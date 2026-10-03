// Exercises the instance lifecycle calls of jaxe.js against the real wasm
// to catch embind arity errors (BindingError) on that path. The other
// harnesses in this directory cover the rest of the bound surface.

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
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let failures = 0;
// A call that throws is the arity error this file exists for. A call
// that returns an FMOD error code is a failure too. A wrong argument
// order reaches FMOD as a refused call rather than a throw. A getter
// returns its error value in band, so its predicate reads the last
// result as well.
function check(label, fn, ok) {
    try {
        const r = fn();
        if (ok !== undefined && !ok(r)) { console.log(`FAIL ${label} -> ${r}`); failures++; return r; }
        console.log(`OK   ${label} -> ${r}`);
        return r;
    }
    catch (e) { console.log(`FAIL ${label} -> ${e.constructor.name}: ${e.message}`); failures++; return null; }
}
const isOk = r => r === 0;
const isHandle = r => typeof r === 'number' && r > 0;
const lastOk = () => jaxe.fmod_sys_last_result() === 0;

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('INIT TIMEOUT'); process.exit(1); }

    const SONG = 'event:/Music/MainLevel';

    // System basics through the raw layer
    check('fmod_sys_is_initialized', () => jaxe.fmod_sys_is_initialized(), r => r === true);
    check('fmod_sys_update', () => { jaxe.fmod_sys_update(); return 'ok'; });
    // Instance lifecycle goes through the domain-prefixed API
    const evd = check('fmod_sys_get_event', () => jaxe.fmod_sys_get_event(SONG), isHandle);
    const h = check('fmod_evd_create_instance', () => jaxe.fmod_evd_create_instance(evd), isHandle);
    check('fmod_evi_start', () => jaxe.fmod_evi_start(h), isOk);
    // The instance reaches PLAYING (0) within a few updates, then plays on
    // for a while so the timeline has moved
    for (let i = 0; i < 200 && jaxe.fmod_evi_get_playback_state(h) !== 0; i++) { jaxe.fmod_sys_update(); await new Promise(r => setTimeout(r, 10)); }
    for (let i = 0; i < 10; i++) { jaxe.fmod_sys_update(); await new Promise(r => setTimeout(r, 10)); }
    check('fmod_evi_get_playback_state', () => jaxe.fmod_evi_get_playback_state(h), r => r === 0 && lastOk());
    check('fmod_evi_get_timeline_position', () => jaxe.fmod_evi_get_timeline_position(h), r => r > 0 && lastOk());
    // HighPass is a parameter the example's music event carries
    check('fmod_evi_set_param_by_name', () => jaxe.fmod_evi_set_param_by_name(h, 'HighPass', 0.5, false), isOk);
    check('fmod_evi_get_param_by_name', () => jaxe.fmod_evi_get_param_by_name(h, 'HighPass'), r => Math.abs(r - 0.5) < 1e-6 && lastOk());
    check('fmod_evi_set_paused(true)', () => jaxe.fmod_evi_set_paused(h, true), isOk);
    check('fmod_evi_set_paused(false)', () => jaxe.fmod_evi_set_paused(h, false), isOk);
    check('fmod_evi_set_callback_mask', () => jaxe.fmod_evi_set_callback_mask(h, 0x7FFFF), isOk);
    check('fmod_evi_stop soft', () => jaxe.fmod_evi_stop(h, 0), isOk);
    let saw = false;
    for (let i = 0; i < 300 && !saw; i++) {
        jaxe.fmod_sys_update();
        while (jaxe.fmod_cb_next()) if (jaxe.fmod_cb_type() === 0x20) saw = true;
        await new Promise(r => setTimeout(r, 5));
    }
    console.log('Stopped delivered:', saw);
    if (!saw) failures++;
    check('fmod_evi_release', () => jaxe.fmod_evi_release(h), isOk);

    console.log(failures ? `AUDIT FAILED: ${failures} failures` : 'AUDIT CLEAN');
    process.exit(failures ? 1 : 0);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
