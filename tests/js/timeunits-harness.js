// Runs the time unit and sound info bindings of jaxe.js against the real
// FMOD 2.03.12 wasm under Node: the unit parameter on sound length, loop
// points, sync point offsets, and channel position, plus the four-slot
// format and open state readers. A 4800 frame mono sound at 48 kHz is
// 100 ms, 4800 PCM samples, and 9600 PCM bytes, which pins each unit.
// Usage: node timeunits-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`TIMEUNITS_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

async function waitForInit() {
    const initResult = jaxe.fmod_sys_init_ex(64, 0, 0, 0, 512, 4, 40, 65536, 3);
    check('sys_init_ex', initResult === 0, `result=${initResult}`);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('TIMEUNITS_TEST: INIT TIMEOUT'); process.exit(1); }
}

async function main() {
    await waitForInit();
    const F = jaxe.FMOD;
    const baseline = jaxe.fmod_debug_live_handle_count();

    const frames = 4800;
    const buf = new ArrayBuffer(frames * 2);
    const snd = jaxe.fmod_core_create_sound_pcm(buf, buf.byteLength, 48000, 1);
    check('sound_create', snd !== 0, `handle=${snd} result=${jaxe.lastResult}`);

    // Length in each unit
    check('length_ms', jaxe.fmod_core_get_sound_length(snd, F.TIMEUNIT_MS) === 100,
        `ms=${jaxe.fmod_core_get_sound_length(snd, F.TIMEUNIT_MS)}`);
    check('length_pcm', jaxe.fmod_core_get_sound_length(snd, F.TIMEUNIT_PCM) === frames,
        `pcm=${jaxe.fmod_core_get_sound_length(snd, F.TIMEUNIT_PCM)}`);
    check('length_pcmbytes', jaxe.fmod_core_get_sound_length(snd, F.TIMEUNIT_PCMBYTES) === frames * 2,
        `bytes=${jaxe.fmod_core_get_sound_length(snd, F.TIMEUNIT_PCMBYTES)}`);

    // Loop points written in samples read back in milliseconds
    jaxe.fmod_sound_set_mode(snd, F.LOOP_NORMAL >>> 0);
    check('sound_loop_points_pcm', jaxe.fmod_sound_set_loop_points(snd, 480, 2400, F.TIMEUNIT_PCM) === F.OK, '');
    const loopsPcm = [];
    jaxe.fmod_sound_get_loop_points(snd, F.TIMEUNIT_PCM, loopsPcm);
    check('sound_loop_points_pcm_roundtrip', loopsPcm[0] === 480 && loopsPcm[1] === 2400,
        `start=${loopsPcm[0]} end=${loopsPcm[1]}`);
    const loopsMs = [];
    jaxe.fmod_sound_get_loop_points(snd, F.TIMEUNIT_MS, loopsMs);
    check('sound_loop_points_ms_view', loopsMs[0] === 10 && loopsMs[1] === 50,
        `start=${loopsMs[0]} end=${loopsMs[1]}`);

    // Sync point offset in samples, read in both units
    check('sync_add_pcm', jaxe.fmod_sound_add_sync_point(snd, 2400, F.TIMEUNIT_PCM, 'half') === F.OK, '');
    check('sync_offset_ms', jaxe.fmod_sound_get_sync_point_offset(snd, 0, F.TIMEUNIT_MS) === 50,
        `ms=${jaxe.fmod_sound_get_sync_point_offset(snd, 0, F.TIMEUNIT_MS)}`);
    check('sync_offset_pcm', jaxe.fmod_sound_get_sync_point_offset(snd, 0, F.TIMEUNIT_PCM) === 2400,
        `pcm=${jaxe.fmod_sound_get_sync_point_offset(snd, 0, F.TIMEUNIT_PCM)}`);
    check('sync_name', jaxe.fmod_sound_get_sync_point_name(snd, 0) === 'half', '');
    check('sync_delete', jaxe.fmod_sound_delete_sync_point(snd, 0) === F.OK
        && jaxe.fmod_sound_get_num_sync_points(snd) === 0, '');

    // Format now carries the type and sample format in front
    const format = [];
    check('format_result', jaxe.fmod_sound_get_format(snd, format) === F.OK, '');
    check('format_type_raw', format[0] === F.SOUND_TYPE_RAW, `type=${format[0]}`);
    check('format_pcm16', format[1] === F.SOUND_FORMAT_PCM16, `format=${format[1]}`);
    check('format_channels_bits', format[2] === 1 && format[3] === 16, `ch=${format[2]} bits=${format[3]}`);

    // Open state info next to the plain state
    const state = [];
    check('open_state_info_result', jaxe.fmod_sound_get_open_state_info(snd, state) === F.OK, '');
    check('open_state_info_ready', state[0] === F.OPENSTATE_READY, `state=${state[0]}`);
    check('open_state_info_flags', state[2] === 0 && state[3] === 0,
        `buffered=${state[1]} starving=${state[2]} diskbusy=${state[3]}`);
    check('open_state_plain', jaxe.fmod_sound_get_open_state(snd) === state[0], '');

    // Channel position and loop points in samples
    const ch = jaxe.fmod_core_play_sound(snd, true);
    check('play_paused', ch !== 0, `handle=${ch}`);
    check('chan_set_position_pcm', jaxe.fmod_chan_set_position(ch, 2400, F.TIMEUNIT_PCM) === F.OK, '');
    check('chan_get_position_ms', jaxe.fmod_chan_get_position(ch, F.TIMEUNIT_MS) === 50,
        `ms=${jaxe.fmod_chan_get_position(ch, F.TIMEUNIT_MS)}`);
    check('chan_get_position_pcm', jaxe.fmod_chan_get_position(ch, F.TIMEUNIT_PCM) === 2400,
        `pcm=${jaxe.fmod_chan_get_position(ch, F.TIMEUNIT_PCM)}`);
    check('chan_loop_points_pcm', jaxe.fmod_chan_set_loop_points(ch, 960, 1920, F.TIMEUNIT_PCM) === F.OK, '');
    const chLoops = [];
    jaxe.fmod_chan_get_loop_points(ch, F.TIMEUNIT_MS, chLoops);
    check('chan_loop_points_ms_view', chLoops[0] === 20 && chLoops[1] === 40,
        `start=${chLoops[0]} end=${chLoops[1]}`);
    jaxe.fmod_chan_stop(ch);

    // Stale and bad handles keep the failure shape
    check('length_bad_handle', jaxe.fmod_core_get_sound_length(12345, F.TIMEUNIT_PCM) === -1, '');
    check('open_state_info_bad_handle', jaxe.fmod_sound_get_open_state_info(12345, []) === jaxe.ERR_INVALID_HANDLE, '');

    check('sound_release', jaxe.fmod_core_release_sound(snd) === F.OK, '');
    check('no_handle_leaks_timeunits', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`TIMEUNITS_TEST: failures = ${failures}`);
    console.log('TIMEUNITS_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
