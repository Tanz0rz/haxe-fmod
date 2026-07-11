// Exercises the Core PCM stream and channel surface of jaxe.js against the
// real FMOD 2.03.12 wasm: ring write/drain through a live OPENUSER sound,
// channel control round-trips, underrun accounting, and handle lifetime.
// Uses NOSOUND_NRT output so update() pumps the mixer deterministically and
// pcmread demand is driven from this script.
// Usage: node pcm-harness.js  (needs FMOD_SDK_WEB)

const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

const BANKS = path.join(REPO, 'example-project', 'EZPlatformer', 'assets', 'fmod', 'Desktop');
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
    jaxe.gSystem.initialize(256, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    var b = {};
    jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.loadedBanks['Master.bank'] = b.val;
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.loadedBanks['Master.strings.bank'] = b.val;
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, cond, detail) {
    console.log(`PCM_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) { failures++; process.exitCode = 1; }
}

function pump(n) {
    for (let i = 0; i < n; i++) jaxe.gSystem.update();
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('PCM_TEST: INIT TIMEOUT'); process.exit(1); }
    console.log('PCM_TEST: initialized');

    // The pcmread copy needs the module heap view
    check('heapu8_exported', jaxe.FMOD.HEAPU8 instanceof Uint8Array,
        `typeof=${typeof jaxe.FMOD.HEAPU8}`);

    // Bad args are rejected before any FMOD call
    check('pcm_create_bad_args', jaxe.fmod_core_pcm_create(0, 1, 4096) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_PARAM);

    const RATE = 48000;
    const ps = jaxe.fmod_core_pcm_create(RATE, 1, 65536);
    check('pcm_create', ps !== 0, `handle=${ps} result=${jaxe.lastResult}`);
    if (ps === 0) { process.exit(1); }

    // Half a second of a 440Hz sine (16-bit mono) fed through the ring
    const samples = Math.floor(RATE * 0.5);
    const buf = new ArrayBuffer(samples * 2);
    const view = new Int16Array(buf);
    for (let i = 0; i < samples; i++) {
        view[i] = Math.round(Math.sin(2 * Math.PI * 440 * i / RATE) * 0x6000);
    }
    const spaceBefore = jaxe.fmod_core_pcm_space(ps);
    const wrote = jaxe.fmod_core_pcm_write(ps, buf, buf.byteLength);
    check('pcm_write', wrote === Math.min(buf.byteLength, spaceBefore),
        `wrote=${wrote} space=${spaceBefore}`);
    check('pcm_space_shrinks', jaxe.fmod_core_pcm_space(ps) === spaceBefore - wrote);

    const ch = jaxe.fmod_core_pcm_play(ps, false);
    check('pcm_play', ch !== 0, `handle=${ch} result=${jaxe.lastResult}`);

    // NRT updates make the mixer drain the ring through pcmread
    pump(30);
    const spaceAfter = jaxe.fmod_core_pcm_space(ps);
    check('mixer_drained_ring', spaceAfter > spaceBefore - wrote,
        `before=${spaceBefore - wrote} after=${spaceAfter}`);

    // Channel round-trips
    check('chan_set_volume', jaxe.fmod_chan_set_volume(ch, 0.5) === jaxe.FMOD.OK);
    check('chan_get_volume', Math.abs(jaxe.fmod_chan_get_volume(ch) - 0.5) < 0.001,
        `value=${jaxe.fmod_chan_get_volume(ch)}`);
    check('chan_set_pitch', jaxe.fmod_chan_set_pitch(ch, 1.5) === jaxe.FMOD.OK);
    check('chan_get_pitch', Math.abs(jaxe.fmod_chan_get_pitch(ch) - 1.5) < 0.001,
        `value=${jaxe.fmod_chan_get_pitch(ch)}`);
    check('chan_is_playing', jaxe.fmod_chan_is_playing(ch) === true);
    check('chan_set_paused', jaxe.fmod_chan_set_paused(ch, true) === jaxe.FMOD.OK);
    check('chan_get_paused', jaxe.fmod_chan_get_paused(ch) === true);
    jaxe.fmod_chan_set_paused(ch, false);

    // Drain past empty: reads must pad with silence and count underruns
    pump(200);
    const under = jaxe.fmod_core_pcm_underruns(ps);
    check('underruns_counted', under > 0, `underruns=${under}`);
    check('underruns_cleared', jaxe.fmod_core_pcm_underruns(ps) === 0);

    // Stop frees the channel slot even when FMOD already dropped the channel
    const stopRes = jaxe.fmod_chan_stop(ch);
    check('chan_stop', typeof stopRes === 'number', `result=${stopRes}`);
    check('chan_handle_freed', jaxe.fmod_chan_set_volume(ch, 1.0) === jaxe.ERR_INVALID_HANDLE);

    check('pcm_release', jaxe.fmod_core_pcm_release(ps) === jaxe.FMOD.OK,
        `result=${jaxe.lastResult}`);
    check('pcm_handle_freed', jaxe.fmod_core_pcm_space(ps) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_HANDLE);

    // Stale handles across the whole new surface return the handle error
    check('stale_pcm_write', jaxe.fmod_core_pcm_write(ps, buf, 4) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_HANDLE);
    check('stale_pcm_play', jaxe.fmod_core_pcm_play(ps, false) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_HANDLE);
    check('stale_chan_getters', jaxe.fmod_chan_get_volume(ch) === 0.0
        && jaxe.fmod_chan_is_playing(ch) === false
        && jaxe.fmod_chan_get_paused(ch) === false);

    testDspSurface();
    testChannelGroups();
    testBusBridge();
    testReverbAndExtras();
    testConnectionGraph();
    testNestingAndScheduling();
    testReverb3dSoundsSystem();
    testCallbacksAndSyncPoints();
    testSoundGroupsAndSystem();
    testGetterSymmetry();

    console.log(`PCM_TEST: failures = ${failures}`);
    console.log('PCM_TEST: COMPLETE');
    process.exit(failures ? 1 : 0);
}

function testDspSurface() {
    // Oscillator through sys_play_dsp feeds the analyzers a real 1kHz tone
    const osc = jaxe.fmod_dsp_create_by_type(2 /* OSCILLATOR */);
    check('dsp_create', osc !== 0, `handle=${osc} result=${jaxe.lastResult}`);
    check('dsp_set_param_int', jaxe.fmod_dsp_set_param_int(osc, 0, 0) === jaxe.FMOD.OK);
    check('dsp_get_param_int', jaxe.fmod_dsp_get_param_int(osc, 0) === 0);
    check('dsp_set_param_float', jaxe.fmod_dsp_set_param_float(osc, 1, 1000.0) === jaxe.FMOD.OK);
    check('dsp_get_param_float', Math.abs(jaxe.fmod_dsp_get_param_float(osc, 1) - 1000.0) < 0.01,
        `value=${jaxe.fmod_dsp_get_param_float(osc, 1)}`);
    check('dsp_get_type', jaxe.fmod_dsp_get_type(osc) === 2, `value=${jaxe.fmod_dsp_get_type(osc)}`);
    check('dsp_get_num_params', jaxe.fmod_dsp_get_num_params(osc) > 0,
        `value=${jaxe.fmod_dsp_get_num_params(osc)}`);
    check('dsp_set_bypass', jaxe.fmod_dsp_set_bypass(osc, true) === jaxe.FMOD.OK);
    check('dsp_get_bypass', jaxe.fmod_dsp_get_bypass(osc) === true);
    jaxe.fmod_dsp_set_bypass(osc, false);
    check('dsp_set_wet_dry_mix', jaxe.fmod_dsp_set_wet_dry_mix(osc, 1, 1, 0) === jaxe.FMOD.OK);
    check('dsp_set_active', jaxe.fmod_dsp_set_active(osc, true) === jaxe.FMOD.OK);
    check('dsp_reset', jaxe.fmod_dsp_reset(osc) === jaxe.FMOD.OK);

    const ch = jaxe.fmod_sys_play_dsp(osc, false);
    check('sys_play_dsp', ch !== 0, `handle=${ch} result=${jaxe.lastResult}`);

    // FFT attached to the master group must see the tone
    const fft = jaxe.fmod_dsp_create_by_type(26 /* FFT */);
    const master = jaxe.fmod_cg_get_master();
    check('cg_get_master', master !== 0, `handle=${master}`);
    check('cg_add_dsp', jaxe.fmod_cg_add_dsp(master, 0, fft) === jaxe.FMOD.OK);
    check('dsp_set_metering_enabled', jaxe.fmod_dsp_set_metering_enabled(fft, true, true) === jaxe.FMOD.OK);
    pump(40);

    const spectrum = [];
    const bins = jaxe.fmod_dsp_fft_get_spectrum(fft, spectrum, 512);
    let maxI = 0;
    for (let i = 1; i < bins; i++) if (spectrum[i] > spectrum[maxI]) maxI = i;
    check('dsp_fft_get_spectrum', bins > 0 && maxI > 0, `bins=${bins} peak_bin=${maxI}`);

    const meters = [];
    const channels = jaxe.fmod_dsp_get_metering(fft, meters);
    check('dsp_get_metering', channels > 0 && meters[0] > 0.01,
        `channels=${channels} peak0=${meters[0]}`);

    check('cg_remove_dsp', jaxe.fmod_cg_remove_dsp(master, fft) === jaxe.FMOD.OK);
    check('dsp_release', jaxe.fmod_dsp_release(fft) === jaxe.FMOD.OK);
    jaxe.fmod_chan_stop(ch);
    check('dsp_release_osc', jaxe.fmod_dsp_release(osc) === jaxe.FMOD.OK);
    check('stale_dsp', jaxe.fmod_dsp_set_param_float(osc, 1, 500) === jaxe.ERR_INVALID_HANDLE);
    pump(5);
}

function testChannelGroups() {
    const group = jaxe.fmod_cg_create('pcm-harness-sub');
    check('cg_create', group !== 0, `handle=${group}`);
    check('cg_set_volume', jaxe.fmod_cg_set_volume(group, 0.5) === jaxe.FMOD.OK);
    check('cg_get_volume', Math.abs(jaxe.fmod_cg_get_volume(group) - 0.5) < 0.001);
    check('cg_set_pitch', jaxe.fmod_cg_set_pitch(group, 1.25) === jaxe.FMOD.OK);
    check('cg_get_pitch', Math.abs(jaxe.fmod_cg_get_pitch(group) - 1.25) < 0.001);
    check('cg_set_mute', jaxe.fmod_cg_set_mute(group, true) === jaxe.FMOD.OK);
    check('cg_get_mute', jaxe.fmod_cg_get_mute(group) === true);
    jaxe.fmod_cg_set_mute(group, false);
    check('cg_set_paused', jaxe.fmod_cg_set_paused(group, true) === jaxe.FMOD.OK);
    check('cg_get_paused', jaxe.fmod_cg_get_paused(group) === true);
    jaxe.fmod_cg_set_paused(group, false);

    // Route a PCM stream channel into the group, then stop everything in it
    const ps = jaxe.fmod_core_pcm_create(48000, 1, 9600);
    const ch = jaxe.fmod_core_pcm_play(ps, true);
    check('chan_set_channel_group', jaxe.fmod_chan_set_channel_group(ch, group) === jaxe.FMOD.OK);
    check('cg_stop', jaxe.fmod_cg_stop(group) === jaxe.FMOD.OK);
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_core_pcm_release(ps);

    check('cg_release', jaxe.fmod_cg_release(group) === jaxe.FMOD.OK);
    check('stale_cg', jaxe.fmod_cg_set_volume(group, 1.0) === jaxe.ERR_INVALID_HANDLE);

    // The master group dedups to one handle and survives lookups
    const m1 = jaxe.fmod_cg_get_master();
    const m2 = jaxe.fmod_cg_get_master();
    check('cg_master_dedup', m1 !== 0 && m1 === m2, `m1=${m1} m2=${m2}`);
    pump(5);
}

function testBusBridge() {
    const bus = jaxe.fmod_sys_get_bus('bus:/');
    check('bridge_get_bus', bus !== 0, `handle=${bus}`);
    check('bus_lock_channel_group', jaxe.fmod_bus_lock_channel_group(bus) === jaxe.FMOD.OK);
    const group = jaxe.fmod_bus_get_channel_group(bus);
    check('bus_get_channel_group', group !== 0, `handle=${group} result=${jaxe.lastResult}`);

    const lowpass = jaxe.fmod_dsp_create_by_type(18 /* LOWPASS_SIMPLE */);
    check('bus_group_add_dsp', jaxe.fmod_cg_add_dsp(group, 0, lowpass) === jaxe.FMOD.OK);
    pump(5);
    check('bus_group_remove_dsp', jaxe.fmod_cg_remove_dsp(group, lowpass) === jaxe.FMOD.OK);
    jaxe.fmod_dsp_release(lowpass);

    check('bus_unlock_channel_group', jaxe.fmod_bus_unlock_channel_group(bus) === jaxe.FMOD.OK);
    pump(5);
}

function testReverbAndExtras() {
    // Reverb properties round-trip through the 12-float buffer
    const props = [];
    check('sys_get_reverb', jaxe.fmod_sys_get_reverb_properties(0, props) === jaxe.FMOD.OK
        && typeof props[0] === 'number', `DecayTime=${props[0]}`);
    props[0] = 2900;
    check('sys_set_reverb', jaxe.fmod_sys_set_reverb_properties(0, props) === jaxe.FMOD.OK);
    const back = [];
    jaxe.fmod_sys_get_reverb_properties(0, back);
    check('sys_reverb_roundtrip', Math.abs(back[0] - 2900) < 1, `DecayTime=${back[0]}`);
    back[11] = -80;
    jaxe.fmod_sys_set_reverb_properties(0, back);

    // Channel extras on a fresh paused stream
    const ps = jaxe.fmod_core_pcm_create(48000, 1, 9600);
    const ch = jaxe.fmod_core_pcm_play(ps, true);
    check('chan_set_pan', jaxe.fmod_chan_set_pan(ch, 0.5) === jaxe.FMOD.OK);
    check('chan_set_frequency', jaxe.fmod_chan_set_frequency(ch, 24000) === jaxe.FMOD.OK);
    check('chan_get_frequency', Math.abs(jaxe.fmod_chan_get_frequency(ch) - 24000) < 1);
    check('chan_set_loop_count', jaxe.fmod_chan_set_loop_count(ch, -1) === jaxe.FMOD.OK);
    check('chan_get_position', jaxe.fmod_chan_get_position(ch) >= 0);
    check('chan_set_position', jaxe.fmod_chan_set_position(ch, 0) === jaxe.FMOD.OK);
    check('chan_set_reverb_wet', jaxe.fmod_chan_set_reverb_wet(ch, 0, 0.5) === jaxe.FMOD.OK);
    check('chan_add_remove_dsp', (() => {
        const echo = jaxe.fmod_dsp_create_by_type(6 /* ECHO */);
        const added = jaxe.fmod_chan_add_dsp(ch, 0, echo) === jaxe.FMOD.OK;
        pump(3);
        const removed = jaxe.fmod_chan_remove_dsp(ch, echo) === jaxe.FMOD.OK;
        jaxe.fmod_dsp_release(echo);
        return added && removed;
    })());
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_core_pcm_release(ps);

    // 3D PCM stream accepts positional control
    const ps3d = jaxe.fmod_core_pcm_create_3d(48000, 1, 9600);
    check('pcm_create_3d', ps3d !== 0, `handle=${ps3d} result=${jaxe.lastResult}`);
    const ch3d = jaxe.fmod_core_pcm_play(ps3d, true);
    check('chan_set_3d_attributes',
        jaxe.fmod_chan_set_3d_attributes(ch3d, 1, 0, 0, 0, 0, 0) === jaxe.FMOD.OK);
    check('chan_set_3d_min_max', jaxe.fmod_chan_set_3d_min_max(ch3d, 1, 100) === jaxe.FMOD.OK);
    jaxe.fmod_chan_stop(ch3d);
    jaxe.fmod_core_pcm_release(ps3d);
    pump(5);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });

//// Slice-3 shim surface against the real wasm

function testConnectionGraph() {
    const osc = jaxe.fmod_dsp_create_by_type(2);
    const lp = jaxe.fmod_dsp_create_by_type(18);
    const conn = jaxe.fmod_dsp_add_input(lp, osc, 0);
    check('s3_dsp_add_input', conn !== 0, `handle=${conn} result=${jaxe.lastResult}`);
    check('s3_conn_set_mix', jaxe.fmod_dspconn_set_mix(conn, 0.5) === jaxe.FMOD.OK);
    check('s3_conn_get_mix', Math.abs(jaxe.fmod_dspconn_get_mix(conn) - 0.5) < 0.001,
        `value=${jaxe.fmod_dspconn_get_mix(conn)}`);
    check('s3_conn_get_type', jaxe.fmod_dspconn_get_type(conn) === 0,
        `value=${jaxe.fmod_dspconn_get_type(conn)}`);
    check('s3_num_inputs', jaxe.fmod_dsp_get_num_inputs(lp) === 1);
    check('s3_num_outputs', jaxe.fmod_dsp_get_num_outputs(osc) === 1);
    const inputDsp = jaxe.fmod_dsp_get_input_dsp(lp, 0);
    check('s3_input_dsp_dedup', inputDsp === osc, `input=${inputDsp} osc=${osc}`);
    const inputConn = jaxe.fmod_dsp_get_input_connection(lp, 0);
    check('s3_input_conn_dedup', inputConn === conn, `conn=${inputConn} orig=${conn}`);
    check('s3_disconnect', jaxe.fmod_dsp_disconnect_from(lp, osc) === jaxe.FMOD.OK);
    // The sweep after disconnect reclaims the dead connection handle
    check('s3_stale_conn', jaxe.fmod_dspconn_set_mix(conn, 1.0) === jaxe.ERR_INVALID_HANDLE);
    jaxe.fmod_dsp_release(lp);
    jaxe.fmod_dsp_release(osc);
}

function testNestingAndScheduling() {
    const parent = jaxe.fmod_cg_create('s3-parent');
    const child = jaxe.fmod_cg_create('s3-child');
    check('s3_cg_add_group', jaxe.fmod_cg_add_group(parent, child) === jaxe.FMOD.OK);
    check('s3_cg_num_groups', jaxe.fmod_cg_get_num_groups(parent) === 1);
    check('s3_cg_get_group_dedup', jaxe.fmod_cg_get_group(parent, 0) === child);
    check('s3_cg_get_parent_dedup', jaxe.fmod_cg_get_parent_group(child) === parent);

    const osc = jaxe.fmod_dsp_create_by_type(2);
    const ch = jaxe.fmod_sys_play_dsp(osc, false);
    pump(10);
    const clocks = [];
    check('s3_chan_dsp_clock', jaxe.fmod_chan_get_dsp_clock(ch, clocks) === jaxe.FMOD.OK
        && clocks[1] > 0, `clock=${clocks[0]} parent=${clocks[1]}`);
    const base = clocks[1];
    check('s3_chan_set_delay', jaxe.fmod_chan_set_delay(ch, 0, base + 96000, false) === jaxe.FMOD.OK);
    check('s3_chan_fade_points', jaxe.fmod_chan_add_fade_point(ch, base + 4800, 1.0) === jaxe.FMOD.OK
        && jaxe.fmod_chan_add_fade_point(ch, base + 48000, 0.0) === jaxe.FMOD.OK);
    check('s3_chan_fade_ramp', jaxe.fmod_chan_set_fade_point_ramp(ch, base + 9600, 0.5) === jaxe.FMOD.OK);
    check('s3_chan_remove_fades', jaxe.fmod_chan_remove_fade_points(ch, 0, base + 96000) === jaxe.FMOD.OK);

    const gclocks = [];
    check('s3_cg_dsp_clock', jaxe.fmod_cg_get_dsp_clock(parent, gclocks) === jaxe.FMOD.OK);
    check('s3_cg_fades', jaxe.fmod_cg_add_fade_point(parent, base + 4800, 0.5) === jaxe.FMOD.OK
        && jaxe.fmod_cg_remove_fade_points(parent, 0, base + 96000) === jaxe.FMOD.OK
        && jaxe.fmod_cg_set_delay(parent, 0, base + 96000, false) === jaxe.FMOD.OK
        && jaxe.fmod_cg_set_fade_point_ramp(parent, base + 9600, 0.5) === jaxe.FMOD.OK);

    // Channel extras
    check('s3_chan_mute', jaxe.fmod_chan_set_mute(ch, true) === jaxe.FMOD.OK
        && jaxe.fmod_chan_get_mute(ch) === true);
    check('s3_chan_low_pass_gain', jaxe.fmod_chan_set_low_pass_gain(ch, 0.5) === jaxe.FMOD.OK);
    check('s3_chan_mix_matrix', jaxe.fmod_chan_set_mix_matrix(ch, [1, 0, 0, 1], 2, 2) === jaxe.FMOD.OK);
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_dsp_release(osc);
    jaxe.fmod_cg_release(child);
    jaxe.fmod_cg_release(parent);

    // 3D spatial extras on a positional stream
    const ps = jaxe.fmod_core_pcm_create_3d(48000, 1, 9600);
    const ch3 = jaxe.fmod_core_pcm_play(ps, true);
    check('s3_cone_settings', jaxe.fmod_chan_set_3d_cone_settings(ch3, 30, 60, 0.5) === jaxe.FMOD.OK);
    check('s3_cone_orientation', jaxe.fmod_chan_set_3d_cone_orientation(ch3, 0, 0, 1) === jaxe.FMOD.OK);
    check('s3_occlusion', jaxe.fmod_chan_set_3d_occlusion(ch3, 0.5, 0.3) === jaxe.FMOD.OK);
    const occ = [];
    jaxe.fmod_chan_get_3d_occlusion(ch3, occ);
    check('s3_occlusion_roundtrip', Math.abs(occ[0] - 0.5) < 0.001 && Math.abs(occ[1] - 0.3) < 0.001,
        `direct=${occ[0]} reverb=${occ[1]}`);
    check('s3_spread', jaxe.fmod_chan_set_3d_spread(ch3, 45) === jaxe.FMOD.OK);
    check('s3_3d_level', jaxe.fmod_chan_set_3d_level(ch3, 0.8) === jaxe.FMOD.OK);
    check('s3_doppler', jaxe.fmod_chan_set_3d_doppler_level(ch3, 1.0) === jaxe.FMOD.OK);
    check('s3_set_mode', jaxe.fmod_chan_set_mode(ch3, (jaxe.FMOD._3D | jaxe.FMOD._3D_LINEARROLLOFF) >>> 0) === jaxe.FMOD.OK);
    jaxe.fmod_chan_stop(ch3);
    jaxe.fmod_core_pcm_release(ps);
    pump(5);
}

function testReverb3dSoundsSystem() {
    const rv = jaxe.fmod_sys_create_reverb3d();
    check('s3_r3d_create', rv !== 0, `handle=${rv} result=${jaxe.lastResult}`);
    check('s3_r3d_attributes', jaxe.fmod_r3d_set_3d_attributes(rv, 0, 0, 0, 5, 20) === jaxe.FMOD.OK);
    const props = [];
    jaxe.fmod_sys_get_reverb_properties(0, props);
    check('s3_r3d_set_props', jaxe.fmod_r3d_set_properties(rv, props) === jaxe.FMOD.OK);
    const back = [];
    check('s3_r3d_get_props', jaxe.fmod_r3d_get_properties(rv, back) === jaxe.FMOD.OK
        && typeof back[0] === 'number', `DecayTime=${back[0]}`);
    check('s3_r3d_active', jaxe.fmod_r3d_set_active(rv, true) === jaxe.FMOD.OK);
    check('s3_r3d_release', jaxe.fmod_r3d_release(rv) === jaxe.FMOD.OK);
    check('s3_stale_r3d', jaxe.fmod_r3d_set_active(rv, false) === jaxe.ERR_INVALID_HANDLE);

    // fromPcm: a raw memory sound plays through a channel
    const frames = 4800;
    const buf = new ArrayBuffer(frames * 2);
    const view = new Int16Array(buf);
    for (let i = 0; i < frames; i++) view[i] = Math.round(Math.sin(2 * Math.PI * 440 * i / 48000) * 0x3000);
    const snd = jaxe.fmod_core_create_sound_pcm(buf, buf.byteLength, 48000, 1);
    check('s3_sound_pcm_create', snd !== 0, `handle=${snd} result=${jaxe.lastResult}`);
    check('s3_sound_defaults', jaxe.fmod_sound_set_defaults(snd, 24000, 128) === jaxe.FMOD.OK);
    const defs = [];
    jaxe.fmod_sound_get_defaults(snd, defs);
    check('s3_sound_defaults_roundtrip', Math.abs(defs[0] - 24000) < 1 && defs[1] === 128,
        `freq=${defs[0]} priority=${defs[1]}`);
    check('s3_sound_mode', jaxe.fmod_sound_set_mode(snd, jaxe.FMOD.LOOP_NORMAL >>> 0) === jaxe.FMOD.OK
        && (jaxe.fmod_sound_get_mode(snd) & jaxe.FMOD.LOOP_NORMAL) !== 0);
    check('s3_sound_loop_points', jaxe.fmod_sound_set_loop_points(snd, 10, 90) === jaxe.FMOD.OK);
    const loops = [];
    jaxe.fmod_sound_get_loop_points(snd, loops);
    check('s3_sound_loop_roundtrip', loops[0] === 10 && loops[1] === 90,
        `start=${loops[0]} end=${loops[1]}`);
    const format = [];
    jaxe.fmod_sound_get_format(snd, format);
    check('s3_sound_format', format[0] === 1 && format[1] === 16, `ch=${format[0]} bits=${format[1]}`);
    check('s3_sound_open_state', jaxe.fmod_sound_get_open_state(snd) === 0,
        `state=${jaxe.fmod_sound_get_open_state(snd)}`);
    const playCh = jaxe.fmod_core_play_sound(snd, true);
    check('s3_play_sound', playCh !== 0, `handle=${playCh} result=${jaxe.lastResult}`);
    jaxe.fmod_chan_stop(playCh);
    check('s3_sound_release', jaxe.fmod_core_release_sound(snd) === jaxe.FMOD.OK);

    // System extras
    const playing = [];
    check('s3_channels_playing', jaxe.fmod_sys_get_channels_playing(playing) === jaxe.FMOD.OK,
        `all=${playing[0]} real=${playing[1]}`);
    check('s3_mixer_suspend_resume', jaxe.fmod_sys_mixer_suspend() === jaxe.FMOD.OK
        && jaxe.fmod_sys_mixer_resume() === jaxe.FMOD.OK);
    const swfmt = [];
    check('s3_software_format', jaxe.fmod_sys_get_software_format(swfmt) === jaxe.FMOD.OK
        && swfmt[0] > 0, `rate=${swfmt[0]}`);
    const dsp = jaxe.fmod_dsp_create_by_type(18);
    const cpu = [];
    const cpuResult = jaxe.fmod_dsp_get_cpu_usage(dsp, cpu);
    check('s3_dsp_cpu_usage_shape', cpuResult === jaxe.FMOD.OK || cpuResult === 1,
        `result=${cpuResult} (BADCOMMAND without profiling init is legitimate)`);
    jaxe.fmod_dsp_release(dsp);
    pump(5);
}

//// Slice-4 shim surface against the real wasm

function testCallbacksAndSyncPoints() {
    // A finite pcm memory sound so END fires
    const frames = 4800;
    const buf = new ArrayBuffer(frames * 2);
    const snd = jaxe.fmod_core_create_sound_pcm(buf, buf.byteLength, 48000, 1);
    check('s4_sync_add', jaxe.fmod_sound_add_sync_point(snd, 50, 'mid') === jaxe.FMOD.OK);
    check('s4_sync_count', jaxe.fmod_sound_get_num_sync_points(snd) === 1);
    check('s4_sync_name', jaxe.fmod_sound_get_sync_point_name(snd, 0) === 'mid',
        `name=${jaxe.fmod_sound_get_sync_point_name(snd, 0)}`);
    check('s4_sync_offset', jaxe.fmod_sound_get_sync_point_offset(snd, 0) === 50,
        `offset=${jaxe.fmod_sound_get_sync_point_offset(snd, 0)}`);

    const ch = jaxe.fmod_core_play_sound(snd, false);
    check('s4_set_callback', jaxe.fmod_chan_set_callback(ch, true) === jaxe.FMOD.OK);
    pump(40);
    // Drain the queue: both channel events must arrive with the channel handle
    let sawSync = false;
    let sawEnd = false;
    while (jaxe.fmod_cb_next()) {
        const h = jaxe.fmod_cb_handle();
        const t = jaxe.fmod_cb_type();
        if (h === ch && t === jaxe.CB_CHAN_SYNCPOINT && jaxe.fmod_cb_int(0) === 0) sawSync = true;
        if (h === ch && t === jaxe.CB_CHAN_END) sawEnd = true;
    }
    check('s4_callback_syncpoint', sawSync, '');
    check('s4_callback_end', sawEnd, '');
    check('s4_sync_delete', jaxe.fmod_sound_delete_sync_point(snd, 0) === jaxe.FMOD.OK
        && jaxe.fmod_sound_get_num_sync_points(snd) === 0, '');
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_core_release_sound(snd);
    pump(5);
}

function testSoundGroupsAndSystem() {
    const sg = jaxe.fmod_sys_create_sound_group('pcm-harness-sg');
    check('s4_sg_create', sg !== 0, `handle=${sg}`);
    check('s4_sg_max_audible', jaxe.fmod_sg_set_max_audible(sg, 2) === jaxe.FMOD.OK
        && jaxe.fmod_sg_get_max_audible(sg) === 2, '');
    check('s4_sg_behavior', jaxe.fmod_sg_set_max_audible_behavior(sg, 2) === jaxe.FMOD.OK
        && jaxe.fmod_sg_get_max_audible_behavior(sg) === 2, '');
    check('s4_sg_mute_fade', jaxe.fmod_sg_set_mute_fade_speed(sg, 0.5) === jaxe.FMOD.OK);

    const buf = new ArrayBuffer(9600);
    const snd = jaxe.fmod_core_create_sound_pcm(buf, buf.byteLength, 48000, 1);
    check('s4_sg_assign', jaxe.fmod_sound_set_sound_group(snd, sg) === jaxe.FMOD.OK);
    check('s4_sg_num_sounds', jaxe.fmod_sg_get_num_sounds(sg) === 1);
    check('s4_sg_stop', jaxe.fmod_sg_stop(sg) === jaxe.FMOD.OK);

    const master = jaxe.fmod_sys_get_master_sound_group();
    check('s4_sg_master_dedup', master !== 0 && master === jaxe.fmod_sys_get_master_sound_group(),
        `handle=${master}`);
    jaxe.fmod_sound_set_sound_group(snd, master);
    check('s4_sg_release', jaxe.fmod_sg_release(sg) === jaxe.FMOD.OK);
    check('s4_stale_sg', jaxe.fmod_sg_stop(sg) === jaxe.ERR_INVALID_HANDLE);
    jaxe.fmod_core_release_sound(snd);

    check('s4_3d_settings', jaxe.fmod_sys_set_3d_settings(1.5, 1.0, 1.0) === jaxe.FMOD.OK);
    const settings = [];
    jaxe.fmod_sys_get_3d_settings(settings);
    check('s4_3d_settings_roundtrip', Math.abs(settings[0] - 1.5) < 0.001, `doppler=${settings[0]}`);
    jaxe.fmod_sys_set_3d_settings(1.0, 1.0, 1.0);

    check('s4_num_drivers', jaxe.fmod_sys_get_num_drivers() >= 1);
    const driverName = jaxe.fmod_sys_get_driver_name(0);
    check('s4_driver_name', typeof driverName === 'string' && driverName.length > 0,
        `name=${driverName}`);
}

function testGetterSymmetry() {
    const ps = jaxe.fmod_core_pcm_create_3d(48000, 1, 9600);
    const ch = jaxe.fmod_core_pcm_play(ps, true);
    jaxe.fmod_chan_set_loop_count(ch, -1);
    check('s4_get_loop_count', jaxe.fmod_chan_get_loop_count(ch) === -1);
    jaxe.fmod_chan_set_low_pass_gain(ch, 0.5);
    check('s4_get_low_pass_gain', Math.abs(jaxe.fmod_chan_get_low_pass_gain(ch) - 0.5) < 0.001);
    check('s4_get_mode', jaxe.fmod_chan_get_mode(ch) !== 0, `mode=${jaxe.fmod_chan_get_mode(ch)}`);
    jaxe.fmod_chan_set_3d_cone_settings(ch, 30, 60, 0.5);
    const cone = [];
    jaxe.fmod_chan_get_3d_cone_settings(ch, cone);
    check('s4_get_cone', Math.abs(cone[0] - 30) < 0.1 && Math.abs(cone[1] - 60) < 0.1,
        `inside=${cone[0]} outside=${cone[1]}`);
    jaxe.fmod_chan_set_3d_spread(ch, 45);
    check('s4_get_spread', Math.abs(jaxe.fmod_chan_get_3d_spread(ch) - 45) < 0.1);
    jaxe.fmod_chan_set_3d_level(ch, 0.8);
    check('s4_get_3d_level', Math.abs(jaxe.fmod_chan_get_3d_level(ch) - 0.8) < 0.001);
    jaxe.fmod_chan_set_3d_doppler_level(ch, 0.7);
    check('s4_get_doppler', Math.abs(jaxe.fmod_chan_get_3d_doppler_level(ch) - 0.7) < 0.001);
    jaxe.fmod_chan_set_3d_min_max(ch, 2, 50);
    const minMax = [];
    jaxe.fmod_chan_get_3d_min_max(ch, minMax);
    check('s4_get_min_max', Math.abs(minMax[0] - 2) < 0.001 && Math.abs(minMax[1] - 50) < 0.001,
        `min=${minMax[0]} max=${minMax[1]}`);
    jaxe.fmod_chan_set_3d_attributes(ch, 1, 2, 3, 0, 0, 0);
    const attrs = [];
    jaxe.fmod_chan_get_3d_attributes(ch, attrs);
    check('s4_get_3d_attributes', Math.abs(attrs[0] - 1) < 0.001 && Math.abs(attrs[1] - 2) < 0.001
        && Math.abs(attrs[2] - 3) < 0.001, `pos=${attrs[0]},${attrs[1]},${attrs[2]}`);
    const clocks = [];
    jaxe.fmod_chan_get_dsp_clock(ch, clocks);
    jaxe.fmod_chan_set_delay(ch, 0, clocks[1] + 96000, false);
    const delay = [];
    jaxe.fmod_chan_get_delay(ch, delay);
    check('s4_get_delay', Math.abs(delay[1] - (clocks[1] + 96000)) < 1,
        `end=${delay[1]} expected=${clocks[1] + 96000}`);
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_core_pcm_release(ps);

    const dsp = jaxe.fmod_dsp_create_by_type(18);
    jaxe.fmod_dsp_set_wet_dry_mix(dsp, 1, 0.8, 0.2);
    const mix = [];
    jaxe.fmod_dsp_get_wet_dry_mix(dsp, mix);
    check('s4_get_wet_dry', Math.abs(mix[1] - 0.8) < 0.001, `post=${mix[1]}`);
    jaxe.fmod_dsp_set_active(dsp, true);
    check('s4_get_active', jaxe.fmod_dsp_get_active(dsp) === true);
    jaxe.fmod_dsp_set_metering_enabled(dsp, true, false);
    const metering = [];
    jaxe.fmod_dsp_get_metering_enabled(dsp, metering);
    check('s4_get_metering_enabled', metering[0] === 1 && metering[1] === 0,
        `in=${metering[0]} out=${metering[1]}`);
    jaxe.fmod_dsp_release(dsp);
    pump(5);
}
