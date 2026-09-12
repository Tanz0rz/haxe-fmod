// Regression harness for object-lifetime behavior on the html5 shim.
// It covers handle-slot reclaim after bulk instance destruction, and
// release on an already-destroyed instance.
// It covers callback routing for instances re-acquired through the instance
// list, plus channel-callback map cleanup.
// It closes on DSP connection invalidation at graph teardown, MEMFS cleanup
// for async bank loads, and zero-filled out-buffers on error paths.
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
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let fails = 0;
function check(label, cond, detail) {
    console.log(`LIFECYCLE_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}
// A path the run could not reach. It reads as neither a pass nor a failure.
function skip(label, detail) {
    console.log(`LIFECYCLE_TEST: ${label} skip ${detail || ''}`);
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
// The glue exports no stat call.
// A create call probes for existence, because it throws on an existing file.
// Cleanup removes the probe file afterwards.
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

    // --- a refused bulk destroy keeps every callback ---
    // FMOD accepts these calls on a live system, so the wrapper methods
    // are shadowed to force the refusal the restore exists for
    {
        const kept = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_set_callback_mask(kept, 0x20 /* STOPPED */);
        const before = JSON.stringify([jaxe.cbMasks, jaxe.psKeys, jaxe.pluginSeen]);
        const evdWrapper = jaxe.handleResolve(evd, jaxe.TYPE_EVD);
        const realReleaseAll = evdWrapper.releaseAllInstances;
        evdWrapper.releaseAllInstances = () => 40;
        const refused = jaxe.fmod_evd_release_all_instances(evd);
        evdWrapper.releaseAllInstances = realReleaseAll;
        check('refused_release_all_reports', refused === 40, `result=${refused}`);
        check('refused_release_all_keeps_state', JSON.stringify([jaxe.cbMasks, jaxe.psKeys, jaxe.pluginSeen]) === before, '');
        check('refused_release_all_keeps_instance', jaxe.handleResolve(kept, jaxe.TYPE_EVI) != null, '');
        const realUnloadAll = jaxe.gSystem.unloadAll;
        jaxe.gSystem.unloadAll = () => 40;
        const refusedAll = jaxe.fmod_sys_unload_all();
        jaxe.gSystem.unloadAll = realUnloadAll;
        check('refused_unload_all_reports', refusedAll === 40, `result=${refusedAll}`);
        check('refused_unload_all_keeps_state', JSON.stringify([jaxe.cbMasks, jaxe.psKeys, jaxe.pluginSeen]) === before, '');
        check('refused_unload_all_keeps_instance', jaxe.handleResolve(kept, jaxe.TYPE_EVI) != null, '');
        // The reinstalled callback still delivers
        jaxe.fmod_evi_start(kept);
        await pump(3);
        jaxe.fmod_evi_stop(kept, 1);
        let sawStopped = false;
        for (let i = 0; i < 100 && !sawStopped; i++) {
            await pump(1);
            for (const ev of drainEvents()) if (ev.handle === kept && ev.type === 0x20) sawStopped = true;
        }
        check('refused_destroy_callback_still_delivers', sawStopped, '');
        // A refused bank unload is the third bulk-destroy path, and it
        // puts every callback back the same way
        const masterBank = jaxe.fmod_sys_get_bank('bank:/Master');
        const bankWrapper = jaxe.handleResolve(masterBank, jaxe.TYPE_BANK);
        const realBankUnload = bankWrapper.unload;
        bankWrapper.unload = () => 40;
        const refusedBank = jaxe.fmod_bank_unload(masterBank);
        bankWrapper.unload = realBankUnload;
        check('refused_bank_unload_reports', refusedBank === 40, `result=${refusedBank}`);
        check('refused_bank_unload_keeps_state',
            JSON.stringify([jaxe.cbMasks, jaxe.psKeys, jaxe.pluginSeen]) === before, '');
        check('refused_bank_unload_keeps_instance', jaxe.handleResolve(kept, jaxe.TYPE_EVI) != null, '');
        jaxe.fmod_evi_release(kept);
        await pump(2);
        drainEvents();
    }

    // --- release on an already-destroyed instance frees the slot anyway ---
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

    // --- canary: destroying a released-then-relisted instance with a
    // callback installed ---
    // The uninstall-before-destroy invariant has no hook on this path.
    // The current glue survives it, as verified here.
    // The check pins that survival, so a glue regression turns the suite red.
    const inst5 = jaxe.fmod_evd_create_instance(evd);
    jaxe.fmod_evi_start(inst5);
    await pump(3);
    jaxe.fmod_evi_release(inst5); // slot freed, instance keeps playing
    const relist = [];
    check('corruption_relist', jaxe.fmod_evd_get_instance_list(evd, relist) === 1, '');
    const watched = relist[0];
    // 0x22 = STOPPED|DESTROYED, the exact mask the Haxe dispatcher installs
    check('corruption_mask_installed', jaxe.fmod_evi_set_callback_mask(watched, 0x22) === 0, '');
    // Stopping without releasing triggers the deferred destroy at fade end,
    // exactly the path a fire-and-forget user hits at natural event end
    jaxe.fmod_evi_stop(watched, 1 /* immediate */);
    await pump(10);
    let survived = true;
    let after = 0;
    try {
        after = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(after);
        await pump(3);
        jaxe.fmod_evi_stop(after, 1);
        jaxe.fmod_evi_release(after);
        await pump(3);
    } catch (e) {
        survived = false;
    }
    check('module_survives_destroy_after_relist_callback', survived && after > 0,
        `after=${after}`);
    drainEvents();

    // --- channel-callback map cleanup on stop and on natural end ---
    const ps = jaxe.fmod_core_pcm_create(8000, 1, 8000);
    check('pcm_create', ps > 0, `handle=${ps}`);
    const chan = jaxe.fmod_core_pcm_play(ps, 0, false);
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
    const chan2 = jaxe.fmod_core_play_sound(sndFinite, 0, false);
    check('finite_pcm_chan', chan2 > 0, `handle=${chan2}`);
    jaxe.fmod_chan_set_callback(chan2, true);
    check('chan2_map_entry', jaxe.chanCallbackHandles.size === 1, '');
    await pump(30);
    const endEvents = drainEvents().filter(ev => ev.type === jaxe.CB_CHAN_END);
    check('end_delivered_once', endEvents.length === 1 && endEvents[0].handle === chan2,
        `ends=${endEvents.length}`);
    check('chan_map_cleared_on_natural_end', jaxe.chanCallbackHandles.size === 0,
        `size=${jaxe.chanCallbackHandles.size}`);
    check('ended_channel_slot_freed_with_end_record', jaxe.handleResolve(chan2, jaxe.TYPE_CHAN) == null, '');

    // --- channels that end without a callback are reclaimed by the next play ---
    const liveBefore = jaxe.liveCount;
    for (let i = 0; i < 5; i++) {
        check(`cycle_${i}_plays`, jaxe.fmod_core_play_sound(sndFinite, 0, false) > 0, '');
        await pump(30);
    }
    const chanLast = jaxe.fmod_core_play_sound(sndFinite, 0, false);
    check('ended_channels_reclaimed_on_play', chanLast > 0 && jaxe.liveCount === liveBefore + 1,
        `live=${jaxe.liveCount} before=${liveBefore}`);
    await pump(30);
    // --- the pool lookup reclaims the slots of earlier pool generations ---
    const livePool = jaxe.liveCount;
    for (let i = 0; i < 3; i++) {
        jaxe.fmod_core_play_sound(sndFinite, 0, false);
        await pump(30);
        jaxe.fmod_sys_get_channel(0);
    }
    check('pool_lookup_reclaims_generations', jaxe.liveCount <= livePool + 2,
        `live=${jaxe.liveCount} before=${livePool}`);
    jaxe.fmod_core_release_sound(sndFinite);

    // --- the channel group handle an instance handed out goes with it ---
    const instGroup = jaxe.fmod_evd_create_instance(evd);
    check('start_instGroup', jaxe.fmod_evi_start(instGroup) === 0, '');
    await pump(3);
    const beforeGroup = jaxe.liveCount;
    const groupH = jaxe.fmod_evi_get_channel_group(instGroup);
    check('instGroup_channel_group', groupH > 0 && jaxe.liveCount === beforeGroup + 1, `handle=${groupH} live=${jaxe.liveCount}`);
    check('instGroup_channel_group_stable', jaxe.fmod_evi_get_channel_group(instGroup) === groupH, '');
    // An instance's group cannot be released by the game
    check('instGroup_release_refused', jaxe.fmod_cg_release(groupH) === 31 && jaxe.resolveCg(groupH) != null,
        `result=${jaxe.lastResult}`);
    // A callback on the instance's group comes off before FMOD destroys
    // the group, and the freed slot takes its map entry with it, so a new
    // group at the same address cannot inherit one
    const groupRaw = jaxe.rawPtr(jaxe.resolveCg(groupH));
    check('instGroup_callback_installed', jaxe.fmod_cg_set_callback(groupH, true) === 0
        && jaxe.chanCallbackHandles.get(groupRaw) === groupH, `result=${jaxe.lastResult}`);
    jaxe.fmod_evi_stop(instGroup, 1);
    jaxe.fmod_evi_release(instGroup);
    check('channel_group_freed_with_instance',
        jaxe.liveCount === beforeGroup - 1 && jaxe.handleResolve(groupH, jaxe.TYPE_CHANGROUP) == null,
        `live=${jaxe.liveCount} before=${beforeGroup}`);

    check('instGroup_callback_map_pruned_with_slot', !jaxe.chanCallbackHandles.has(groupRaw),
        `size=${jaxe.chanCallbackHandles.size}`);

    // A bulk destroy takes the shim callback off every instance group in
    // its scope first, and a refused call puts it back. FMOD must never
    // free a group with the shim callback installed.
    {
        const instRefuse = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(instRefuse);
        await pump(3);
        const refuseGroup = jaxe.fmod_evi_get_channel_group(instRefuse);
        check('refuse_group_handle', refuseGroup > 0, `handle=${refuseGroup}`);
        check('refuse_group_callback_installed', jaxe.fmod_cg_set_callback(refuseGroup, true) === 0, '');
        const refuseWrapper = jaxe.resolveCg(refuseGroup);
        const groupCalls = [];
        const realGroupSet = refuseWrapper.setCallback;
        refuseWrapper.setCallback = function (cb) {
            groupCalls.push(cb === null ? 'off' : 'on');
            return realGroupSet.call(refuseWrapper, cb);
        };
        const evdW = jaxe.handleResolve(evd, jaxe.TYPE_EVD);
        const realRA = evdW.releaseAllInstances;
        evdW.releaseAllInstances = () => 40;
        const refusedRA = jaxe.fmod_evd_release_all_instances(evd);
        evdW.releaseAllInstances = realRA;
        check('refused_release_all_cycles_group_callback',
            refusedRA === 40 && groupCalls.join(',') === 'off,on',
            `result=${refusedRA} calls=${groupCalls.join(',')}`);
        check('refused_release_all_keeps_group_map',
            jaxe.chanCallbackHandles.get(jaxe.rawPtr(refuseWrapper)) === refuseGroup, '');
        // A bulk destroy scoped to another description leaves this
        // instance's group callback installed: FMOD destroyed nothing here
        const otherEvd = jaxe.fmod_sys_get_event('event:/SFX/Jump');
        groupCalls.length = 0;
        const okRA = jaxe.fmod_evd_release_all_instances(otherEvd);
        refuseWrapper.setCallback = realGroupSet;
        check('accepted_release_all_keeps_other_group_callback',
            okRA === 0 && groupCalls.length === 0
            && jaxe.chanCallbackHandles.get(jaxe.rawPtr(refuseWrapper)) === refuseGroup,
            `result=${okRA} calls=${groupCalls.join(',')}`);
        jaxe.fmod_cg_set_callback(refuseGroup, false);
        jaxe.fmod_evi_stop(instRefuse, 1);
        jaxe.fmod_evi_release(instRefuse);
        await pump(3);
        drainEvents();
    }

    // --- DSP connection handles die with graph teardown ---
    const dsp = jaxe.fmod_dsp_create_by_type(3 /* echo */);
    check('dsp_created', dsp > 0, `handle=${dsp}`);
    const ps2 = jaxe.fmod_core_pcm_create(8000, 1, 8000);
    const chan3 = jaxe.fmod_core_pcm_play(ps2, 0, false);
    check('chan_add_dsp', jaxe.fmod_chan_add_dsp(chan3, 0, dsp) === 0, '');
    await pump(2);
    const conn = jaxe.fmod_dsp_get_input_connection(dsp, 0);
    // NRT mixing links the connection on its own schedule, so each path
    // below runs only once its handle exists. One of the two must run.
    let connInvalidationsRun = 0;
    if (conn > 0) {
        check('conn_minted', true, `handle=${conn}`);
        check('chan_remove_dsp', jaxe.fmod_chan_remove_dsp(chan3, dsp) === 0, '');
        check('conn_invalidated_by_remove_dsp',
            jaxe.handleResolve(conn, jaxe.TYPE_DSPCONN) == null, '');
        connInvalidationsRun++;
    } else {
        skip('conn_invalidated_by_remove_dsp', `conn=${conn}`);
        jaxe.fmod_chan_remove_dsp(chan3, dsp);
    }
    jaxe.fmod_chan_add_dsp(chan3, 0, dsp);
    await pump(2);
    const conn2 = jaxe.fmod_dsp_get_input_connection(dsp, 0);
    jaxe.fmod_chan_stop(chan3);
    if (conn2 > 0) {
        check('conn_invalidated_by_chan_stop',
            jaxe.handleResolve(conn2, jaxe.TYPE_DSPCONN) == null, '');
        connInvalidationsRun++;
    } else {
        skip('conn_invalidated_by_chan_stop', `conn=${conn2}`);
    }
    check('conn_invalidation_covered', connInvalidationsRun > 0, `paths=${connInvalidationsRun}`);
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

    // --- a bank that gets no handle slot is unloaded again, without a throw ---
    const realAlloc = jaxe.handleAlloc;
    jaxe.handleAlloc = function () { return 0; };
    const banksBefore = jaxe.fmod_sys_get_bank_count();
    const arrayBuf = bankBytes.buffer.slice(bankBytes.byteOffset, bankBytes.byteOffset + bankBytes.length);
    let fullHandle = -1, fullThrew = null;
    try { fullHandle = jaxe.fmod_sys_load_bank_memory(arrayBuf, bankBytes.length, 0); } catch (e) { fullThrew = e; }
    jaxe.handleAlloc = realAlloc;
    check('full_table_bank_load_reports_memory',
        fullThrew === null && fullHandle === 0 && jaxe.lastResult === jaxe.ERR_MEMORY,
        `threw=${fullThrew} handle=${fullHandle} result=${jaxe.lastResult}`);
    // The unload lands on the next Studio update
    await pump(3);
    check('full_table_bank_unloaded_again', jaxe.fmod_sys_get_bank_count() === banksBefore,
        `banks=${jaxe.fmod_sys_get_bank_count()} before=${banksBefore}`);

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
