// Runs the ChannelControl parity bindings of jaxe.js against the real
// FMOD 2.03.12 wasm under Node: the group readers (delay, isPlaying), the
// group callback registration, the connection addGroup hands back, the
// connection-narrowed disconnectFrom, and the mix matrix hop on channels,
// groups, and connections. The glue binds the matrix readers as a single
// float, so those report 68 (ERR_UNSUPPORTED). The rest work.
// Usage: node channelcontrol-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`CHANNELCONTROL_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
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
    if (!jaxe.FmodIsInitialized) { console.log('CHANNELCONTROL_TEST: INIT TIMEOUT'); process.exit(1); }
}

async function main() {
    await waitForInit();
    const OK = jaxe.FMOD.OK;
    const UNSUPPORTED = jaxe.ERR_UNSUPPORTED;
    const INVALID_HANDLE = jaxe.ERR_INVALID_HANDLE;
    const INVALID_PARAM = jaxe.ERR_INVALID_PARAM;
    jaxe.fmod_cg_get_master();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const fbuf = new Array(1024).fill(0);
    const ibuf = new Array(1024).fill(0);

    // addGroup returns the connection, and the flag reaches FMOD
    const parent = jaxe.fmod_cg_create('cc-parent');
    const child = jaxe.fmod_cg_create('cc-child');
    const other = jaxe.fmod_cg_create('cc-other');
    const conn = jaxe.fmod_cg_add_group(parent, child, true);
    check('cg_add_group_connection', conn !== 0 && jaxe.lastResult === OK, `handle=${conn} result=${jaxe.lastResult}`);
    check('cg_add_group_connection_resolves', Math.abs(jaxe.fmod_dspconn_get_mix(conn) - 1) < 0.001 && jaxe.lastResult === OK, `mix=${jaxe.fmod_dspconn_get_mix(conn)}`);
    check('cg_add_group_no_propagate', jaxe.fmod_cg_add_group(parent, other, false) !== 0 && jaxe.lastResult === OK,
        `result=${jaxe.lastResult}`);
    check('cg_add_group_stale', jaxe.fmod_cg_add_group(parent, 0x7fff0001, true) === 0 && jaxe.lastResult === INVALID_HANDLE,
        `result=${jaxe.lastResult}`);

    // The group readers
    check('cg_is_playing_empty', jaxe.fmod_cg_is_playing(parent) === false && jaxe.lastResult === OK, `result=${jaxe.lastResult}`);
    const stream = jaxe.fmod_core_pcm_create(48000, 2, 4096);
    const channel = jaxe.fmod_core_pcm_play(stream, false);
    jaxe.fmod_chan_set_channel_group(channel, child);
    check('cg_is_playing_nested', jaxe.fmod_cg_is_playing(parent) === true && jaxe.fmod_cg_is_playing(child) === true, '');
    check('cg_is_playing_stale', jaxe.fmod_cg_is_playing(0x7fff0001) === false && jaxe.lastResult === INVALID_HANDLE, '');
    // FMOD 2.03.12 answers OK and leaves a group's lowpass gain and
    // occlusion at zero on every target, so only the result and range count
    jaxe.fmod_cg_set_low_pass_gain(child, 0.5);
    const gain = jaxe.fmod_cg_get_low_pass_gain(child);
    check('cg_get_low_pass_gain', jaxe.lastResult === OK && gain >= 0 && gain <= 1, `gain=${gain}`);
    check('cg_get_low_pass_gain_stale', jaxe.fmod_cg_get_low_pass_gain(0x7fff0001) === 0.0 && jaxe.lastResult === INVALID_HANDLE, '');
    jaxe.fmod_cg_set_3d_occlusion(child, 0.4, 0.2);
    check('cg_get_3d_occlusion', jaxe.fmod_cg_get_3d_occlusion(child, fbuf) === OK && fbuf[0] >= 0 && fbuf[0] <= 1,
        `direct=${fbuf[0]} reverb=${fbuf[1]}`);
    check('cg_get_3d_occlusion_stale', jaxe.fmod_cg_get_3d_occlusion(0x7fff0001, fbuf) === INVALID_HANDLE, '');
    jaxe.fmod_cg_get_dsp_clock(child, fbuf);
    const base = fbuf[1];
    check('cg_set_delay_stop', jaxe.fmod_cg_set_delay(child, 0, base + 96000, true) === OK, '');
    check('cg_get_delay', jaxe.fmod_cg_get_delay(child, fbuf) === OK && Math.abs(fbuf[1] - (base + 96000)) < 1 && fbuf[2] === 1,
        `end=${fbuf[1]} stop=${fbuf[2]}`);
    jaxe.fmod_cg_set_delay(child, 0, base + 96000, false);
    check('cg_get_delay_pause_only', jaxe.fmod_cg_get_delay(child, fbuf) === OK && fbuf[2] === 0, `stop=${fbuf[2]}`);
    jaxe.fmod_cg_set_delay(child, 0, 0, true);
    check('cg_get_delay_stale', jaxe.fmod_cg_get_delay(0x7fff0001, fbuf) === INVALID_HANDLE, '');

    // Group callbacks register through the same map as channel callbacks
    check('cg_set_callback', jaxe.fmod_cg_set_callback(child, true) === OK, `result=${jaxe.lastResult}`);
    check('cg_set_callback_mapped', jaxe.chanCallbackHandles.get(jaxe.rawPtr(jaxe.resolveCg(child))) === child, '');
    check('cg_clear_callback', jaxe.fmod_cg_set_callback(child, false) === OK
        && !jaxe.chanCallbackHandles.has(jaxe.rawPtr(jaxe.resolveCg(child))), '');
    check('cg_set_callback_stale', jaxe.fmod_cg_set_callback(0x7fff0001, true) === INVALID_HANDLE, '');
    jaxe.fmod_cg_set_callback(child, true);
    // A synthetic group occlusion callback lands in the queue with the group handle
    jaxe.channelCallback(jaxe.resolveCg(child), 1, 3, 0.75, 0.25);
    check('cg_occlusion_event_queued', jaxe.fmod_cb_next() && jaxe.fmod_cb_handle() === child
        && jaxe.fmod_cb_type() === jaxe.CB_CHAN_OCCLUSION && Math.abs(jaxe.fmod_cb_float() - 0.75) < 0.001,
        `handle=${jaxe.fmod_cb_handle()} type=${jaxe.fmod_cb_type()} f1=${jaxe.fmod_cb_float()}`);
    jaxe.floatBitsInt[0] = jaxe.fmod_cb_int(0);
    check('cg_occlusion_event_reverb_bits', Math.abs(jaxe.floatBits[0] - 0.25) < 0.001, `reverb=${jaxe.floatBits[0]}`);
    jaxe.channelCallback(jaxe.resolveChan(channel), 0, 1, 1, 0);
    check('chan_virtual_voice_ignored_without_handler', !jaxe.fmod_cb_next(), '');
    jaxe.fmod_chan_set_callback(channel, true);
    jaxe.channelCallback(jaxe.resolveChan(channel), 0, 1, 1, 0);
    check('chan_virtual_voice_event_queued', jaxe.fmod_cb_next() && jaxe.fmod_cb_handle() === channel
        && jaxe.fmod_cb_type() === jaxe.CB_CHAN_VIRTUALVOICE && jaxe.fmod_cb_int(0) === 1, `type=${jaxe.fmod_cb_type()}`);
    jaxe.fmod_chan_set_callback(channel, false);

    // The mix matrix hop on channels, groups, and connections
    const wide = [1, 0, 0, 0, 0, 1, 0, 0];
    for (let i = 0; i < 8; i++) fbuf[i] = wide[i];
    check('chan_set_mix_matrix_hop', jaxe.fmod_chan_set_mix_matrix(channel, fbuf, 2, 2, 4) === OK, `result=${jaxe.lastResult}`);
    check('chan_set_mix_matrix_hop_too_narrow', jaxe.fmod_chan_set_mix_matrix(channel, fbuf, 2, 2, 1) === INVALID_PARAM, '');
    check('chan_set_mix_matrix_hop_too_wide', jaxe.fmod_chan_set_mix_matrix(channel, fbuf, 2, 2, 33) === INVALID_PARAM, '');
    check('chan_set_mix_matrix_packed', jaxe.fmod_chan_set_mix_matrix(channel, fbuf, 2, 2, 0) === OK, '');
    check('chan_get_mix_matrix_unsupported', jaxe.fmod_chan_get_mix_matrix(channel, fbuf, ibuf, 4) === 0 && jaxe.lastResult === UNSUPPORTED,
        `result=${jaxe.lastResult}`);
    for (let i = 0; i < 8; i++) fbuf[i] = wide[i];
    check('cg_set_mix_matrix_hop', jaxe.fmod_cg_set_mix_matrix(child, fbuf, 2, 2, 4) === OK, `result=${jaxe.lastResult}`);
    check('cg_get_mix_matrix_unsupported', jaxe.fmod_cg_get_mix_matrix(child, fbuf, ibuf, 0) === 0 && jaxe.lastResult === UNSUPPORTED, '');
    const osc = jaxe.fmod_dsp_create_by_type(2);
    const fft = jaxe.fmod_dsp_create_by_type(26);
    const link = jaxe.fmod_dsp_add_input(fft, osc, 0);
    check('conn_for_matrix', link !== 0, `handle=${link} result=${jaxe.lastResult}`);
    for (let i = 0; i < 8; i++) fbuf[i] = wide[i] * 0.5;
    check('conn_set_mix_matrix_hop', jaxe.fmod_conn_set_mix_matrix(link, fbuf, 2, 2, 4) === OK, `result=${jaxe.lastResult}`);
    check('conn_get_mix_matrix_unsupported', jaxe.fmod_conn_get_mix_matrix(link, fbuf, ibuf, 0) === 0 && jaxe.lastResult === UNSUPPORTED, '');

    // disconnectFrom narrowed to one connection, then the stale handle
    check('dsp_disconnect_from_connection', jaxe.fmod_dsp_disconnect_from(fft, osc, link) === OK
        && jaxe.fmod_dsp_get_num_inputs(fft) === 0, `inputs=${jaxe.fmod_dsp_get_num_inputs(fft)}`);
    const again = jaxe.fmod_dsp_add_input(fft, osc, 0);
    check('dsp_disconnect_from_stale_connection', jaxe.fmod_dsp_disconnect_from(fft, osc, link) === INVALID_HANDLE
        && jaxe.fmod_dsp_get_num_inputs(fft) === 1, `again=${again} old=${link}`);
    check('dsp_disconnect_from_any', jaxe.fmod_dsp_disconnect_from(fft, osc, 0) === OK
        && jaxe.fmod_dsp_get_num_inputs(fft) === 0, '');
    jaxe.fmod_dsp_release(osc);
    jaxe.fmod_dsp_release(fft);

    // Releasing a group with a callback drops its map entry
    const childPtr = jaxe.rawPtr(jaxe.resolveCg(child));
    jaxe.fmod_chan_stop(channel);
    jaxe.fmod_core_pcm_release(stream);
    check('cg_release_with_callback', jaxe.fmod_cg_release(child) === OK && !jaxe.chanCallbackHandles.has(childPtr), '');
    jaxe.fmod_cg_release(other);
    jaxe.fmod_cg_release(parent);
    check('no_handle_leaks', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`CHANNELCONTROL_TEST: ${failures === 0 ? 'COMPLETE' : 'FAILED'} failures=${failures}`);
    process.exit(failures === 0 ? 0 : 1);
}

main().catch(e => {
    console.log('CHANNELCONTROL_TEST: THREW', e && e.stack ? e.stack : e);
    process.exit(1);
});
