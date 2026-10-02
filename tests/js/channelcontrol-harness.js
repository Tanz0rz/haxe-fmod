// Runs the ChannelControl parity bindings of jaxe.js against the real
// FMOD 2.03.12 wasm under Node.
// The coverage holds the group readers (delay, isPlaying), the group
// callback registration, and the connection addGroup hands back.
// It takes in the connection-narrowed disconnectFrom and the mix matrix hop
// on channels, groups, and connections.
// The glue binds the matrix readers as a single float, so those report 68
// (ERR_UNSUPPORTED). The rest work.
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
    // Whether a connection handle still works and runs at mix, and whether
    // it fails its check
    const connLive = (c, mix) => {
        const m = jaxe.fmod_dspconn_get_mix(c);
        return Math.abs(m - mix) < 0.001 && jaxe.lastResult === OK;
    };
    const connDead = (c) => jaxe.fmod_dspconn_get_mix(c) === 0 && jaxe.lastResult === INVALID_HANDLE;
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
    // A group added below itself makes FMOD recurse until the stack runs
    // out. The binding refuses the group itself, its parent, and the master.
    const selfAdd = jaxe.fmod_cg_add_group(child, child, true);
    const selfResult = jaxe.lastResult;
    const parentAdd = jaxe.fmod_cg_add_group(child, parent, true);
    const parentResult = jaxe.lastResult;
    const masterAdd = jaxe.fmod_cg_add_group(child, jaxe.fmod_cg_get_master(), true);
    const masterResult = jaxe.lastResult;
    check('cg_add_group_ancestor_refused', selfAdd === 0 && selfResult === INVALID_PARAM && parentAdd === 0
        && parentResult === INVALID_PARAM && masterAdd === 0 && masterResult === INVALID_PARAM
        && jaxe.fmod_cg_get_num_groups(parent) === 2,
        `self=${selfResult} parent=${parentResult} master=${masterResult} groups=${jaxe.fmod_cg_get_num_groups(parent)}`);
    // A move down a branch and back up to the grandparent stays open
    const down = jaxe.fmod_cg_add_group(child, other, true);
    const downCount = jaxe.fmod_cg_get_num_groups(child);
    const up = jaxe.fmod_cg_add_group(parent, other, true);
    check('cg_add_group_reparent', down !== 0 && downCount === 1 && up !== 0
        && jaxe.fmod_cg_get_num_groups(child) === 0 && jaxe.fmod_cg_get_num_groups(parent) === 2,
        `down=${down} up=${up} groups=${jaxe.fmod_cg_get_num_groups(parent)}`);
    // A walk returns the live handle of a connection the game made. A
    // connection the game did not make gets a short-lived handle, and a
    // stop ends it.
    const walkedConn = jaxe.fmod_dsp_get_output_connection(jaxe.fmod_cg_get_dsp(parent, -1), 0);
    const walkedLive = walkedConn !== 0 && jaxe.fmod_dspconn_get_mix(walkedConn) > 0;
    const reached = jaxe.fmod_dsp_get_output_connection(jaxe.fmod_cg_get_dsp(child, -1), 0);
    jaxe.fmod_cg_stop(parent);
    jaxe.fmod_dspconn_get_mix(walkedConn);
    const walkedResult = jaxe.lastResult;
    const connMix = jaxe.fmod_dspconn_get_mix(conn);
    check('dsp_walk_connection_short_lived', walkedLive && walkedResult === INVALID_HANDLE && reached === conn
        && connMix > 0 && jaxe.lastResult === OK,
        `live=${walkedLive} walked=${walkedResult} reached=${reached} conn=${conn} connMix=${connMix}`);
    // A move destroys the connection to the old parent, and its handle
    // fails the check. Every other handle keeps working. A refused move
    // keeps the connection, and so does a move into the parent the child
    // already has. That move gets no connection.
    const moved = jaxe.fmod_cg_add_group(child, other, true);
    const movedLive = moved !== 0 && jaxe.fmod_dspconn_get_mix(moved) > 0;
    const refusedMove = jaxe.fmod_cg_add_group(other, parent, true);
    const refusedResult = jaxe.lastResult;
    const keptMix = jaxe.fmod_dspconn_get_mix(moved);
    const sameParent = jaxe.fmod_cg_add_group(child, other, true);
    const sameParentResult = jaxe.lastResult;
    const sameMix = jaxe.fmod_dspconn_get_mix(moved);
    check('cg_add_group_same_parent_keeps_connection', sameParent === 0 && sameParentResult === OK && sameMix > 0
        && jaxe.lastResult === OK, `same=${sameParent} result=${sameParentResult} mix=${sameMix}`);
    const moveBack = jaxe.fmod_cg_add_group(parent, other, true);
    const movedMix = jaxe.fmod_dspconn_get_mix(moved);
    const movedResult = jaxe.lastResult;
    const unrelatedMix = jaxe.fmod_dspconn_get_mix(conn);
    check('cg_add_group_move_ends_connection', movedLive && refusedMove === 0 && refusedResult === INVALID_PARAM
        && keptMix > 0 && moveBack !== 0 && movedMix === 0 && movedResult === INVALID_HANDLE
        && unrelatedMix > 0 && jaxe.lastResult === OK,
        `live=${movedLive} refused=${refusedResult} kept=${keptMix} back=${moveBack} mix=${movedMix} unrelated=${unrelatedMix}`);

    // The group readers
    check('cg_is_playing_empty', jaxe.fmod_cg_is_playing(parent) === false && jaxe.lastResult === OK, `result=${jaxe.lastResult}`);
    const stream = jaxe.fmod_core_pcm_create(48000, 2, 4096);
    const channel = jaxe.fmod_core_pcm_play(stream, false);
    // A channel move destroys the connection to the old group, and its
    // handle fails the check. Every other handle keeps working. A refused
    // move keeps the connection, and so does a move into the group the
    // channel is in.
    const sendOsc = jaxe.fmod_dsp_create_by_type(2);
    const sendFft = jaxe.fmod_dsp_create_by_type(26);
    const send = jaxe.fmod_dsp_add_input(sendFft, sendOsc, 0);
    const sendLive = send !== 0 && jaxe.fmod_dspconn_get_mix(send) > 0;
    const toMaster = jaxe.fmod_dsp_get_output_connection(jaxe.fmod_chan_get_dsp(channel, -1), 0);
    const toMasterLive = toMaster !== 0 && jaxe.fmod_dspconn_get_mix(toMaster) > 0;
    const refusedRoute = jaxe.fmod_chan_set_channel_group(channel, 0x7fff0001);
    const routeKept = jaxe.fmod_dspconn_get_mix(toMaster);
    const sameRoute = jaxe.fmod_chan_set_channel_group(channel, jaxe.fmod_cg_get_master());
    const sameRouteMix = jaxe.fmod_dspconn_get_mix(toMaster);
    check('chan_set_channel_group_same_group_keeps_connection', toMasterLive && refusedRoute === INVALID_HANDLE
        && routeKept > 0 && sameRoute === OK && sameRouteMix > 0 && jaxe.lastResult === OK,
        `live=${toMasterLive} refused=${refusedRoute} kept=${routeKept} same=${sameRoute} mix=${sameRouteMix}`);
    const route = jaxe.fmod_chan_set_channel_group(channel, child);
    const routedMix = jaxe.fmod_dspconn_get_mix(toMaster);
    const routedResult = jaxe.lastResult;
    const sendMix = jaxe.fmod_dspconn_get_mix(send);
    check('chan_set_channel_group_ends_connection', sendLive && route === OK && routedMix === 0
        && routedResult === INVALID_HANDLE && sendMix > 0 && jaxe.lastResult === OK,
        `route=${route} moved=${routedResult} send=${sendMix}`);
    jaxe.fmod_dsp_release(sendFft);
    jaxe.fmod_dsp_release(sendOsc);
    check('cg_is_playing_nested', jaxe.fmod_cg_is_playing(parent) === true && jaxe.fmod_cg_is_playing(child) === true, '');
    // FMOD indexes before the chain below the tail marker. Both getters
    // refuse that, and the markers themselves still answer.
    const groupBelow = jaxe.fmod_cg_get_dsp(child, -4);
    const groupBelowResult = jaxe.lastResult;
    const channelBelow = jaxe.fmod_chan_get_dsp(channel, -4);
    const channelBelowResult = jaxe.lastResult;
    check('get_dsp_below_tail_refused', groupBelow === 0 && groupBelowResult === INVALID_PARAM
        && channelBelow === 0 && channelBelowResult === INVALID_PARAM
        && jaxe.fmod_cg_get_dsp(child, -100000) === 0 && jaxe.lastResult === INVALID_PARAM,
        `group=${groupBelowResult} channel=${channelBelowResult}`);
    check('get_dsp_markers_ok', jaxe.fmod_cg_get_dsp(child, -3) !== 0 && jaxe.fmod_chan_get_dsp(channel, -1) !== 0,
        `result=${jaxe.lastResult}`);
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

    // disconnectFrom narrowed to one connection, then the stale handle. A
    // connection the disconnect leaves keeps its handle.
    const bystanderIn = jaxe.fmod_dsp_create_by_type(2);
    const bystanderOut = jaxe.fmod_dsp_create_by_type(1);
    const bystander = jaxe.fmod_dsp_add_input(bystanderOut, bystanderIn, 0);
    jaxe.fmod_dspconn_set_mix(bystander, 0.4);
    check('dsp_disconnect_from_connection', jaxe.fmod_dsp_disconnect_from(fft, osc, link) === OK
        && jaxe.fmod_dsp_get_num_inputs(fft) === 0 && connDead(link) && connLive(bystander, 0.4),
        `inputs=${jaxe.fmod_dsp_get_num_inputs(fft)}`);
    // A connection FMOD makes at the address of one it destroyed gets a
    // new handle. The old handle is never checked before the new
    // connections come, and no new one comes back with it.
    const oldLink = jaxe.fmod_dsp_add_input(fft, osc, 0);
    jaxe.fmod_dsp_disconnect_from(fft, osc, 0);
    jaxe.fmod_sys_update();
    // The mark goes out of reach so the check at the mark frees nothing
    // and the make path alone keeps the handles apart
    const markBefore = jaxe.connMark;
    jaxe.connMark = 1 << 30;
    let reusedAs = 0;
    const churn = [];
    for (let i = 0; i < 1500 && !reusedAs; i++) {
        const x = jaxe.fmod_dsp_create_by_type(2), y = jaxe.fmod_dsp_create_by_type(1);
        const c = jaxe.fmod_dsp_add_input(y, x, 0);
        if (c === oldLink) reusedAs = c;
        churn.push(x, y);
        if (i % 64 === 63) jaxe.fmod_sys_update();
    }
    for (const d of churn) jaxe.fmod_dsp_release(d);
    jaxe.connMark = markBefore;
    const again = jaxe.fmod_dsp_add_input(fft, osc, 0);
    check('dsp_add_input_new_handle_at_reused_address', oldLink !== 0 && reusedAs === 0 && again !== oldLink
        && connDead(oldLink) && connLive(again, 1.0), `old=${oldLink} reused=${reusedAs} again=${again}`);
    check('dsp_disconnect_from_stale_connection', jaxe.fmod_dsp_disconnect_from(fft, osc, link) === INVALID_HANDLE
        && jaxe.fmod_dsp_get_num_inputs(fft) === 1, `again=${again} old=${link}`);
    check('dsp_disconnect_from_any', jaxe.fmod_dsp_disconnect_from(fft, osc, 0) === OK
        && jaxe.fmod_dsp_get_num_inputs(fft) === 0, '');
    jaxe.fmod_dsp_release(osc);
    jaxe.fmod_dsp_release(fft);

    // Releasing a group with a callback takes the callback off first and
    // drops its map entry. A refused release puts the callback back.
    const childWrapper = jaxe.resolveCg(child);
    const childPtr = jaxe.rawPtr(childWrapper);
    jaxe.fmod_chan_stop(channel);
    jaxe.fmod_core_pcm_release(stream);
    const cbCalls = [];
    const realSetCallback = childWrapper.setCallback;
    childWrapper.setCallback = function (cb) { cbCalls.push(cb === null ? 'off' : 'on'); return realSetCallback.call(childWrapper, cb); };
    const realRelease = childWrapper.release;
    childWrapper.release = () => { cbCalls.push('release'); return 40; };
    check('cg_refused_release_restores_callback', jaxe.fmod_cg_release(child) === 40
        && cbCalls.join(',') === 'off,release,on' && jaxe.chanCallbackHandles.get(childPtr) === child, `calls=${cbCalls.join(',')}`);
    childWrapper.release = function () { cbCalls.push('release'); return realRelease.call(childWrapper); };
    cbCalls.length = 0;
    check('cg_release_with_callback', jaxe.fmod_cg_release(child) === OK && !jaxe.chanCallbackHandles.has(childPtr)
        && cbCalls.join(',') === 'off,release', `calls=${cbCalls.join(',')}`);
    // The master group cannot be released. The shim marks it owned when it
    // mints the handle, and refuses with INVALID_PARAM before the FMOD call.
    // The slot and the channel callback mapping stay.
    const master = jaxe.fmod_cg_get_master();
    const masterPtr = jaxe.rawPtr(jaxe.resolveCg(master));
    check('cg_master_callback_installed', jaxe.fmod_cg_set_callback(master, true) === OK
        && jaxe.chanCallbackHandles.get(masterPtr) === master, `result=${jaxe.lastResult}`);
    const liveBeforeMaster = jaxe.fmod_debug_live_handle_count();
    check('cg_master_release_refused', jaxe.fmod_cg_release(master) === INVALID_PARAM,
        `result=${jaxe.lastResult}`);
    check('cg_master_release_keeps_handle', jaxe.resolveCg(master) != null
        && jaxe.fmod_debug_live_handle_count() === liveBeforeMaster,
        `live=${jaxe.fmod_debug_live_handle_count()} before=${liveBeforeMaster}`);
    check('cg_master_release_keeps_callback', jaxe.chanCallbackHandles.get(masterPtr) === master, '');
    check('cg_master_still_answers', jaxe.fmod_cg_get_volume(master) === 1 && jaxe.lastResult === OK,
        `result=${jaxe.lastResult}`);
    jaxe.fmod_cg_set_callback(master, false);
    // A group the game created stays releasable when reached through a
    // walk, since the walk finds its slot instead of minting an owned one
    const walked = jaxe.fmod_cg_get_group(parent, 0);
    check('cg_walk_finds_created_group', walked === other && !jaxe.isOwned(walked), `walked=${walked} other=${other}`);
    check('cg_walk_mints_owned_master', jaxe.isOwned(jaxe.fmod_cg_get_parent_group(parent)), '');
    // The live-handle query answers for any type with no FMOD call
    const lastBefore = jaxe.lastResult;
    check('debug_handle_is_live', jaxe.fmod_debug_handle_is_live(master) === true
        && jaxe.fmod_debug_handle_is_live(0x7fff0001) === false && jaxe.fmod_debug_handle_is_live(0) === false
        && jaxe.lastResult === lastBefore, `last=${jaxe.lastResult}`);
    // A slot at its last generation retires, so a stale handle from an
    // earlier generation never resolves again
    {
        const liveBefore = jaxe.fmod_debug_live_handle_count();
        const marker = {};
        const seed = jaxe.handleAlloc(marker, jaxe.TYPE_EVI);
        const idx = seed & 0xFFFF;
        jaxe.slots[idx].gen = 0x7FFF;
        const stale = (0x7FFF << 16) | idx;
        jaxe.handleFree(stale);
        const next = jaxe.handleAlloc(marker, jaxe.TYPE_EVI);
        check('handle_slot_retires_at_last_generation',
            jaxe.freeList.indexOf(idx) === -1 && (next & 0xFFFF) !== idx
            && jaxe.handleResolve(stale, jaxe.TYPE_EVI) === null
            && jaxe.handleIsLive(stale) === false && jaxe.handleIsLive(next) === true,
            `stale=${stale} next=${next} free=${jaxe.freeList.join('|')}`);
        jaxe.handleFree(next);
        check('handle_retirement_leaks_nothing',
            jaxe.fmod_debug_live_handle_count() === liveBefore,
            `live=${jaxe.fmod_debug_live_handle_count()} before=${liveBefore}`);
    }

    // A send from a channel's head ends with the channel. A send between
    // two DSPs the game created outlives the updates. The wait is on the
    // clock.
    {
        const pcm = new ArrayBuffer(4800 * 2);
        const shortSound = jaxe.fmod_core_create_sound_pcm(pcm, pcm.byteLength, 48000, 1);
        const shot = jaxe.fmod_core_play_sound(shortSound, 0, false);
        const sink = jaxe.fmod_dsp_create_by_type(26);
        const source = jaxe.fmod_dsp_create_by_type(2);
        const headSend = jaxe.fmod_dsp_add_input(sink, jaxe.fmod_chan_get_dsp(shot, -1), 0);
        const headLive = headSend !== 0 && jaxe.fmod_dspconn_get_mix(headSend) > 0;
        const pairSend = jaxe.fmod_dsp_add_input(sink, source, 0);
        const started = Date.now();
        while (jaxe.fmod_chan_is_playing(shot) && Date.now() - started < 5000) {
            jaxe.fmod_sys_update();
            await new Promise(r => setTimeout(r, 10));
        }
        jaxe.fmod_sys_update();
        const ended = !jaxe.fmod_chan_is_playing(shot);
        jaxe.fmod_dspconn_get_mix(headSend);
        const headResult = jaxe.lastResult;
        const pairMix = jaxe.fmod_dspconn_get_mix(pairSend);
        check('dsp_add_input_channel_send_short_lived', headLive && ended && headResult === INVALID_HANDLE,
            `live=${headLive} ended=${ended} result=${headResult}`);
        check('dsp_add_input_game_send_long_lived', pairSend !== 0 && pairMix > 0 && jaxe.lastResult === OK,
            `mix=${pairMix} result=${jaxe.lastResult}`);
        // The ended channel keeps its slot until a stop or the next play
        jaxe.fmod_chan_stop(shot);
        jaxe.fmod_dsp_release(sink);
        jaxe.fmod_dsp_release(source);
        jaxe.fmod_core_release_sound(shortSound);
    }

    // A head with a second connection to the old parent's tail. The move
    // destroys the parent connection, and the game's send keeps routing at
    // its mix with its handle.
    {
        const inputsAtMix = (dsp, mix) => {
            let count = 0;
            const n = jaxe.fmod_dsp_get_num_inputs(dsp);
            for (let i = 0; i < n; i++) {
                if (Math.abs(jaxe.fmod_dspconn_get_mix(jaxe.fmod_dsp_get_input_connection(dsp, i)) - mix) < 0.001) count++;
            }
            return count;
        };
        const dupParent = jaxe.fmod_cg_create('cc-dup-parent');
        const dupChild = jaxe.fmod_cg_create('cc-dup-child');
        const dupTail = jaxe.fmod_cg_get_dsp(dupParent, -3);
        const dupSend = jaxe.fmod_dsp_add_input(dupTail, jaxe.fmod_cg_get_dsp(dupChild, -1), 2);
        jaxe.fmod_dspconn_set_mix(dupSend, 0.25);
        const dupConn = jaxe.fmod_cg_add_group(dupParent, dupChild, true);
        const dupLive = dupSend !== 0 && dupConn !== 0 && jaxe.fmod_dspconn_get_mix(dupConn) > 0 && inputsAtMix(dupTail, 0.25) === 1;
        const dupMove = jaxe.fmod_cg_add_group(other, dupChild, true);
        const dupMoveResult = jaxe.lastResult;
        const dupMix = jaxe.fmod_dspconn_get_mix(dupConn);
        const dupResult = jaxe.lastResult;
        const dupSends = inputsAtMix(dupTail, 0.25);
        check('cg_add_group_second_tail_connection', dupLive && dupMove !== 0 && dupMoveResult === OK && dupMix === 0
            && dupResult === INVALID_HANDLE && dupSends === 1 && connLive(dupSend, 0.25),
            `live=${dupLive} move=${dupMoveResult} result=${dupResult} sends=${dupSends}`);
        // The same holds for a channel. The game sends to a group's tail
        // first, then moves the channel into the group and out again.
        const dupStream = jaxe.fmod_core_pcm_create(48000, 2, 4096);
        const dupChannel = jaxe.fmod_core_pcm_play(dupStream, 0, false);
        const otherTail = jaxe.fmod_cg_get_dsp(other, -3);
        const chanSend = jaxe.fmod_dsp_add_input(otherTail, jaxe.fmod_chan_get_dsp(dupChannel, -1), 2);
        jaxe.fmod_dspconn_set_mix(chanSend, 0.25);
        const before = [];
        for (let i = 0; i < jaxe.fmod_dsp_get_num_inputs(otherTail); i++) before.push(jaxe.fmod_dsp_get_input_connection(otherTail, i));
        const chanJoin = jaxe.fmod_chan_set_channel_group(dupChannel, other);
        let chanParent = 0;
        for (let i = 0; i < jaxe.fmod_dsp_get_num_inputs(otherTail); i++) {
            const c = jaxe.fmod_dsp_get_input_connection(otherTail, i);
            if (before.indexOf(c) < 0) chanParent = c;
        }
        const chanLive = chanSend !== 0 && chanJoin === OK && chanParent !== 0 && jaxe.fmod_dspconn_get_mix(chanParent) > 0;
        const chanLeave = jaxe.fmod_chan_set_channel_group(dupChannel, parent);
        const chanMix = jaxe.fmod_dspconn_get_mix(chanParent);
        const chanResult = jaxe.lastResult;
        const chanSends = inputsAtMix(otherTail, 0.25);
        check('chan_set_channel_group_second_tail_connection', chanLive && chanLeave === OK && chanMix === 0
            && chanResult === INVALID_HANDLE && chanSends === 1 && connLive(chanSend, 0.25),
            `live=${chanLive} leave=${chanLeave} result=${chanResult} sends=${chanSends}`);
        jaxe.fmod_chan_stop(dupChannel);
        jaxe.fmod_core_pcm_release(dupStream);
        jaxe.fmod_cg_release(dupChild);
        jaxe.fmod_cg_release(dupParent);
    }

    // A DSP at a group's tail carries the connections of the group's
    // children. FMOD destroys the connection of a lone child when that DSP
    // moves, and its handle fails the check. A fresh DSP at the tail takes
    // the connection over, and the handle follows the tail. The bystander
    // keeps working throughout.
    {
        const tailParent = jaxe.fmod_cg_create('cc-tail-parent');
        const tailChild = jaxe.fmod_cg_create('cc-tail-child');
        const tailConn = jaxe.fmod_cg_add_group(tailParent, tailChild, true);
        jaxe.fmod_dspconn_set_mix(tailConn, 0.6);
        const tailDsp = jaxe.fmod_dsp_create_by_type(3);
        const tailAdd = jaxe.fmod_cg_add_dsp(tailParent, jaxe.fmod_cg_get_num_dsps(tailParent), tailDsp);
        const tailKept = jaxe.fmod_dspconn_get_mix(tailConn);
        const tailKeptResult = jaxe.lastResult;
        check('cg_add_dsp_fresh_keeps_connection', tailAdd === OK && tailKeptResult === OK && Math.abs(tailKept - 0.6) < 0.001,
            `add=${tailAdd} result=${tailKeptResult} mix=${tailKept}`);
        const tailMove = jaxe.fmod_cg_set_dsp_index(tailParent, tailDsp, 0);
        jaxe.fmod_dspconn_get_mix(tailConn);
        const tailMoveResult = jaxe.lastResult;
        check('cg_set_dsp_index_tail_ends_connection', tailMove === OK && tailMoveResult === INVALID_HANDLE
            && connLive(bystander, 0.4),
            `move=${tailMove} result=${tailMoveResult}`);
        const readdParent = jaxe.fmod_cg_create('cc-readd-parent');
        const readdChild = jaxe.fmod_cg_create('cc-readd-child');
        const readdConn = jaxe.fmod_cg_add_group(readdParent, readdChild, true);
        const readdDsp = jaxe.fmod_dsp_create_by_type(5);
        const readdFirst = jaxe.fmod_cg_add_dsp(readdParent, jaxe.fmod_cg_get_num_dsps(readdParent), readdDsp);
        jaxe.fmod_dspconn_get_mix(readdConn);
        const readdLive = readdFirst === OK && jaxe.lastResult === OK;
        const readdAgain = jaxe.fmod_cg_add_dsp(readdParent, 0, readdDsp);
        jaxe.fmod_dspconn_get_mix(readdConn);
        const readdResult = jaxe.lastResult;
        check('cg_add_dsp_tail_again_ends_connection', readdLive && readdAgain === OK && readdResult === INVALID_HANDLE
            && connLive(bystander, 0.4),
            `live=${readdLive} again=${readdAgain} result=${readdResult}`);
        jaxe.fmod_cg_remove_dsp(readdParent, readdDsp);
        jaxe.fmod_dsp_release(readdDsp);
        jaxe.fmod_cg_release(readdChild);
        jaxe.fmod_cg_release(readdParent);
        jaxe.fmod_cg_remove_dsp(tailParent, tailDsp);
        jaxe.fmod_dsp_release(tailDsp);
        jaxe.fmod_cg_release(tailChild);
        jaxe.fmod_cg_release(tailParent);
    }

    // Each graph call ends only the handles of the connections it destroys
    // or moves. The bystander joins two DSPs none of these calls touches.
    {
        const fxStream = jaxe.fmod_core_pcm_create(48000, 2, 4096);
        const fxChannel = jaxe.fmod_core_pcm_play(fxStream, 0, false);
        const fx = jaxe.fmod_dsp_create_by_type(3);
        const fxIn = jaxe.fmod_dsp_create_by_type(1);
        const fxOut = jaxe.fmod_dsp_create_by_type(1);
        jaxe.fmod_chan_add_dsp(fxChannel, 0, fx);
        const fxFeed = jaxe.fmod_dsp_add_input(fx, fxIn, 0);
        jaxe.fmod_dspconn_set_mix(fxFeed, 0.3);
        const fxSend = jaxe.fmod_dsp_add_input(fxOut, fx, 2);
        jaxe.fmod_dspconn_set_mix(fxSend, 0.5);
        const fxLive = connLive(fxFeed, 0.3) && connLive(fxSend, 0.5);
        const fxStop = jaxe.fmod_chan_stop(fxChannel);
        // The stop takes the DSP out of the channel's chain and moves its
        // input onto the chain. The send out of it stays.
        check('chan_stop_ends_feed_keeps_send', fxLive && fxStop === OK && connDead(fxFeed)
            && connLive(fxSend, 0.5) && connLive(bystander, 0.4), `live=${fxLive} stop=${fxStop}`);
        const fxFeed2 = jaxe.fmod_dsp_add_input(fx, fxIn, 0);
        const fxFed = connLive(fxFeed2, 1.0);
        const fxRelease = jaxe.fmod_dsp_release(fx);
        check('dsp_release_ends_its_connections', fxFed && fxRelease === OK && connDead(fxFeed2)
            && connDead(fxSend) && connLive(bystander, 0.4), `fed=${fxFed} release=${fxRelease}`);
        jaxe.fmod_dsp_release(fxIn);
        jaxe.fmod_dsp_release(fxOut);
        jaxe.fmod_core_pcm_release(fxStream);

        const relParent = jaxe.fmod_cg_create('cc-rel-parent');
        const relChild = jaxe.fmod_cg_create('cc-rel-child');
        const relConn = jaxe.fmod_cg_add_group(relParent, relChild, true);
        jaxe.fmod_dspconn_set_mix(relConn, 0.7);
        const relLive = connLive(relConn, 0.7);
        const relRelease = jaxe.fmod_cg_release(relChild);
        check('cg_release_ends_child_connection', relLive && relRelease === OK && connDead(relConn)
            && connLive(bystander, 0.4), `live=${relLive} release=${relRelease}`);
        jaxe.fmod_cg_release(relParent);

        const rmGroup = jaxe.fmod_cg_create('cc-rm');
        const rmDsp = jaxe.fmod_dsp_create_by_type(3);
        const rmIn = jaxe.fmod_dsp_create_by_type(1);
        const rmOut = jaxe.fmod_dsp_create_by_type(1);
        jaxe.fmod_cg_add_dsp(rmGroup, 0, rmDsp);
        const rmFeed = jaxe.fmod_dsp_add_input(rmDsp, rmIn, 0);
        jaxe.fmod_dspconn_set_mix(rmFeed, 0.3);
        const rmSend = jaxe.fmod_dsp_add_input(rmOut, rmDsp, 2);
        jaxe.fmod_dspconn_set_mix(rmSend, 0.5);
        const rmLive = connLive(rmFeed, 0.3) && connLive(rmSend, 0.5);
        const rmResult = jaxe.fmod_cg_remove_dsp(rmGroup, rmDsp);
        check('cg_remove_dsp_ends_feed_keeps_send', rmLive && rmResult === OK && connDead(rmFeed)
            && connLive(rmSend, 0.5) && connLive(bystander, 0.4), `live=${rmLive} remove=${rmResult}`);
        const daFeed = jaxe.fmod_dsp_add_input(rmDsp, rmIn, 0);
        const daLive = connLive(daFeed, 1.0);
        const daResult = jaxe.fmod_dsp_disconnect_all(rmDsp, true, false);
        check('dsp_disconnect_all_ends_inputs_keeps_send', daLive && daResult === OK && connDead(daFeed)
            && connLive(rmSend, 0.5) && connLive(bystander, 0.4), `live=${daLive} result=${daResult}`);
        jaxe.fmod_dsp_release(rmOut);
        jaxe.fmod_dsp_release(rmIn);
        jaxe.fmod_dsp_release(rmDsp);
        jaxe.fmod_cg_release(rmGroup);

        // A reorder in a chain leaves the child's connection and a send out
        // of the chain alone
        const roParent = jaxe.fmod_cg_create('cc-ro-parent');
        const roChild = jaxe.fmod_cg_create('cc-ro-child');
        const roConn = jaxe.fmod_cg_add_group(roParent, roChild, true);
        jaxe.fmod_dspconn_set_mix(roConn, 0.6);
        const roX = jaxe.fmod_dsp_create_by_type(3);
        const roY = jaxe.fmod_dsp_create_by_type(5);
        const roOut = jaxe.fmod_dsp_create_by_type(1);
        jaxe.fmod_cg_add_dsp(roParent, 0, roX);
        jaxe.fmod_cg_add_dsp(roParent, 0, roY);
        const roSend = jaxe.fmod_dsp_add_input(roOut, roX, 2);
        jaxe.fmod_dspconn_set_mix(roSend, 0.5);
        const roIn = jaxe.fmod_dsp_create_by_type(1);
        const roFeed = jaxe.fmod_dsp_add_input(roX, roIn, 0);
        jaxe.fmod_dspconn_set_mix(roFeed, 0.3);
        const roLive = connLive(roConn, 0.6) && connLive(roSend, 0.5) && connLive(roFeed, 0.3);
        const roMove = jaxe.fmod_cg_set_dsp_index(roParent, roY, 1);
        check('cg_set_dsp_index_keeps_unrelated_connections', roLive && roMove === OK && connLive(roConn, 0.6)
            && connLive(roSend, 0.5) && connLive(bystander, 0.4), `live=${roLive} move=${roMove}`);
        // FMOD moved the feed onto the DSP above roX. Its
        // handle fails, and a walk to the moved connection mints a new one.
        let roWalked = 0;
        for (let i = 0; i < jaxe.fmod_dsp_get_num_inputs(roY); i++) {
            const c = jaxe.fmod_dsp_get_input_connection(roY, i);
            if (Math.abs(jaxe.fmod_dspconn_get_mix(c) - 0.3) < 0.001) roWalked = c;
        }
        check('cg_set_dsp_index_moved_feed_rewalks', connDead(roFeed) && roWalked !== 0 && roWalked !== roFeed
            && connLive(roWalked, 0.3), `walked=${roWalked} feed=${roFeed}`);
        jaxe.fmod_dsp_release(roIn);
        jaxe.fmod_cg_remove_dsp(roParent, roX);
        jaxe.fmod_cg_remove_dsp(roParent, roY);
        jaxe.fmod_dsp_release(roOut);
        jaxe.fmod_dsp_release(roX);
        jaxe.fmod_dsp_release(roY);
        jaxe.fmod_cg_release(roChild);
        jaxe.fmod_cg_release(roParent);

        // FMOD destroys a standard input of a DSP that a chain takes
        const fedParent = jaxe.fmod_cg_create('cc-fed-parent');
        const fedSource = jaxe.fmod_dsp_create_by_type(1);
        const fedDsp = jaxe.fmod_dsp_create_by_type(3);
        const fedConn = jaxe.fmod_dsp_add_input(fedDsp, fedSource, 0);
        const fedLive = connLive(fedConn, 1.0);
        const fedAdd = jaxe.fmod_cg_add_dsp(fedParent, 0, fedDsp);
        check('cg_add_dsp_fed_ends_connection', fedLive && fedAdd === OK && connDead(fedConn)
            && connLive(bystander, 0.4), `live=${fedLive} add=${fedAdd}`);
        jaxe.fmod_cg_remove_dsp(fedParent, fedDsp);
        jaxe.fmod_dsp_release(fedDsp);
        jaxe.fmod_dsp_release(fedSource);
        jaxe.fmod_cg_release(fedParent);

        // An addDsp past the end of the DSP's own chain takes the DSP out
        // of the chain before FMOD refuses the index
        const refParent = jaxe.fmod_cg_create('cc-refused-parent');
        const refChild = jaxe.fmod_cg_create('cc-refused-child');
        const refConn = jaxe.fmod_cg_add_group(refParent, refChild, true);
        const refDsp = jaxe.fmod_dsp_create_by_type(3);
        const refFirst = jaxe.fmod_cg_add_dsp(refParent, jaxe.fmod_cg_get_num_dsps(refParent), refDsp);
        const refLive = refFirst === OK && connLive(refConn, 1.0);
        const refAgain = jaxe.fmod_cg_add_dsp(refParent, jaxe.fmod_cg_get_num_dsps(refParent), refDsp);
        check('cg_add_dsp_refused_ends_connection', refLive && refAgain === INVALID_PARAM && connDead(refConn)
            && connLive(bystander, 0.4), `live=${refLive} again=${refAgain}`);
        jaxe.fmod_cg_remove_dsp(refParent, refDsp);
        jaxe.fmod_dsp_release(refDsp);
        jaxe.fmod_cg_release(refChild);
        jaxe.fmod_cg_release(refParent);
        jaxe.fmod_dsp_release(bystanderOut);
        jaxe.fmod_dsp_release(bystanderIn);
    }

    // FMOD lists a DSP that another chain holds in both chains, and a later
    // release frees it while one chain still uses it. So a second chain
    // refuses the DSP until the first one removes it. A channel's own DSP
    // counts as held by that channel. An add after the removal, a re-add in
    // the same chain, and a reuse after the holding channel stops or ends
    // all work.
    {
        const INUSE = jaxe.FMOD.ERR_DSP_INUSE;
        const inGroupH = jaxe.fmod_cg_create('cc-inuse-group');
        const inOtherH = jaxe.fmod_cg_create('cc-inuse-other');
        const inStream = jaxe.fmod_core_pcm_create(48000, 1, 4096);
        const inChannel = jaxe.fmod_core_pcm_play(inStream, inGroupH, false);
        const inDsp = jaxe.fmod_dsp_create_by_type(3);
        const first = jaxe.fmod_chan_add_dsp(inChannel, 0, inDsp);
        const group = jaxe.fmod_cg_add_dsp(inGroupH, 0, inDsp);
        const other = jaxe.fmod_cg_add_dsp(inOtherH, 0, inDsp);
        const fader = jaxe.fmod_cg_add_dsp(inOtherH, 0, jaxe.fmod_chan_get_dsp(inChannel, -2));
        const remove = jaxe.fmod_chan_remove_dsp(inChannel, inDsp);
        const afterRemove = jaxe.fmod_cg_add_dsp(inGroupH, 0, inDsp);
        const same = jaxe.fmod_cg_add_dsp(inGroupH, 1, inDsp);
        const sameIndex = jaxe.fmod_cg_get_dsp_index(inGroupH, inDsp);
        const back = jaxe.fmod_chan_add_dsp(inChannel, 0, inDsp);
        jaxe.fmod_cg_remove_dsp(inGroupH, inDsp);
        const stopStream = jaxe.fmod_core_pcm_create(48000, 1, 4096);
        const stopChannel = jaxe.fmod_core_pcm_play(stopStream, inOtherH, false);
        const stopFirst = jaxe.fmod_chan_add_dsp(stopChannel, 0, inDsp);
        jaxe.fmod_chan_stop(stopChannel);
        const afterStop = jaxe.fmod_chan_add_dsp(inChannel, 0, inDsp);
        // The group stop ends the channel with no call on its handle
        jaxe.fmod_cg_stop(inGroupH);
        const afterEnd = jaxe.fmod_cg_add_dsp(inOtherH, 0, inDsp);
        const cleanup = jaxe.fmod_cg_remove_dsp(inOtherH, inDsp);
        const release = jaxe.fmod_dsp_release(inDsp);
        check('chan_add_dsp_held_elsewhere_inuse', first === OK && group === INUSE && other === INUSE && fader === INUSE
            && remove === OK && afterRemove === OK && same === OK && sameIndex === 1 && back === INUSE
            && stopFirst === OK && afterStop === OK && afterEnd === OK && cleanup === OK && release === OK,
            `first=${first} group=${group} other=${other} fader=${fader} remove=${remove} afterRemove=${afterRemove}`
            + ` same=${same}/${sameIndex} back=${back} stopFirst=${stopFirst} afterStop=${afterStop} afterEnd=${afterEnd}`
            + ` cleanup=${cleanup} release=${release}`);
        // The stop of an ended channel frees its slot
        jaxe.fmod_chan_stop(inChannel);
        jaxe.fmod_core_pcm_release(stopStream);
        jaxe.fmod_core_pcm_release(inStream);
        jaxe.fmod_cg_release(inOtherH);
        jaxe.fmod_cg_release(inGroupH);
    }

    // A group's own fader reached through a DSP walk has no recorded
    // chain. FMOD accepts it in a second chain and reads freed memory
    // after the group's release. So the second chain refuses it.
    {
        const OK = jaxe.FMOD.OK;
        const walkGroupH = jaxe.fmod_cg_create('cc-walk-group');
        const walkOtherH = jaxe.fmod_cg_create('cc-walk-other');
        const walkDsp = jaxe.fmod_dsp_create_by_type(3);
        const first = jaxe.fmod_cg_add_dsp(walkGroupH, 0, walkDsp);
        const fader = jaxe.fmod_dsp_get_input_dsp(walkDsp, 0);
        const faderIndex = jaxe.fmod_cg_get_dsp_index(walkGroupH, fader);
        const add = jaxe.fmod_cg_add_dsp(walkOtherH, 0, fader);
        const listed = jaxe.fmod_cg_get_dsp_index(walkOtherH, fader);
        if (add === OK) jaxe.fmod_cg_remove_dsp(walkOtherH, fader);
        const remove = jaxe.fmod_cg_remove_dsp(walkGroupH, walkDsp);
        const release = jaxe.fmod_dsp_release(walkDsp);
        check('cg_add_dsp_walked_fader_inuse', first === OK && fader !== 0 && faderIndex === 1
            && add === jaxe.FMOD.ERR_DSP_INUSE && listed === -1 && remove === OK && release === OK,
            `first=${first} fader=${fader}/${faderIndex} add=${add} listed=${listed} remove=${remove} release=${release}`);
        jaxe.fmod_cg_release(walkOtherH);
        jaxe.fmod_cg_release(walkGroupH);
    }

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
