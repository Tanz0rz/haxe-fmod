// Runs the plugin bindings of jaxe.js against the real FMOD 2.03.12 wasm
// under Node. The wasm system object has no loadPlugin at all, so every
// function here must report 68 (ERR_UNSUPPORTED), hand back the failure
// value for its shape (0 handle, -1 count, "" name), and leave the handle
// table untouched.
// Usage: node plugins-harness.js  (needs FMOD_SDK_WEB)

const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
global.window = {
    location: { pathname: '/game/index.html' },
    setInterval: setInterval,
    clearInterval: clearInterval,
};
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));

const src = fs.readFileSync(JAXE, 'utf8');
eval(src + '\nglobal.jaxe = jaxe;');

jaxe.onRuntimeInitialized = function () {
    try {
        var outval = {};
        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;
        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;
        jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
        jaxe.applyPendingCoreSettings(jaxe.gSystemCore, jaxe.pendingInit);
        jaxe.gSystem.initialize(64, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.coreInitFlags(jaxe.pendingInit), null);
        jaxe.FmodIsInitialized = true;
    } catch (e) {
        console.log('INIT THREW:', e.message);
        process.exit(1);
    }
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, cond, detail) {
    console.log(`PLUGIN_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

async function waitForInit() {
    // The init call loads the wasm module, onRuntimeInitialized above finishes it
    const initResult = jaxe.fmod_sys_init_ex(64, 0, 0, 0, 512, 4, 40, 65536, 3);
    check('sys_init_ex', initResult === 0, `result=${initResult}`);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('PLUGIN_TEST: INIT TIMEOUT'); process.exit(1); }
}

async function main() {
    await waitForInit();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const ibuf = new Array(1024).fill(7);

    // The reason the whole surface is unsupported: the wasm has no loader
    check('wasm_has_no_load_plugin', typeof jaxe.gSystemCore.loadPlugin === 'undefined', '');

    check('sys_set_plugin_path_unsupported', jaxe.fmod_sys_set_plugin_path('plugins') === 68, '');
    const loaded = jaxe.fmod_sys_load_plugin('libtest_plugin_gain.so', 0);
    check('sys_load_plugin_unsupported', loaded === 0 && jaxe.fmod_sys_last_result() === 68,
        `handle=${loaded} result=${jaxe.fmod_sys_last_result()}`);
    check('sys_unload_plugin_unsupported', jaxe.fmod_sys_unload_plugin(1) === 68, '');
    check('sys_get_num_plugins_unsupported', jaxe.fmod_sys_get_num_plugins(2) === -1
        && jaxe.fmod_sys_last_result() === 68, '');
    check('sys_get_plugin_handle_unsupported', jaxe.fmod_sys_get_plugin_handle(2, 0) === 0
        && jaxe.fmod_sys_last_result() === 68, '');
    const name = jaxe.fmod_sys_get_plugin_info(1, ibuf);
    check('sys_get_plugin_info_unsupported', name === '' && jaxe.fmod_sys_last_result() === 68
        && ibuf[0] === 0 && ibuf[1] === 0, `name="${name}" type=${ibuf[0]} version=${ibuf[1]}`);
    check('sys_get_num_nested_plugins_unsupported', jaxe.fmod_sys_get_num_nested_plugins(1) === -1
        && jaxe.fmod_sys_last_result() === 68, '');
    check('sys_get_nested_plugin_unsupported', jaxe.fmod_sys_get_nested_plugin(1, 0) === 0
        && jaxe.fmod_sys_last_result() === 68, '');
    const unit = jaxe.fmod_dsp_create_by_plugin(1);
    check('dsp_create_by_plugin_unsupported', unit === 0 && jaxe.fmod_sys_last_result() === 68,
        `handle=${unit} result=${jaxe.fmod_sys_last_result()}`);
    ibuf.fill(7);
    const dspName = jaxe.fmod_dsp_get_info_by_plugin(1, ibuf);
    check('dsp_get_info_by_plugin_unsupported', dspName === '' && jaxe.fmod_sys_last_result() === 68
        && ibuf[0] === 0 && ibuf[1] === 0 && ibuf[2] === 0 && ibuf[3] === 0,
        `name="${dspName}" ints=${ibuf.slice(0, 4).join(',')}`);

    check('no_handle_leaks_plugins', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`PLUGIN_TEST: failures = ${failures}`);
    console.log('PLUGIN_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
