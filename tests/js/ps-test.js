// Validates the M4 jaxe.js surface: core sound micro subset with a real wav
// in MEMFS, ps_assign/ps_clear mask handling, and the CREATE_PROGRAMMER_SOUND
// resolution logic (invoked directly - the example bank has no programmer
// instrument to trigger it naturally).
// Path resolution: the FMOD html5 SDK comes from $FMOD_SDK_WEB (the same
// variable lime builds use). The shim and banks are found relative to this
// file so the harness runs from any cwd.
const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
const BANKS = path.join(REPO, 'example-project', 'EZPlatformer', 'assets', 'fmod', 'Desktop');
const WAV = path.join(REPO, 'example-project', 'EZPlatformer', 'fmod', 'Assets', 'Jump.wav');

global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

jaxe.preRun = function () {
    for (const n of ['Master.bank', 'Master.strings.bank']) {
        jaxe.FMOD.FS_createDataFile('/', n, fs.readFileSync(path.join(BANKS, n)), true, false, false);
    }
    jaxe.FMOD.FS_createDataFile('/', 'Jump.wav', fs.readFileSync(WAV), true, false, false);
};
jaxe.onRuntimeInitialized = function () {
    var o = {};
    jaxe.FMOD.Studio_System_Create(o); jaxe.gSystem = o.val;
    jaxe.gSystem.getCoreSystem(o); jaxe.gSystemCore = o.val;
    jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
    jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    var b = {};
    jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let fails = 0;
function check(label, cond, detail) {
    console.log(`PS_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('INIT TIMEOUT'); process.exit(1); }

    // --- Core micro subset: the html5 Studio build ships FSB-only codecs,
    // so loose wav/ogg files fail with FMOD_ERR_FORMAT (19). The binding must
    // return 0 + lastResult, not throw. Native targets load
    // these files fine. That path is CI-validated by ProgrammerSoundTestState.
    const snd = jaxe.fmod_core_create_sound('Jump.wav', 0);
    check('core_create_sound_format_limit', snd === 0 && jaxe.fmod_sys_last_result() === 19,
        `handle=${snd} lastResult=${jaxe.fmod_sys_last_result()}`);
    check('core_missing_file', jaxe.fmod_core_create_sound('Nope.wav', 0) === 0
        && jaxe.fmod_sys_last_result() === 18, `lastResult=${jaxe.fmod_sys_last_result()}`);
    check('core_invalid_handle_len', jaxe.fmod_core_get_sound_length(12345) === -1, '');

    // --- ps_assign / ps_clear mask plumbing on a real instance ---
    const evi = jaxe.fmod_evd_create_instance(jaxe.fmod_sys_get_event('event:/Music/MainLevel'));
    check('create_instance', evi > 0, `handle=${evi}`);
    check('ps_assign', jaxe.fmod_ps_assign(evi, 'Jump.wav') === 0, '');
    check('ps_key_stored', jaxe.psKeys[evi] === 'Jump.wav', '');
    check('ps_mask_bits', (jaxe.effectiveCallbackMask(evi) & 0x180) === 0x180, '');
    // user mask coexists
    jaxe.fmod_evi_set_callback_mask(evi, 0x20);
    check('ps_mask_coexists', (jaxe.effectiveCallbackMask(evi) & 0x1A0) === 0x1A0, '');

    // --- Direct CREATE_PROGRAMMER_SOUND resolution (file path fallback) ---
    // The example bank has no programmer instrument, so invoke the handler
    // exactly as FMOD would: same wrapper delivery, fake props object.
    const inst = jaxe.handleResolve(evi, jaxe.TYPE_EVI);
    const props = { name: '', sound: null, subsoundIndex: 0 };
    const r = jaxe.callbackHandler(0x80, inst, props);
    check('create_ps_returns_ok', r === 0, `r=${r}`);
    // File fallback cannot decode loose wav on html5 (FSB-only codecs): the
    // handler must leave sound null and not throw. Audio-table keys are the
    // supported html5 route, pinned below against the real table.
    check('create_ps_rejects_unsupported_format', props.sound == null, '');
    const rd = jaxe.callbackHandler(0x100, inst, props);
    check('destroy_ps_returns_ok', rd === 0, `r=${rd}`);

    // --- Audio-table key resolution (the html5-supported route) ---
    // "hello" lives in the Master bank's audio table: getSoundInfo resolves
    // it and createSound decodes the FSB entry
    jaxe.fmod_ps_assign(evi, 'hello');
    const tableProps = { name: '', sound: null, subsoundIndex: 0 };
    let tableResult = null;
    try {
        tableResult = jaxe.callbackHandler(0x80, inst, tableProps);
    } catch (e) {
        check('create_ps_audio_table_no_throw', false, (e && e.message) || String(e));
    }
    if (tableResult !== null) {
        check('create_ps_audio_table_no_throw', true, '');
        check('create_ps_audio_table_returns_ok', tableResult === 0, `r=${tableResult}`);
        check('create_ps_audio_table_resolves', tableProps.sound != null, '');
        check('create_ps_audio_table_subsound',
            typeof tableProps.subsoundIndex === 'number' && tableProps.subsoundIndex >= 0,
            `idx=${tableProps.subsoundIndex}`);
        const rdTable = jaxe.callbackHandler(0x100, inst, tableProps);
        check('destroy_ps_audio_table', rdTable === 0, `r=${rdTable}`);
    }

    // ps_clear removes bits
    check('ps_clear', jaxe.fmod_ps_clear(evi) === 0, '');
    check('ps_mask_cleared', (jaxe.effectiveCallbackMask(evi) & 0x180) === 0, '');

    // DESTROYED cleans per-handle state
    jaxe.fmod_ps_assign(evi, 'Jump.wav');
    jaxe.callbackHandler(0x02, inst, null);
    check('destroyed_cleans_state', jaxe.psKeys[evi] === undefined && jaxe.cbMasks[evi] === undefined, '');

    jaxe.fmod_evi_release(evi);
    console.log(fails ? `PS_TEST FAILED: ${fails}` : 'PS_TEST COMPLETE');
    process.exit(fails ? 1 : 0);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
