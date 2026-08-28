// Runs the last seven bindings of jaxe.js against the real FMOD 2.03.12
// wasm under Node: the preallocated DSP input, the mix level setters on
// channels and groups, the DSP description by type, the output plugin
// handle, and the replay cursor. The wasm DSP object has no
// addInputPreallocated and embind cannot marshal the description pointer,
// so those two must report 68 (ERR_UNSUPPORTED). The rest work.
// Usage: node lastseven-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`LASTSEVEN_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
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
    if (!jaxe.FmodIsInitialized) { console.log('LASTSEVEN_TEST: INIT TIMEOUT'); process.exit(1); }
}

async function main() {
    await waitForInit();
    const master = jaxe.fmod_cg_get_master();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const ibuf = new Array(1024).fill(7);
    const fbuf = new Array(1024).fill(0);

    // The reasons for the two unsupported paths
    const probeDsp = jaxe.fmod_dsp_create_by_type(7);
    check('wasm_has_no_add_input_preallocated', typeof jaxe.resolveDsp(probeDsp).addInputPreallocated === 'undefined', '');
    const echo = jaxe.fmod_dsp_create_by_type(6);
    const conn = jaxe.fmod_dsp_add_input(echo, probeDsp, 0);
    check('dsp_add_input_for_conn', conn !== 0, `handle=${conn}`);
    const preallocated = jaxe.fmod_dsp_add_input_preallocated(echo, probeDsp, conn);
    check('dsp_add_input_preallocated_unsupported', preallocated === 0 && jaxe.fmod_sys_last_result() === 68,
        `handle=${preallocated} result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_add_input_preallocated_stale', jaxe.fmod_dsp_add_input_preallocated(0x7fff0001, probeDsp, conn) === 0
        && jaxe.fmod_sys_last_result() === 30, `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_add_input_preallocated_null_conn', jaxe.fmod_dsp_add_input_preallocated(echo, probeDsp, 0) === 0
        && jaxe.fmod_sys_last_result() === 30, `result=${jaxe.fmod_sys_last_result()}`);
    jaxe.fmod_dsp_disconnect_all(echo, true, true);
    jaxe.fmod_dsp_release(echo);
    jaxe.fmod_dsp_release(probeDsp);

    // Mix levels on a playing stream channel and on the master group
    const ps = jaxe.fmod_core_pcm_create(48000, 2, 9600);
    const ch = jaxe.fmod_core_pcm_play(ps, true);
    check('pcm_play', ch !== 0, `handle=${ch}`);
    fbuf[0] = 0.5; fbuf[1] = 0.5;
    check('chan_set_mix_levels_input', jaxe.fmod_chan_set_mix_levels_input(ch, fbuf, 2) === 0, '');
    // The wasm rejects an empty list, so the abstract never sends one
    check('chan_set_mix_levels_input_empty', jaxe.fmod_chan_set_mix_levels_input(ch, fbuf, 0) === 31, '');
    check('chan_set_mix_levels_input_too_many', jaxe.fmod_chan_set_mix_levels_input(ch, fbuf, 33) === 31, '');
    check('chan_set_mix_levels_output', jaxe.fmod_chan_set_mix_levels_output(ch, 1, 1, 0, 0, 0, 0, 0, 0) === 0, '');
    fbuf[0] = 1.0; fbuf[1] = 1.0;
    jaxe.fmod_chan_set_mix_levels_input(ch, fbuf, 2);
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_core_pcm_release(ps);
    check('chan_set_mix_levels_input_stale', jaxe.fmod_chan_set_mix_levels_input(ch, fbuf, 1) === 30, '');
    check('chan_set_mix_levels_output_stale', jaxe.fmod_chan_set_mix_levels_output(ch, 1, 1, 0, 0, 0, 0, 0, 0) === 30, '');

    fbuf[0] = 0.8; fbuf[1] = 0.8;
    check('cg_set_mix_levels_input', jaxe.fmod_cg_set_mix_levels_input(master, fbuf, 2) === 0, '');
    check('cg_set_mix_levels_input_too_many', jaxe.fmod_cg_set_mix_levels_input(master, fbuf, 33) === 31, '');
    check('cg_set_mix_levels_output', jaxe.fmod_cg_set_mix_levels_output(master, 1, 1, 0, 0, 0, 0, 0, 0) === 0, '');
    fbuf[0] = 1.0; fbuf[1] = 1.0;
    jaxe.fmod_cg_set_mix_levels_input(master, fbuf, 2);
    check('cg_set_mix_levels_input_stale', jaxe.fmod_cg_set_mix_levels_input(0x7fff0001, fbuf, 1) === 30, '');
    check('cg_set_mix_levels_output_stale', jaxe.fmod_cg_set_mix_levels_output(0x7fff0001, 1, 1, 0, 0, 0, 0, 0, 0) === 30, '');

    // The description by type cannot cross embind
    let threw = false;
    try { jaxe.gSystemCore.getDSPInfoByType(7, {}); } catch (e) { threw = true; }
    check('wasm_get_dsp_info_by_type_throws', threw, '');
    const name = jaxe.fmod_sys_get_dsp_info_by_type(7, ibuf);
    check('sys_get_dsp_info_by_type_unsupported', name === '' && jaxe.fmod_sys_last_result() === 68
        && ibuf[0] === 0 && ibuf[1] === 0 && ibuf[2] === 0 && ibuf[3] === 0,
        `name="${name}" ints=${ibuf.slice(0, 4).join(',')}`);

    // The output plugin handle, and the setter refused once running
    const outputBefore = jaxe.fmod_sys_get_output();
    const outputPlugin = jaxe.fmod_sys_get_output_by_plugin();
    check('sys_get_output_by_plugin', outputPlugin !== 0 && jaxe.fmod_sys_last_result() === 0,
        `handle=${outputPlugin} result=${jaxe.fmod_sys_last_result()}`);
    check('sys_set_output_by_plugin_after_init', jaxe.fmod_sys_set_output_by_plugin(outputPlugin) === 27, '');
    check('sys_set_output_by_plugin_leaves_output', jaxe.fmod_sys_get_output() === outputBefore,
        `before=${outputBefore} now=${jaxe.fmod_sys_get_output()}`);

    // The replay cursor on a capture that has never been started
    check('capture_start', jaxe.fmod_sys_start_command_capture('/lastseven.cmd.txt') === 0, '');
    jaxe.fmod_sys_update();
    check('capture_stop', jaxe.fmod_sys_stop_command_capture() === 0, '');
    const replay = jaxe.fmod_sys_load_command_replay('/lastseven.cmd.txt');
    check('replay_load', replay !== 0, `handle=${replay}`);
    fbuf[0] = 5;
    const current = jaxe.fmod_replay_get_current_command(replay, fbuf);
    check('replay_get_current_command', current === 0 && jaxe.fmod_sys_last_result() === 0 && fbuf[0] === 0,
        `index=${current} time=${fbuf[0]} result=${jaxe.fmod_sys_last_result()}`);
    check('replay_release', jaxe.fmod_replay_release(replay) === 0, '');
    fbuf[0] = 5;
    check('replay_get_current_command_stale', jaxe.fmod_replay_get_current_command(replay, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 30 && fbuf[0] === 0, `result=${jaxe.fmod_sys_last_result()}`);

    check('no_handle_leaks_lastseven', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`LASTSEVEN_TEST: failures = ${failures}`);
    console.log('LASTSEVEN_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
