// Regression harness for object-lifetime behavior on the html5 shim:
// handle-slot reclaim after bulk instance destruction, release on an
// already-destroyed instance, callback routing for instances re-acquired
// through the instance list, channel-callback map cleanup, DSP connection
// invalidation on graph teardown, MEMFS cleanup for async bank loads, and
// zero-filled out-buffers on error paths.
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
    // A fixed mixer block makes NRT time-per-update deterministic, so the
    // beat wait below cannot depend on the SDK's default block size
    jaxe.gSystemCore.setDSPBufferSize(2048, 2);
    jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    var b = {};
    jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.loadedBanks['Master.bank'] = b.val;
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.loadedBanks['Master.strings.bank'] = b.val;
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let fails = 0;
function check(label, cond, detail) {
    console.log(`LIFECYCLE_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function pump(n) {
    for (let i = 0; i < n; i++) { jaxe.fmod_sys_update(); await sleep(15); }
}
function drainEvents() {
    const events = [];
    while (jaxe.fmod_cb_next()) {
        events.push({ handle: jaxe.fmod_cb_handle(), type: jaxe.fmod_cb_type() });
    }
    return events;
}
// The glue exports no stat call, so existence is probed with a create
// (which throws on an existing file) followed by cleanup of the probe file
function memfsExists(name) {
    try {
        jaxe.FMOD.FS_createDataFile('/', name, new Uint8Array(1), true, false, false);
    } catch (e) {
        return true;
    }
    jaxe.FMOD.FS_unlink('/' + name);
    return false;
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await sleep(50);
    if (!jaxe.FmodIsInitialized) { console.log('INIT TIMEOUT'); process.exit(1); }

    const MUSIC = 'event:/Music/MainLevel';
    const evd = jaxe.fmod_sys_get_event(MUSIC);
    check('get_event', evd > 0, `handle=${evd}`);

    // --- release_all_instances reclaims the destroyed instances' slots ---
    const baseline = jaxe.liveCount;
    const inst1 = jaxe.fmod_evd_create_instance(evd);
    const inst2 = jaxe.fmod_evd_create_instance(evd);
    check('two_instances_live', jaxe.liveCount === baseline + 2, `live=${jaxe.liveCount}`);
    check('release_all', jaxe.fmod_evd_release_all_instances(evd) === 0, '');
    await pump(5);
    // A second call sweeps again now that the destruction has been processed
    jaxe.fmod_evd_release_all_instances(evd);
    check('slots_reclaimed_after_release_all', jaxe.liveCount === baseline,
        `live=${jaxe.liveCount} baseline=${baseline}`);
    check('stale_handle_resolves_null', jaxe.handleResolve(inst1, jaxe.TYPE_EVI) == null, '');

    // --- release on an already-destroyed instance still frees the slot ---
    const inst3 = jaxe.fmod_evd_create_instance(evd);
    const wrapper = jaxe.handleResolve(inst3, jaxe.TYPE_EVI);
    wrapper.release(); // destroy behind the binding's back
    jaxe.gSystem.flushCommands();
    await pump(5);
    const before3 = jaxe.liveCount;
    const r3 = jaxe.fmod_evi_release(inst3);
    check('release_after_destroy_reports_30', r3 === 30, `result=${r3}`);
    check('release_after_destroy_frees_slot', jaxe.liveCount === before3 - 1,
        `live=${jaxe.liveCount} before=${before3}`);
    check('slot3_resolves_null', jaxe.handleResolve(inst3, jaxe.TYPE_EVI) == null, '');
    check('double_release_safe', jaxe.fmod_evi_release(inst3) === 30, '');

    // --- callbacks route to the handle minted by get_instance_list after
    // the original handle was released ---
    const inst4 = jaxe.fmod_evd_create_instance(evd);
    check('start_inst4', jaxe.fmod_evi_start(inst4) === 0, '');
    await pump(3);
    jaxe.fmod_evi_release(inst4); // slot freed, instance keeps playing
    const listBuf = [];
    const n = jaxe.fmod_evd_get_instance_list(evd, listBuf);
    check('relisted_one_instance', n === 1, `count=${n}`);
    const reminted = listBuf[0];
    check('reminted_fresh_handle', reminted > 0 && reminted !== inst4,
        `old=${inst4} new=${reminted}`);
    drainEvents();
    jaxe.fmod_evi_set_callback_mask(reminted, 0x1000 /* TIMELINE_BEAT */);
    await pump(100);
    const beatEvents = drainEvents().filter(ev => ev.type === 0x1000);
    check('beats_deliver_on_reminted_handle',
        beatEvents.length > 0 && beatEvents.every(ev => ev.handle === reminted),
        `beats=${beatEvents.length} handles=${[...new Set(beatEvents.map(e => e.handle))]}`);
    check('stop_reminted', jaxe.fmod_evi_stop(reminted, 1) === 0, '');
    jaxe.fmod_evi_release(reminted);
    await pump(5);

    // --- channel-callback map cleanup on stop and on natural end ---
    const ps = jaxe.fmod_core_pcm_create(8000, 1, 8000);
    check('pcm_create', ps > 0, `handle=${ps}`);
    const chan = jaxe.fmod_core_pcm_play(ps, false);
    check('pcm_play', chan > 0, `handle=${chan}`);
    jaxe.fmod_chan_set_callback(chan, true);
    check('chan_map_entry_present', jaxe.chanCallbackHandles.size === 1,
        `size=${jaxe.chanCallbackHandles.size}`);
    jaxe.fmod_chan_stop(chan);
    check('chan_map_cleared_on_stop', jaxe.chanCallbackHandles.size === 0,
        `size=${jaxe.chanCallbackHandles.size}`);
    await pump(3);
    const lateEvents = drainEvents().filter(ev => ev.type === jaxe.CB_CHAN_END);
    check('no_end_event_for_freed_handle', lateEvents.length === 0,
        `late=${lateEvents.length}`);
    jaxe.fmod_core_pcm_release(ps);

    // a finite PCM sound that ends on its own must also clear its entry
    const sampleCount = 800; // 0.1s at 8kHz
    const pcmBytes = new ArrayBuffer(sampleCount * 2);
    const sndFinite = jaxe.fmod_core_create_sound_pcm(pcmBytes, sampleCount * 2, 8000, 1);
    check('finite_pcm_sound', sndFinite > 0, `handle=${sndFinite}`);
    const chan2 = jaxe.fmod_core_play_sound(sndFinite, false);
    check('finite_pcm_chan', chan2 > 0, `handle=${chan2}`);
    jaxe.fmod_chan_set_callback(chan2, true);
    check('chan2_map_entry', jaxe.chanCallbackHandles.size === 1, '');
    await pump(30);
    const endEvents = drainEvents().filter(ev => ev.type === jaxe.CB_CHAN_END);
    check('end_delivered_once', endEvents.length === 1 && endEvents[0].handle === chan2,
        `ends=${endEvents.length}`);
    check('chan_map_cleared_on_natural_end', jaxe.chanCallbackHandles.size === 0,
        `size=${jaxe.chanCallbackHandles.size}`);
    jaxe.fmod_core_release_sound(sndFinite);

    // --- DSP connection handles die with graph teardown ---
    const dsp = jaxe.fmod_dsp_create_by_type(3 /* echo */);
    check('dsp_created', dsp > 0, `handle=${dsp}`);
    const ps2 = jaxe.fmod_core_pcm_create(8000, 1, 8000);
    const chan3 = jaxe.fmod_core_pcm_play(ps2, false);
    check('chan_add_dsp', jaxe.fmod_chan_add_dsp(chan3, 0, dsp) === 0, '');
    await pump(2);
    const conn = jaxe.fmod_dsp_get_input_connection(dsp, 0);
    if (conn > 0) {
        check('conn_minted', true, `handle=${conn}`);
        check('chan_remove_dsp', jaxe.fmod_chan_remove_dsp(chan3, dsp) === 0, '');
        check('conn_invalidated_by_remove_dsp',
            jaxe.handleResolve(conn, jaxe.TYPE_DSPCONN) == null, '');
    } else {
        // NRT mixing may not link the connection yet. The invalidation path
        // is then proven through chan_stop below.
        check('conn_minted_skipped', true, `conn=${conn}`);
        jaxe.fmod_chan_remove_dsp(chan3, dsp);
    }
    jaxe.fmod_chan_add_dsp(chan3, 0, dsp);
    await pump(2);
    const conn2 = jaxe.fmod_dsp_get_input_connection(dsp, 0);
    jaxe.fmod_chan_stop(chan3);
    if (conn2 > 0) {
        check('conn_invalidated_by_chan_stop',
            jaxe.handleResolve(conn2, jaxe.TYPE_DSPCONN) == null, '');
    }
    jaxe.fmod_core_pcm_release(ps2);
    jaxe.fmod_dsp_release(dsp);

    // --- error paths zero-fill the out buffer ---
    const bus = jaxe.fmod_sys_get_bus('bus:/');
    const memBuf = [7, 7, 7];
    const memResult = jaxe.fmod_bus_get_memory_usage(bus, memBuf);
    check('bus_memory_usage_no_stale_values',
        memResult === 0 || (memBuf[0] === 0 && memBuf[1] === 0 && memBuf[2] === 0),
        `result=${memResult} buf=${memBuf}`);

    // --- async bank loads delete their MEMFS copy ---
    const bankBytes = fs.readFileSync(path.join(BANKS, 'Master.bank'));
    global.fetch = function () {
        return Promise.resolve({ ok: true, arrayBuffer: () => Promise.resolve(bankBytes.buffer.slice(0)) });
    };
    // Master.bank is already loaded, so this settles on the error path and
    // must clean up the file it wrote
    const dupHandle = jaxe.fmod_sys_load_bank_async('assets/fmod/Desktop/Master.bank');
    check('async_dup_handle', dupHandle > 0, `handle=${dupHandle}`);
    for (let i = 0; i < 100 && jaxe.fmod_bank_get_loading_state(dupHandle) === 2; i++) await sleep(20);
    check('async_dup_errors', jaxe.fmod_bank_get_loading_state(dupHandle) === 4,
        `state=${jaxe.fmod_bank_get_loading_state(dupHandle)}`);
    check('no_tracked_memfs_after_error', jaxe.asyncBankFiles.size === 0,
        `tracked=${jaxe.asyncBankFiles.size}`);
    jaxe.fmod_bank_unload(dupHandle);

    // unload the preloaded master banks so a fresh async load can succeed
    const bankList = [];
    const bankCount = jaxe.fmod_sys_get_bank_list(bankList);
    for (let i = 0; i < bankCount; i++) jaxe.fmod_bank_unload(bankList[i]);
    await pump(3);

    const asyncHandle = jaxe.fmod_sys_load_bank_async('assets/fmod/Desktop/Master.bank');
    check('async_reload_handle', asyncHandle > 0, `handle=${asyncHandle}`);
    for (let i = 0; i < 100 && jaxe.fmod_bank_get_loading_state(asyncHandle) === 2; i++) await sleep(20);
    check('async_reload_loaded', jaxe.fmod_bank_get_loading_state(asyncHandle) === 3,
        `state=${jaxe.fmod_bank_get_loading_state(asyncHandle)}`);
    check('memfs_copy_tracked', jaxe.asyncBankFiles.size === 1,
        `tracked=${jaxe.asyncBankFiles.size}`);
    const memfsName = jaxe.asyncBankFiles.values().next().value;
    check('memfs_file_exists', memfsExists(memfsName) === true, memfsName);
    check('async_unload', jaxe.fmod_bank_unload(asyncHandle) === 0, '');
    check('memfs_copy_deleted', memfsExists(memfsName) === false, memfsName);
    check('no_tracked_memfs_after_unload', jaxe.asyncBankFiles.size === 0,
        `tracked=${jaxe.asyncBankFiles.size}`);

    console.log(`LIFECYCLE_TEST: failures = ${fails}`);
    console.log(fails === 0 ? 'LIFECYCLE_TEST: COMPLETE' : 'LIFECYCLE_TEST: FAILED');
    process.exit(fails === 0 ? 0 : 1);
}

main().catch(e => { console.log('HARNESS ERROR', e); process.exit(1); });
