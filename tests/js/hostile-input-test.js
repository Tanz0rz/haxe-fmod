// Hostile-input contract for the JS shim: every manifest function that
// takes a string must handle a null (or non-string) argument the way the
// C shims do - set lastResult to an error code and return - instead of
// letting emscripten's embind throw a BindingError out of the shim.
// Also pins the programmer-sound key length contract (>= 512 UTF-8 bytes
// rejected, matching FAXE_PS_KEY_MAX on native) and the pcm length
// contract (a count beyond the buffer's real size never over-reads).
// Usage: FMOD_SDK_WEB=<sdk root> node hostile-input-test.js
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
const MANIFEST = path.join(REPO, 'native', 'manifest', 'studio_api.txt');

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
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let fails = 0;
function check(label, cond, detail) {
    console.log(`HOSTILE_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Manifest functions with str-typed args, and each str position
function strFunctions() {
    const out = [];
    for (const raw of fs.readFileSync(MANIFEST, 'utf8').split('\n')) {
        const line = raw.trim();
        if (!line || line.startsWith('#') || !line.includes('->')) continue;
        const args = line.split('->')[0].trim().split(/\s+/);
        const name = args.shift();
        const positions = [];
        args.forEach((a, i) => { if (a === 'str') positions.push(i); });
        if (positions.length) out.push({ name, positions, arity: args.length });
    }
    return out;
}

async function main() {
    jaxe.fmod_sys_init_ex(128, 0, 0, 0);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await sleep(50);
    check('init_completes', jaxe.FmodIsInitialized, '');

    // Every str-taking export survives a null in each str position:
    // no throw, and lastResult reports an error (never left at OK)
    const fns = strFunctions();
    check('manifest_str_functions_found', fns.length >= 30, `count=${fns.length}`);
    let clean = 0;
    for (const fn of fns) {
        const impl = jaxe['fmod_' + fn.name];
        if (typeof impl !== 'function') { check(`missing_export_${fn.name}`, false, ''); continue; }
        for (const pos of fn.positions) {
            const args = new Array(fn.arity).fill(0);
            args[pos] = null;
            let threw = null;
            jaxe.lastResult = 0;
            try { impl.apply(jaxe, args); } catch (e) { threw = e; }
            if (threw) {
                check(`null_throws_${fn.name}_arg${pos}`, false, String(threw).slice(0, 60));
            } else if (jaxe.lastResult === 0) {
                check(`null_reports_ok_${fn.name}_arg${pos}`, false, 'lastResult=0');
            } else {
                clean++;
            }
        }
    }
    check('null_strings_handled_everywhere', true, `clean=${clean}`);

    // The system still works after the hostile sweep
    const evd = jaxe.fmod_sys_get_event('event:/Music/MainLevel');
    check('system_survives_hostile_sweep', evd > 0, `handle=${evd}`);

    // Programmer-sound key length: >= 512 UTF-8 bytes rejected (parity
    // with FAXE_PS_KEY_MAX truncation-free native behavior)
    const evi = jaxe.fmod_evd_create_instance(evd);
    check('instance_for_ps', evi > 0, `handle=${evi}`);
    const longKey = 'k'.repeat(600);
    const r = jaxe.fmod_ps_assign(evi, longKey);
    check('ps_key_overlong_rejected', r !== 0 && jaxe.lastResult !== 0, `r=${r}`);
    const okKey = jaxe.fmod_ps_assign(evi, 'sfx-table-key');
    check('ps_key_normal_accepted', okKey === 0, `r=${okKey}`);
    jaxe.fmod_ps_clear(evi);
    jaxe.fmod_evi_release(evi);

    // PCM create with a lied length: never over-reads (returns a valid
    // clamped sound or a clean error - a crash here fails the harness)
    const pcm = new ArrayBuffer(1024);
    const handle = jaxe.fmod_core_create_sound_pcm(pcm, 1024 * 1024, 44100, 1);
    check('pcm_lied_length_safe', handle === 0 && jaxe.lastResult !== 0,
        `handle=${handle} lastResult=${jaxe.lastResult}`);
    const good = jaxe.fmod_core_create_sound_pcm(pcm, 1024, 44100, 1);
    check('pcm_true_length_works', good > 0, `handle=${good}`);
    jaxe.fmod_core_release_sound(good);

    console.log(`HOSTILE_TEST: failures = ${fails}`);
    console.log(fails === 0 ? 'HOSTILE_TEST: COMPLETE' : 'HOSTILE_TEST: FAILED');
    process.exit(fails === 0 ? 0 : 1);
}

main().catch(e => { console.log('HARNESS ERROR', e); process.exit(1); });
