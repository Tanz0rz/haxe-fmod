// Runs the system extras of jaxe.js against the real FMOD 2.03.12 wasm
// under Node: command replay inspection, the DSP lock, audio table sound
// info, memory and file statistics, the network settings, and speaker
// positions. The web build serves all of them, so every call here is
// expected to work for real, with dead handles still reporting 30
// (ERR_INVALID_HANDLE) and the handle table left as it was found.
// Usage: node sysextras-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`SYSEXTRAS_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
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
    if (!jaxe.FmodIsInitialized) { console.log('SYSEXTRAS_TEST: INIT TIMEOUT'); process.exit(1); }
}

async function main() {
    await waitForInit();
    // The master group handle is cached by the shim, so it is taken before the baseline
    const master = jaxe.fmod_cg_get_master();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const fbuf = new Array(1024).fill(0);
    const ibuf = new Array(1024).fill(0);

    // A short capture in MEMFS to inspect
    check('capture_start', jaxe.fmod_sys_start_command_capture('/sysextras.cmd.txt') === 0, '');
    jaxe.fmod_sys_update();
    check('capture_stop', jaxe.fmod_sys_stop_command_capture() === 0, '');
    const replay = jaxe.fmod_sys_load_command_replay('/sysextras.cmd.txt');
    check('replay_load', replay !== 0, `handle=${replay}`);

    const count = jaxe.fmod_replay_get_command_count(replay);
    check('replay_get_command_count', count > 0, `count=${count}`);
    const name = jaxe.fmod_replay_get_command_info(replay, 0, ibuf, fbuf);
    check('replay_get_command_info', jaxe.fmod_sys_last_result() === 0 && name.length > 0 && ibuf[4] === 0,
        `name=${name} instancetype=${ibuf[0]} frame=${ibuf[4]} parent=${ibuf[5]} time=${fbuf[0]}`);
    const text = jaxe.fmod_replay_get_command_string(replay, 0);
    check('replay_get_command_string', text.length > 0 && text.startsWith(name), `text=${text}`);
    check('replay_get_command_at_time', jaxe.fmod_replay_get_command_at_time(replay, 0) === 0, '');
    check('replay_seek_to_command', jaxe.fmod_replay_seek_to_command(replay, 0) === 0, '');
    check('replay_get_playback_state', jaxe.fmod_replay_get_playback_state(replay) === 2, '');
    check('replay_set_bank_path', jaxe.fmod_replay_set_bank_path(replay, '/') === 0, '');
    check('replay_set_bank_path_bad_arg', jaxe.fmod_replay_set_bank_path(replay, 5) === 31, '');
    check('replay_get_command_info_out_of_range', jaxe.fmod_replay_get_command_info(replay, count + 10, ibuf, fbuf) === ''
        && jaxe.fmod_sys_last_result() !== 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('replay_get_command_string_out_of_range', jaxe.fmod_replay_get_command_string(replay, count + 10) === '', '');
    check('replay_release', jaxe.fmod_replay_release(replay) === 0, '');

    // Dead handle paths
    check('replay_get_command_count_stale', jaxe.fmod_replay_get_command_count(replay) === -1
        && jaxe.fmod_sys_last_result() === 30, '');
    check('replay_get_command_info_stale', jaxe.fmod_replay_get_command_info(replay, 0, ibuf, fbuf) === ''
        && jaxe.fmod_sys_last_result() === 30, '');
    check('replay_get_command_string_stale', jaxe.fmod_replay_get_command_string(replay, 0) === ''
        && jaxe.fmod_sys_last_result() === 30, '');
    check('replay_get_command_at_time_stale', jaxe.fmod_replay_get_command_at_time(replay, 0) === -1
        && jaxe.fmod_sys_last_result() === 30, '');
    check('replay_seek_to_command_stale', jaxe.fmod_replay_seek_to_command(replay, 0) === 30, '');
    check('replay_get_playback_state_stale', jaxe.fmod_replay_get_playback_state(replay) === 2
        && jaxe.fmod_sys_last_result() === 30, '');
    check('replay_set_bank_path_stale', jaxe.fmod_replay_set_bank_path(replay, '/') === 30, '');

    // The DSP lock around a graph edit on the master group
    const lowpass = jaxe.fmod_dsp_create_by_type(18);
    check('sys_lock_dsp', jaxe.fmod_sys_lock_dsp() === 0, '');
    const added = jaxe.fmod_cg_add_dsp(master, 0, lowpass);
    const removed = jaxe.fmod_cg_remove_dsp(master, lowpass);
    check('sys_unlock_dsp', jaxe.fmod_sys_unlock_dsp() === 0 && added === 0 && removed === 0,
        `add=${added} remove=${removed}`);
    jaxe.fmod_dsp_release(lowpass);

    // Sound info on a key no audio table holds
    check('sys_get_sound_info_missing', jaxe.fmod_sys_get_sound_info('no-such-key', ibuf) === ''
        && jaxe.fmod_sys_last_result() !== 0 && ibuf[0] === -1, `result=${jaxe.fmod_sys_last_result()}`);
    check('sys_get_sound_info_bad_arg', jaxe.fmod_sys_get_sound_info(5, ibuf) === ''
        && jaxe.fmod_sys_last_result() === 31, '');

    // Memory statistics
    check('sys_get_memory_stats', jaxe.fmod_sys_get_memory_stats(false, ibuf) === 0 && ibuf[0] > 0 && ibuf[1] >= ibuf[0],
        `current=${ibuf[0]} max=${ibuf[1]}`);
    check('sys_get_memory_stats_blocking', jaxe.fmod_sys_get_memory_stats(true, ibuf) === 0 && ibuf[0] > 0,
        `current=${ibuf[0]}`);

    // File usage: the NRT system here reads nothing from disk, so the
    // counters are zero and the call itself is what gets checked
    check('sys_get_file_usage', jaxe.fmod_sys_get_file_usage(fbuf) === 0 && fbuf[0] >= 0 && fbuf[1] >= 0 && fbuf[2] >= 0,
        `sample=${fbuf[0]} stream=${fbuf[1]} other=${fbuf[2]}`);

    // Network proxy and timeout round trips, restored afterwards
    const proxyBefore = jaxe.fmod_sys_get_network_proxy();
    const timeoutBefore = jaxe.fmod_sys_get_network_timeout();
    check('sys_get_network_timeout_default', timeoutBefore > 0, `value=${timeoutBefore}`);
    check('sys_network_proxy_roundtrip', jaxe.fmod_sys_set_network_proxy('proxy.example:8080') === 0
        && jaxe.fmod_sys_get_network_proxy() === 'proxy.example:8080', `value=${jaxe.fmod_sys_get_network_proxy()}`);
    check('sys_set_network_proxy_bad_arg', jaxe.fmod_sys_set_network_proxy(5) === 31, '');
    check('sys_network_timeout_roundtrip', jaxe.fmod_sys_set_network_timeout(1234) === 0
        && jaxe.fmod_sys_get_network_timeout() === 1234, `value=${jaxe.fmod_sys_get_network_timeout()}`);
    jaxe.fmod_sys_set_network_proxy(proxyBefore);
    jaxe.fmod_sys_set_network_timeout(timeoutBefore);
    check('sys_network_restored', jaxe.fmod_sys_get_network_proxy() === proxyBefore
        && jaxe.fmod_sys_get_network_timeout() === timeoutBefore, '');

    // Speaker position round trip on front left, restored afterwards
    check('sys_get_speaker_position', jaxe.fmod_sys_get_speaker_position(0, fbuf) === 0,
        `x=${fbuf[0]} y=${fbuf[1]} active=${fbuf[2]}`);
    const before = [fbuf[0], fbuf[1], fbuf[2]];
    check('sys_speaker_position_roundtrip', jaxe.fmod_sys_set_speaker_position(0, -0.5, 0.5, true) === 0
        && jaxe.fmod_sys_get_speaker_position(0, fbuf) === 0
        && Math.abs(fbuf[0] + 0.5) < 0.001 && Math.abs(fbuf[1] - 0.5) < 0.001 && fbuf[2] === 1,
        `x=${fbuf[0]} y=${fbuf[1]} active=${fbuf[2]}`);
    jaxe.fmod_sys_set_speaker_position(0, before[0], before[1], before[2] === 1);
    check('sys_speaker_position_restored', jaxe.fmod_sys_get_speaker_position(0, fbuf) === 0
        && Math.abs(fbuf[0] - before[0]) < 0.001 && Math.abs(fbuf[1] - before[1]) < 0.001, '');

    check('no_handle_leaks_sysextras', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`SYSEXTRAS_TEST: failures = ${failures}`);
    console.log('SYSEXTRAS_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
