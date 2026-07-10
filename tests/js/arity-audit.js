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

    // Legacy surface (every static fmod_* the old backends call)
    check('fmod_is_initialized', () => jaxe.fmod_is_initialized());
    check('fmod_update', () => { jaxe.fmod_update(); return 'ok'; });
    check('fmod_load_bank (again)', () => jaxe.fmod_load_bank('Master.bank'));
    check('fmod_fire_one_shot', () => jaxe.fmod_fire_one_shot('event:/SFX/Jump'));
    const h = check('fmod_create_instance', () => jaxe.fmod_create_instance(SONG));
    check('fmod_start', () => { jaxe.fmod_start(h); return 'ok'; });
    for (let i = 0; i < 10; i++) { jaxe.fmod_update(); await new Promise(r => setTimeout(r, 10)); }
    check('fmod_get_playback_state', () => jaxe.fmod_get_playback_state(h));
    check('fmod_get_timeline_position', () => jaxe.fmod_get_timeline_position(h));
    check('fmod_set_param', () => { jaxe.fmod_set_param(h, 'AreaOneUnderWater', 0.5); return 'ok'; });
    check('fmod_get_param', () => jaxe.fmod_get_param(h, 'AreaOneUnderWater'));
    check('fmod_set_paused(true)', () => { jaxe.fmod_set_paused(h, true); return 'ok'; });
    check('fmod_set_paused(false)', () => { jaxe.fmod_set_paused(h, false); return 'ok'; });
    // legacy path-based bus API
    check('fmod_set_bus_volume', () => { jaxe.fmod_set_bus_volume('bus:/', 0.8); return 'ok'; });
    check('fmod_get_bus_volume', () => jaxe.fmod_get_bus_volume('bus:/'));
    check('fmod_set_bus_mute(true)', () => { jaxe.fmod_set_bus_mute('bus:/', true); return 'ok'; });
    check('fmod_get_bus_mute', () => jaxe.fmod_get_bus_mute('bus:/'));
    check('fmod_set_bus_mute(false)', () => { jaxe.fmod_set_bus_mute('bus:/', false); return 'ok'; });
    check('fmod_stop_all_events_on_bus', () => { jaxe.fmod_stop_bus("bus:/"); return 'ok'; });
    check('fmod_set_bus_paused t', () => { jaxe.fmod_set_bus_paused('bus:/', true); return 'ok'; });
    check('fmod_set_bus_paused f', () => { jaxe.fmod_set_bus_paused('bus:/', false); return 'ok'; });
    check('fmod_evi_set_callback_mask', () => jaxe.fmod_evi_set_callback_mask(h, 0x7FFFF));
    check('fmod_stop soft', () => { jaxe.fmod_stop(h, 0); return 'ok'; });
    let saw = false;
    for (let i = 0; i < 300 && !saw; i++) {
        jaxe.fmod_update();
        while (jaxe.fmod_cb_next()) if (jaxe.fmod_cb_type() === 0x20) saw = true;
        await new Promise(r => setTimeout(r, 5));
    }
    console.log('Stopped delivered:', saw);
    if (!saw) failures++;
    check('fmod_release', () => { jaxe.fmod_release(h); return 'ok'; });
    check('fmod_unload_bank', () => { jaxe.fmod_unload_bank('Master.bank'); return 'ok'; });

    console.log(failures ? `AUDIT FAILED: ${failures} failures` : 'AUDIT CLEAN');
    process.exit(failures ? 1 : 0);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
