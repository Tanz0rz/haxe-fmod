// Runs the completeness-tail bindings of jaxe.js (sound cone and distances,
// DSP chain positions, fade point and mix matrix readback, group getters,
// sound group enumeration, system queries, DSP descriptors and channel
// formats, connection matrices) against the real FMOD 2.03.12 wasm under
// Node. The functions the web glue cannot serve must report 68
// (ERR_UNSUPPORTED) and return their empty value.
// Usage: node completeness-tail-harness.js  (needs FMOD_SDK_WEB)

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

jaxe.preRun = function () {};

// Node-safe init: NOSOUND output and no driver query
jaxe.onRuntimeInitialized = function () {
    try {
        var outval = {};
        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;
        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;
        jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
        jaxe.gSystem.initialize(64, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
        jaxe.FmodIsInitialized = true;
    } catch (e) {
        console.log('INIT THREW:', e.message);
        process.exit(1);
    }
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, cond, detail) {
    console.log(`TAIL_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}
function near(a, b) { return Math.abs(a - b) < 1e-3; }

async function pump(n) {
    for (let i = 0; i < n; i++) { jaxe.fmod_sys_update(); await new Promise(r => setTimeout(r, 10)); }
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    jaxe.FMOD['TOTAL_MEMORY'] = 64 * 1024 * 1024;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED:', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('TAIL_TEST: INIT TIMEOUT'); process.exit(1); }
    await pump(2);
    const baseline = jaxe.fmod_debug_live_handle_count();
    const fbuf = new Array(1024).fill(0);
    const ibuf = new Array(1024).fill(0);
    const UNSUPPORTED = 68;
    const INVALID_HANDLE = 30;
    const INVALID_PARAM = 31;

    // Sound cone and rolloff distances
    const pcm = new Uint8Array(9600).buffer;
    const sound = jaxe.fmod_core_create_sound_pcm(pcm, 9600, 48000, 1);
    check('core_create_sound_pcm', sound > 0, `handle=${sound}`);
    jaxe.fmod_sound_set_mode(sound, 0x10);
    check('core_sound_set_3d_cone_settings', jaxe.fmod_core_sound_set_3d_cone_settings(sound, 30, 60, 0.5) === 0, '');
    check('core_sound_get_3d_cone_settings', jaxe.fmod_core_sound_get_3d_cone_settings(sound, fbuf) === 0
        && near(fbuf[0], 30) && near(fbuf[1], 60) && near(fbuf[2], 0.5), `inside=${fbuf[0]} outside=${fbuf[1]} vol=${fbuf[2]}`);
    check('core_sound_set_3d_min_max', jaxe.fmod_core_sound_set_3d_min_max(sound, 2, 50) === 0, '');
    check('core_sound_get_3d_min_max', jaxe.fmod_core_sound_get_3d_min_max(sound, fbuf) === 0
        && near(fbuf[0], 2) && near(fbuf[1], 50), `min=${fbuf[0]} max=${fbuf[1]}`);
    check('core_sound_get_3d_min_max_bad_handle', jaxe.fmod_core_sound_get_3d_min_max(999999, fbuf) === INVALID_HANDLE, '');

    // Chain positions on a paused channel
    const channel = jaxe.fmod_core_play_sound(sound, true);
    check('core_play_sound', channel > 0, `handle=${channel}`);
    const lowpass = jaxe.fmod_dsp_create_by_type(3);
    const echo = jaxe.fmod_dsp_create_by_type(9);
    jaxe.fmod_chan_add_dsp(channel, 0, lowpass);
    jaxe.fmod_chan_add_dsp(channel, 0, echo);
    check('chan_get_dsp_index', jaxe.fmod_chan_get_dsp_index(channel, echo) === 0
        && jaxe.fmod_chan_get_dsp_index(channel, lowpass) === 1,
        `echo=${jaxe.fmod_chan_get_dsp_index(channel, echo)} lowpass=${jaxe.fmod_chan_get_dsp_index(channel, lowpass)}`);
    check('chan_set_dsp_index', jaxe.fmod_chan_set_dsp_index(channel, echo, 1) === 0
        && jaxe.fmod_chan_get_dsp_index(channel, echo) === 1, `echo=${jaxe.fmod_chan_get_dsp_index(channel, echo)}`);
    check('chan_get_dsp_index_bad_handle', jaxe.fmod_chan_get_dsp_index(channel, 999999) === -1
        && jaxe.fmod_sys_last_result() === INVALID_HANDLE, '');

    // Fade point and mix matrix readback: the glue cannot return either
    jaxe.fmod_chan_get_dsp_clock(channel, fbuf);
    jaxe.fmod_chan_add_fade_point(channel, fbuf[1] + 4800, 0.5);
    check('chan_get_fade_points (expect 68 unsupported)', jaxe.fmod_chan_get_fade_points(channel, fbuf) === 0
        && jaxe.fmod_sys_last_result() === UNSUPPORTED, `result=${jaxe.fmod_sys_last_result()}`);
    check('chan_get_fade_points_bad_handle', jaxe.fmod_chan_get_fade_points(999999, fbuf) === 0
        && jaxe.fmod_sys_last_result() === INVALID_HANDLE, '');
    fbuf[0] = 1; fbuf[1] = 0; fbuf[2] = 0; fbuf[3] = 1;
    check('chan_set_mix_matrix', jaxe.fmod_chan_set_mix_matrix(channel, fbuf, 2, 2) === 0, '');
    check('chan_get_mix_matrix (expect 68 unsupported)', jaxe.fmod_chan_get_mix_matrix(channel, fbuf, ibuf, 2, 2) === 0
        && jaxe.fmod_sys_last_result() === UNSUPPORTED, `result=${jaxe.fmod_sys_last_result()}`);

    // Group getter, group chain position, group readbacks
    const group = jaxe.fmod_cg_create('tail-group');
    check('chan_set_channel_group', jaxe.fmod_chan_set_channel_group(channel, group) === 0, '');
    check('chan_get_channel_group', jaxe.fmod_chan_get_channel_group(channel) === group,
        `got=${jaxe.fmod_chan_get_channel_group(channel)} set=${group}`);
    check('chan_get_channel_group_bad_handle', jaxe.fmod_chan_get_channel_group(999999) === 0
        && jaxe.fmod_sys_last_result() === INVALID_HANDLE, '');
    jaxe.fmod_cg_add_dsp(group, 0, lowpass);
    check('cg_get_dsp_index', jaxe.fmod_cg_get_dsp_index(group, lowpass) === 0, `value=${jaxe.fmod_cg_get_dsp_index(group, lowpass)}`);
    check('cg_set_dsp_index', jaxe.fmod_cg_set_dsp_index(group, lowpass, 0) === 0, '');
    check('cg_get_fade_points (expect 68 unsupported)', jaxe.fmod_cg_get_fade_points(group, fbuf) === 0
        && jaxe.fmod_sys_last_result() === UNSUPPORTED, `result=${jaxe.fmod_sys_last_result()}`);
    check('cg_get_mix_matrix (expect 68 unsupported)', jaxe.fmod_cg_get_mix_matrix(group, fbuf, ibuf, 2, 2) === 0
        && jaxe.fmod_sys_last_result() === UNSUPPORTED, `result=${jaxe.fmod_sys_last_result()}`);

    // Pool channel by index
    // FMOD hands back a pool slot reference of its own, so the handle is
    // separate from the playing channel's and shared by repeated calls
    const index = jaxe.fmod_chan_get_index(channel);
    const pooled = jaxe.fmod_sys_get_channel(index);
    check('sys_get_channel', index >= 0 && pooled > 0 && jaxe.fmod_chan_get_index(pooled) === index
        && jaxe.fmod_chan_get_paused(pooled) === true, `index=${index} pooled=${pooled} pooledIndex=${jaxe.fmod_chan_get_index(pooled)}`);
    check('sys_get_channel_dedup', jaxe.fmod_sys_get_channel(index) === pooled, '');
    check('sys_get_channel_bad_index', jaxe.fmod_sys_get_channel(-1) === 0, `result=${jaxe.fmod_sys_last_result()}`);

    // Sound group name and enumeration
    const soundGroup = jaxe.fmod_sys_create_sound_group('tail-sg');
    check('sg_get_name', jaxe.fmod_sg_get_name(soundGroup) === 'tail-sg', `name=${jaxe.fmod_sg_get_name(soundGroup)}`);
    check('sg_get_name_bad_handle', jaxe.fmod_sg_get_name(999999) === '' && jaxe.fmod_sys_last_result() === INVALID_HANDLE, '');
    jaxe.fmod_sound_set_sound_group(sound, soundGroup);
    check('sg_get_sound', jaxe.fmod_sg_get_sound(soundGroup, 0) === sound,
        `got=${jaxe.fmod_sg_get_sound(soundGroup, 0)} have=${sound}`);
    check('sg_get_sound_past_end', jaxe.fmod_sg_get_sound(soundGroup, 5) === 0, `result=${jaxe.fmod_sys_last_result()}`);

    // System queries
    check('sys_get_output', jaxe.fmod_sys_get_output() >= 0, `value=${jaxe.fmod_sys_get_output()}`);
    check('sys_get_speaker_mode_channels', jaxe.fmod_sys_get_speaker_mode_channels(3) === 2,
        `value=${jaxe.fmod_sys_get_speaker_mode_channels(3)}`);
    check('sys_get_default_mix_matrix (expect 68 unsupported)', jaxe.fmod_sys_get_default_mix_matrix(3, 3, 0, fbuf) === 0
        && jaxe.fmod_sys_last_result() === UNSUPPORTED, `result=${jaxe.fmod_sys_last_result()}`);

    // DSP descriptors and channel formats
    check('dsp_get_parameter_info (expect 68 unsupported)', jaxe.fmod_dsp_get_parameter_info(lowpass, 0, fbuf, ibuf) === ''
        && jaxe.fmod_sys_last_result() === UNSUPPORTED && ibuf[0] === 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_get_parameter_info_bad_handle', jaxe.fmod_dsp_get_parameter_info(999999, 0, fbuf, ibuf) === ''
        && jaxe.fmod_sys_last_result() === INVALID_HANDLE, '');
    const fft = jaxe.fmod_dsp_create_by_type(26);
    check('dsp_get_data_parameter_index', jaxe.fmod_dsp_get_data_parameter_index(fft, -4) >= 0,
        `value=${jaxe.fmod_dsp_get_data_parameter_index(fft, -4)}`);
    check('dsp_get_data_parameter_index_missing', jaxe.fmod_dsp_get_data_parameter_index(lowpass, -4) === -1
        && jaxe.fmod_sys_last_result() === INVALID_PARAM, `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_set_channel_format', jaxe.fmod_dsp_set_channel_format(echo, 0, 2, 3) === 0, '');
    check('dsp_get_channel_format', jaxe.fmod_dsp_get_channel_format(echo, ibuf) === 0
        && ibuf[1] === 2 && ibuf[2] === 3, `mask=${ibuf[0]} channels=${ibuf[1]} mode=${ibuf[2]}`);
    check('dsp_get_output_channel_format', jaxe.fmod_dsp_get_output_channel_format(echo, 0, 2, 3, ibuf) === 0
        && ibuf[1] === 2, `channels=${ibuf[1]} mode=${ibuf[2]}`);

    // Connection matrices
    const osc = jaxe.fmod_dsp_create_by_type(2);
    const conn = jaxe.fmod_dsp_add_input(fft, osc, 0);
    check('dsp_add_input', conn > 0, `handle=${conn}`);
    fbuf[0] = 0.5; fbuf[1] = 0; fbuf[2] = 0; fbuf[3] = 0.5;
    check('conn_set_mix_matrix', jaxe.fmod_conn_set_mix_matrix(conn, fbuf, 2, 2) === 0, '');
    check('conn_set_mix_matrix_bad_size', jaxe.fmod_conn_set_mix_matrix(conn, fbuf, 40, 40) === INVALID_PARAM, '');
    check('conn_get_mix_matrix (expect 68 unsupported)', jaxe.fmod_conn_get_mix_matrix(conn, fbuf, ibuf, 2, 2) === 0
        && jaxe.fmod_sys_last_result() === UNSUPPORTED, `result=${jaxe.fmod_sys_last_result()}`);
    check('conn_get_mix_matrix_bad_handle', jaxe.fmod_conn_get_mix_matrix(999999, fbuf, ibuf, 2, 2) === 0
        && jaxe.fmod_sys_last_result() === INVALID_HANDLE, '');

    jaxe.fmod_dsp_disconnect_from(fft, osc);
    jaxe.fmod_chan_stop(channel);
    jaxe.fmod_chan_stop(pooled);
    jaxe.fmod_dsp_release(osc);
    jaxe.fmod_dsp_release(fft);
    jaxe.fmod_dsp_release(echo);
    jaxe.fmod_dsp_release(lowpass);
    jaxe.fmod_cg_release(group);
    jaxe.fmod_core_release_sound(sound);
    jaxe.fmod_sg_release(soundGroup);
    await pump(3);
    check('no_handle_leaks_completeness_tail', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`TAIL_TEST: failures = ${failures}`);
    console.log('TAIL_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
