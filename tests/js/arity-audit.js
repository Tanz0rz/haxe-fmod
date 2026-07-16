// Exercises EVERY jaxe.js public function against the real wasm to catch
// embind arity errors (BindingError) anywhere in the bound surface.

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
global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

jaxe.preRun = function () {
    for (const n of ['Master.bank', 'Master.strings.bank']) {
        jaxe.FMOD.FS_createDataFile('/', n, fs.readFileSync(path.join(BANKS, n)), true, false, false);
    }
};
jaxe.onRuntimeInitialized = function () {
    var o = {};
    jaxe.FMOD.Studio_System_Create(o); jaxe.gSystem = o.val;
    jaxe.gSystem.getCoreSystem(o); jaxe.gSystemCore = o.val;
    jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
    jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    var b = {};
    jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.loadedBanks['Master.bank'] = b.val;
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.loadedBanks['Master.strings.bank'] = b.val;
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, fn) {
    try { const r = fn(); console.log(`OK   ${label} -> ${r}`); return r; }
    catch (e) { console.log(`FAIL ${label} -> ${e.constructor.name}: ${e.message}`); failures++; return null; }
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('INIT TIMEOUT'); process.exit(1); }

    const SONG = 'event:/Music/MainLevel';

    // System basics through the raw layer
    check('fmod_sys_is_initialized', () => jaxe.fmod_sys_is_initialized());
    check('fmod_sys_update', () => { jaxe.fmod_sys_update(); return 'ok'; });
    // Instance lifecycle goes through the domain-prefixed API
    const evd = check('fmod_sys_get_event', () => jaxe.fmod_sys_get_event(SONG));
    const h = check('fmod_evd_create_instance', () => jaxe.fmod_evd_create_instance(evd));
    check('fmod_evi_start', () => jaxe.fmod_evi_start(h));
    for (let i = 0; i < 10; i++) { jaxe.fmod_sys_update(); await new Promise(r => setTimeout(r, 10)); }
    check('fmod_evi_get_playback_state', () => jaxe.fmod_evi_get_playback_state(h));
    check('fmod_evi_get_timeline_position', () => jaxe.fmod_evi_get_timeline_position(h));
    check('fmod_evi_set_param_by_name', () => jaxe.fmod_evi_set_param_by_name(h, 'AreaOneUnderWater', 0.5, false));
    check('fmod_evi_get_param_by_name', () => jaxe.fmod_evi_get_param_by_name(h, 'AreaOneUnderWater'));
    check('fmod_evi_set_paused(true)', () => jaxe.fmod_evi_set_paused(h, true));
    check('fmod_evi_set_paused(false)', () => jaxe.fmod_evi_set_paused(h, false));
    check('fmod_evi_set_callback_mask', () => jaxe.fmod_evi_set_callback_mask(h, 0x7FFFF));
    check('fmod_evi_stop soft', () => jaxe.fmod_evi_stop(h, 0));
    let saw = false;
    for (let i = 0; i < 300 && !saw; i++) {
        jaxe.fmod_sys_update();
        while (jaxe.fmod_cb_next()) if (jaxe.fmod_cb_type() === 0x20) saw = true;
        await new Promise(r => setTimeout(r, 5));
    }
    console.log('Stopped delivered:', saw);
    if (!saw) failures++;
    check('fmod_evi_release', () => jaxe.fmod_evi_release(h));

    console.log(failures ? `AUDIT FAILED: ${failures} failures` : 'AUDIT CLEAN');
    process.exit(failures ? 1 : 0);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
