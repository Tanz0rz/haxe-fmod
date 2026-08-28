// Runs the settings, version, sound-data, distance-filter, and recording
// bindings of jaxe.js against the real FMOD 2.03.12 wasm under Node. The
// init path applies the same pre-init settings the browser path does, and
// the functions the web build cannot do must report 68 (ERR_UNSUPPORTED).
// Usage: node system-extras-harness.js  (needs FMOD_SDK_WEB)

const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
const WAV = path.join(REPO, 'example-project', 'EZPlatformer', 'fmod', 'Assets', 'Jump.wav');
global.window = {
    location: { pathname: '/game/index.html' },
    setInterval: setInterval,
    clearInterval: clearInterval,
};
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));

const src = fs.readFileSync(JAXE, 'utf8');
eval(src + '\nglobal.jaxe = jaxe;');

jaxe.preRun = function () {
    jaxe.FMOD.FS_createDataFile('/', 'Jump.wav', fs.readFileSync(WAV), true, false, false);
};

// Node-safe init: NOSOUND output, no driver query, but the same pre-init
// settings and core init flags the browser onRuntimeInitialized applies.
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
    console.log(`EXTRAS_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

async function pump(n) {
    for (let i = 0; i < n; i++) { jaxe.fmod_sys_update(); await new Promise(r => setTimeout(r, 10)); }
}

async function main() {
    // 9-argument init: dsp buffer args are ignored on this target, the rest apply
    const initResult = jaxe.fmod_sys_init_ex(64, 0, 0, 0, 512, 4, 40, 65536, 3);
    check('sys_init_ex_accepts_settings', initResult === 0, `result=${initResult}`);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('EXTRAS_TEST: INIT TIMEOUT'); process.exit(1); }

    const sc = {};
    jaxe.gSystemCore.getSoftwareChannels(sc);
    check('init_software_channels_applied', sc.val === 40, `value=${sc.val}`);
    const sb = {}, sbt = {};
    jaxe.gSystemCore.getStreamBufferSize(sb, sbt);
    check('init_stream_buffer_size_applied', sb.val === 65536, `value=${sb.val}`);
    const dl = {}, dn = {};
    jaxe.gSystemCore.getDSPBufferSize(dl, dn);
    check('init_dsp_buffer_ignored_on_web', dl.val !== 512, `length=${dl.val} num=${dn.val}`);
    check('core_init_flags_translate', jaxe.coreInitFlags({ initFlags: 3 }) === (0x10000 | 0x200),
        `flags=${jaxe.coreInitFlags({ initFlags: 3 })}`);
    check('core_init_flags_default', jaxe.coreInitFlags(null) === jaxe.FMOD.INIT_NORMAL, '');

    // --- version ---
    const version = jaxe.fmod_sys_get_version();
    check('sys_get_version_format', /^\d+\.\d{2}\.\d{2}$/.test(version), `value=${version}`);
    check('sys_get_version_matches_sdk', version === '2.03.12', `value=${version}`);

    const baseline = jaxe.fmod_debug_live_handle_count();

    // --- distance filter on a 3D channel and a group (the init flag is on) ---
    const stream = jaxe.fmod_core_pcm_create_3d(48000, 1, 48000);
    check('pcm_create_3d', stream > 0, `handle=${stream}`);
    const chan = jaxe.fmod_core_pcm_play(stream, true);
    check('pcm_play', chan > 0, `handle=${chan}`);
    const setDf = jaxe.fmod_chan_set_3d_distance_filter(chan, true, 0.5, 1200);
    check('chan_set_3d_distance_filter', setDf === 0, `result=${setDf}`);
    const fbuf = [0, 0, 0];
    const getDf = jaxe.fmod_chan_get_3d_distance_filter(chan, fbuf);
    check('chan_get_3d_distance_filter', getDf === 0 && fbuf[0] === 1
        && Math.abs(fbuf[1] - 0.5) < 0.001 && Math.abs(fbuf[2] - 1200) < 0.5,
        `result=${getDf} custom=${fbuf[0]} level=${fbuf[1]} freq=${fbuf[2]}`);
    check('chan_distance_filter_stale', jaxe.fmod_chan_set_3d_distance_filter(999999, false, 1, 1000) === 30, '');
    jaxe.fmod_chan_stop(chan);
    jaxe.fmod_core_pcm_release(stream);

    const group = jaxe.fmod_cg_create('extras');
    check('cg_create', group > 0, `handle=${group}`);
    // A 2D group reports NEEDS3D (40) from the filter setter, so it goes 3D first
    check('cg_set_mode_3d', jaxe.fmod_cg_set_mode(group, 0x10) === 0, '');
    const setCgDf = jaxe.fmod_cg_set_3d_distance_filter(group, true, 0.25, 900);
    check('cg_set_3d_distance_filter', setCgDf === 0, `result=${setCgDf}`);
    const gbuf = [0, 0, 0];
    const getCgDf = jaxe.fmod_cg_get_3d_distance_filter(group, gbuf);
    check('cg_get_3d_distance_filter', getCgDf === 0 && gbuf[0] === 1
        && Math.abs(gbuf[1] - 0.25) < 0.001 && Math.abs(gbuf[2] - 900) < 0.5,
        `result=${getCgDf} custom=${gbuf[0]} level=${gbuf[1]} freq=${gbuf[2]}`);
    check('cg_distance_filter_stale', jaxe.fmod_cg_get_3d_distance_filter(999999, gbuf) === 30, '');
    jaxe.fmod_cg_release(group);

    // --- sound data: openOnly is accepted, readData and seekData report 68 ---
    // The wav format limit of the web build makes Jump.wav fail to open,
    // so a raw PCM sound stands in for the handle-level checks
    const pcm = new Uint8Array(4096).buffer;
    const sound = jaxe.fmod_core_create_sound_pcm(pcm, 4096, 8000, 1);
    check('core_create_sound_pcm', sound > 0, `handle=${sound}`);
    const openOnly = jaxe.fmod_core_create_sound('Jump.wav', 0, true);
    check('core_create_sound_open_only_no_throw', openOnly === 0 || openOnly > 0,
        `handle=${openOnly} result=${jaxe.fmod_sys_last_result()}`);
    if (openOnly > 0) jaxe.fmod_core_release_sound(openOnly);
    const readBuf = new Uint8Array(256).buffer;
    const read = jaxe.fmod_core_sound_read_data(sound, readBuf, 256);
    check('core_sound_read_data_unsupported', read === -68 && jaxe.fmod_sys_last_result() === 68,
        `value=${read} result=${jaxe.fmod_sys_last_result()}`);
    check('core_sound_read_data_stale', jaxe.fmod_core_sound_read_data(999999, readBuf, 256) === -30, '');
    const seek = jaxe.fmod_core_sound_seek_data(sound, 0);
    check('core_sound_seek_data_unsupported', seek === 68, `result=${seek}`);
    check('core_sound_seek_data_stale', jaxe.fmod_core_sound_seek_data(999999, 0) === 30, '');
    jaxe.fmod_core_release_sound(sound);

    // --- recording: every entry point reports 68 on this target ---
    const ibuf = [7, 7, 7, 7];
    const drivers = jaxe.fmod_sys_get_record_num_drivers(ibuf);
    check('sys_get_record_num_drivers_unsupported', drivers === -1 && ibuf[0] === 0
        && jaxe.fmod_sys_last_result() === 68, `value=${drivers} result=${jaxe.fmod_sys_last_result()}`);
    const name = jaxe.fmod_sys_get_record_driver_info(0, ibuf);
    check('sys_get_record_driver_info_unsupported', name === '' && jaxe.fmod_sys_last_result() === 68,
        `result=${jaxe.fmod_sys_last_result()}`);
    const recSound = jaxe.fmod_core_create_record_sound(48000, 1, 1);
    check('core_create_record_sound_unsupported', recSound === 0 && jaxe.fmod_sys_last_result() === 68,
        `handle=${recSound} result=${jaxe.fmod_sys_last_result()}`);
    check('sys_record_start_unsupported', jaxe.fmod_sys_record_start(0, recSound, false) === 68, '');
    check('sys_record_stop_unsupported', jaxe.fmod_sys_record_stop(0) === 68, '');
    check('sys_is_recording_unsupported', jaxe.fmod_sys_is_recording(0) === false
        && jaxe.fmod_sys_last_result() === 68, '');
    check('sys_get_record_position_unsupported', jaxe.fmod_sys_get_record_position(0) === -1
        && jaxe.fmod_sys_last_result() === 68, '');

    await pump(3);
    check('no_handle_leaks_extras', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`EXTRAS_TEST: failures = ${failures}`);
    console.log('EXTRAS_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
