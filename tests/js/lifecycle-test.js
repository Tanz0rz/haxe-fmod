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
    for (const n of ['Master.bank', 'Master.strings.bank', 'Extras.bank']) {
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
    // The shim's own init keeps BANK_UNLOAD installed from here on
    jaxe.installStudioCallback(jaxe.studioCallbackMask);
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
        // The unloadAll and bank-unload paths destroy instances too. They
        // take the shim callback off every instance group in scope first,
        // and put it back when FMOD refuses
        const wide = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(wide);
        await pump(3);
        const wideGroup = jaxe.fmod_evi_get_channel_group(wide);
        check('wide_group_handle', wideGroup > 0, `handle=${wideGroup}`);
        check('wide_group_callback_installed', jaxe.fmod_cg_set_callback(wideGroup, true) === 0, '');
        const wideWrapper = jaxe.resolveCg(wideGroup);
        const wideCalls = [];
        const realWideSet = wideWrapper.setCallback;
        wideWrapper.setCallback = function (cb) {
            wideCalls.push(cb === null ? 'off' : 'on');
            return realWideSet.call(wideWrapper, cb);
        };
        jaxe.gSystem.unloadAll = () => 40;
        const refusedAll2 = jaxe.fmod_sys_unload_all();
        jaxe.gSystem.unloadAll = realUnloadAll;
        check('refused_unload_all_cycles_group_callback',
            refusedAll2 === 40 && wideCalls.join(',') === 'off,on',
            `result=${refusedAll2} calls=${wideCalls.join(',')}`);
        wideCalls.length = 0;
        bankWrapper.unload = () => 40;
        const refusedBank2 = jaxe.fmod_bank_unload(masterBank);
        bankWrapper.unload = realBankUnload;
        check('refused_bank_unload_cycles_group_callback',
            refusedBank2 === 40 && wideCalls.join(',') === 'off,on',
            `result=${refusedBank2} calls=${wideCalls.join(',')}`);
        // A bank whose event list cannot be read leaves the scope
        // unknown, so every callback comes off, the way the native shims
        // fall back
        wideCalls.length = 0;
        const realEventList = bankWrapper.getEventList;
        bankWrapper.getEventList = () => 40;
        bankWrapper.unload = () => 40;
        const refusedBank3 = jaxe.fmod_bank_unload(masterBank);
        bankWrapper.unload = realBankUnload;
        bankWrapper.getEventList = realEventList;
        wideWrapper.setCallback = realWideSet;
        check('unlisted_bank_unload_falls_back_to_every_callback',
            refusedBank3 === 40 && wideCalls.join(',') === 'off,on',
            `result=${refusedBank3} calls=${wideCalls.join(',')}`);
        check('unlisted_bank_unload_keeps_state',
            JSON.stringify([jaxe.cbMasks, jaxe.psKeys, jaxe.pluginSeen]) === before, '');
        check('refused_bulk_destroy_keeps_group_map',
            jaxe.chanCallbackHandles.get(jaxe.rawPtr(wideWrapper)) === wideGroup, '');
        jaxe.fmod_cg_set_callback(wideGroup, false);
        jaxe.fmod_evi_stop(wide, 1);
        jaxe.fmod_evi_release(wide);
        await pump(3);
        drainEvents();
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
    check('instGroup_release_refused', jaxe.fmod_cg_release(groupH) === jaxe.ERR_INVALID_PARAM && jaxe.resolveCg(groupH) != null,
        `result=${jaxe.lastResult}`);
    // A callback on the instance's group comes off before FMOD destroys
    // the group. The freed slot takes its map entry with it, so a new
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

    // A group FMOD destroyed keeps its slot until its owner instance's
    // slot goes. The web runtime never reports the destruction, so the
    // drain asks about every instance a handle hangs off and frees the
    // dead one with its group handle.
    {
        const staleLive = jaxe.liveCount;
        const staleInst = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(staleInst);
        await pump(3);
        const staleGroup = jaxe.fmod_evi_get_channel_group(staleInst);
        const staleChild = jaxe.fmod_cg_get_group(staleGroup, 0);
        check('stale_group_handle', staleGroup > 0 && staleChild > 0, `handle=${staleGroup} child=${staleChild}`);
        // Destroy the instance behind the shim's back, so the group dies
        // with it and every slot stays
        jaxe.fmod_evi_stop(staleInst, 1);
        jaxe.handleResolve(staleInst, jaxe.TYPE_EVI).release();
        jaxe.gSystem.flushCommands();
        await pump(3);
        check('dead_group_slot_lingers_until_drain', jaxe.handleResolve(staleGroup, jaxe.TYPE_CHANGROUP) != null, '');
        drainEvents();
        check('drain_frees_destroyed_instance_and_its_groups',
            jaxe.handleResolve(staleInst, jaxe.TYPE_EVI) == null
            && jaxe.handleResolve(staleGroup, jaxe.TYPE_CHANGROUP) == null
            && jaxe.handleResolve(staleChild, jaxe.TYPE_CHANGROUP) == null,
            `inst=${jaxe.handleIsLive(staleInst)} group=${jaxe.handleIsLive(staleGroup)} child=${jaxe.handleIsLive(staleChild)}`);
        check('drain_reclaim_leaves_no_slots', jaxe.liveCount === staleLive,
            `live=${jaxe.liveCount} before=${staleLive}`);
    }

    // A slot naming a group that FMOD freed behind the shim's back goes
    // when a created group lands at that address, so no walk hands the
    // new group out under the dead handle
    {
        const reuseLive = jaxe.liveCount;
        const first = jaxe.fmod_cg_create('reuse-a');
        const wrapper = jaxe.resolveCg(first);
        const raw = jaxe.rawPtr(wrapper);
        // A second wrapper for the same group, as a walk would hold it
        const master = jaxe.resolveCg(jaxe.fmod_cg_get_master());
        let second = null;
        const n = {};
        master.getNumGroups(n);
        for (let i = 0; i < n.val && !second; i++) {
            const g = {};
            master.getGroup(i, g);
            if (jaxe.rawPtr(g.val) === raw) second = g.val; else jaxe.dropWrapper(g.val);
        }
        const stale = second ? jaxe.handleAlloc(second, jaxe.TYPE_CHANGROUP) : 0;
        wrapper.release();
        let fresh = 0;
        let fresh2 = 0;
        fresh = jaxe.fmod_cg_create('reuse-b');
        const reused = jaxe.rawPtr(jaxe.resolveCg(fresh)) === raw;
        if (!reused) fresh2 = jaxe.fmod_cg_create('reuse-c');
        check('cg_create_frees_stale_slots_at_its_address',
            stale > 0 && (reused || jaxe.rawPtr(jaxe.resolveCg(fresh2)) === raw)
            && jaxe.handleResolve(stale, jaxe.TYPE_CHANGROUP) == null
            && jaxe.handleResolve(first, jaxe.TYPE_CHANGROUP) == null,
            `stale=${stale} reused=${reused} first=${jaxe.handleIsLive(first)}`);
        jaxe.fmod_cg_release(fresh);
        if (fresh2) jaxe.fmod_cg_release(fresh2);
        // The master group lookup keeps its slot
        check('cg_create_reuse_leaves_no_slots', jaxe.liveCount === reuseLive + 1,
            `live=${jaxe.liveCount} before=${reuseLive}`);
    }

    // A handle the game reaches through another one dies with it, refuses
    // release, and a volatile one dies at the next update drain or the next
    // call that stops, releases, or unloads anything.
    // The walked handles once outlived their instance and a new group at
    // the same address answered to them.
    {
        const borrowLive = jaxe.liveCount;
        const inst = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(inst);
        await pump(3);
        const group = jaxe.fmod_evi_get_channel_group(inst);
        const parent = jaxe.fmod_cg_get_parent_group(group);
        const head = jaxe.fmod_cg_get_dsp(group, -1);
        check('borrowed_walk_minted', group > 0 && parent > 0 && head > 0, `group=${group} parent=${parent} head=${head}`);
        check('borrowed_walk_linked', jaxe.slots[parent & 0xFFFF].parent === group
            && jaxe.slots[group & 0xFFFF].parent === inst && jaxe.slots[head & 0xFFFF].parent === group, '');
        check('borrowed_group_release_refused', jaxe.fmod_cg_release(parent) === jaxe.ERR_INVALID_PARAM, `result=${jaxe.lastResult}`);
        check('borrowed_dsp_release_refused', jaxe.fmod_dsp_release(head) === jaxe.ERR_INVALID_PARAM, `result=${jaxe.lastResult}`);
        // A walk from the master can reach a group that dies with any
        // instance, so it is volatile
        const master = jaxe.fmod_cg_get_master();
        const fromMaster = jaxe.fmod_cg_get_group(master, 0);
        check('borrowed_master_walk_volatile', fromMaster > 0
            && jaxe.slots[fromMaster & 0xFFFF].borrowed === jaxe.BORROWED_VOLATILE, `handle=${fromMaster}`);
        // A walk that reaches the master group gets its fixed handle
        const own = jaxe.fmod_cg_create('walk-to-master');
        const up = jaxe.fmod_cg_get_parent_group(own);
        check('borrowed_walk_to_master_fixed', up === master
            && jaxe.slots[master & 0xFFFF].borrowed === jaxe.BORROWED_NONE, `up=${up} master=${master}`);
        jaxe.fmod_cg_release(own);
        jaxe.fmod_evi_stop(inst, 1);
        jaxe.fmod_evi_release(inst);
        check('borrowed_handles_die_with_instance', !jaxe.handleIsLive(group) && !jaxe.handleIsLive(parent)
            && !jaxe.handleIsLive(head), '');
        jaxe.gSystem.flushCommands();
        await pump(3);
        drainEvents();
        check('borrowed_volatile_dies_after_destroy', !jaxe.handleIsLive(fromMaster), `handle=${fromMaster}`);
        const fresh = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(fresh);
        await pump(3);
        const freshGroup = jaxe.fmod_evi_get_channel_group(fresh);
        const freshParent = jaxe.fmod_cg_get_parent_group(freshGroup);
        check('borrowed_fresh_instance_own_handles', freshGroup > 0 && freshParent > 0
            && freshGroup !== group && freshParent !== parent, `old=${group}/${parent} new=${freshGroup}/${freshParent}`);
        jaxe.fmod_evi_stop(fresh, 1);
        jaxe.fmod_evi_release(fresh);

        // A PcmStream's sound reached through its channel refuses release
        // and dies with the stream
        const pcm = jaxe.fmod_core_pcm_create(48000, 1, 9600);
        const pcmChannel = jaxe.fmod_core_pcm_play(pcm, 0, true);
        const pcmSound = jaxe.fmod_chan_get_current_sound(pcmChannel);
        check('borrowed_pcm_sound_release_refused', pcmSound > 0
            && jaxe.fmod_core_release_sound(pcmSound) === jaxe.ERR_INVALID_PARAM, `sound=${pcmSound} result=${jaxe.lastResult}`);
        const sgSound = jaxe.fmod_sg_get_sound(jaxe.fmod_sys_get_master_sound_group(), 0);
        check('borrowed_sound_group_sound_volatile', sgSound > 0
            && jaxe.slots[sgSound & 0xFFFF].borrowed === jaxe.BORROWED_VOLATILE, `sound=${sgSound}`);
        check('borrowed_pcm_release', jaxe.fmod_core_pcm_release(pcm) === 0, `result=${jaxe.lastResult}`);
        check('borrowed_pcm_sound_dies_with_stream', !jaxe.handleIsLive(pcmSound) && !jaxe.handleIsLive(sgSound), '');
        jaxe.fmod_chan_stop(pcmChannel);
        jaxe.gSystem.flushCommands();
        await pump(3);
        drainEvents();
        // The master groups got their slots in the blocks above
        check('borrowed_leaves_no_slots', jaxe.liveCount === borrowLive,
            `live=${jaxe.liveCount} before=${borrowLive}`);
    }

    // Lifetimes that depend on where a walk starts and on which call
    // reached an object first. An event sound's parent was releasable and
    // never died. A nested event's group walked from an instance outlived
    // the group, and another instance's walk handed the stale handle out.
    // A DSP a graph walk reached first stayed volatile when the game
    // fetched it again from its group.
    {
        // The lookups and the master group's head live for the session
        const coinEvd = jaxe.fmod_sys_get_event('event:/SFX/Coin');
        const nestedEvd = jaxe.fmod_sys_get_event('event:/Music/Nested');
        const holdEvd = jaxe.fmod_sys_get_event('event:/SFX/Hold');
        const rootBus = jaxe.fmod_sys_get_bus('bus:/');
        const masterHead = jaxe.fmod_cg_get_dsp(jaxe.fmod_cg_get_master(), -1);
        const walkLive = jaxe.liveCount;
        // Plain objects stand in for wrappers in the table checks below.
        // They carry their own address for the table.
        const realRawPtr = jaxe.rawPtr;
        jaxe.rawPtr = obj => (obj && obj.fakeRaw) ? obj.fakeRaw : realRawPtr(obj);
        const fake = raw => ({ $$: { ptr: raw }, fakeRaw: raw });
        function destroyPoint() {
            const scratch = jaxe.fmod_core_create_sound_pcm(new Uint8Array(800).buffer, 800, 8000, 1);
            jaxe.fmod_core_release_sound(scratch);
        }
        function below(group, out) {
            for (let i = 0; i < jaxe.fmod_cg_get_num_groups(group); i++) {
                const child = jaxe.fmod_cg_get_group(group, i);
                if (child > 0) { out.push(child); below(child, out); }
            }
            return out;
        }
        function firstChannel(group) {
            if (jaxe.fmod_cg_get_num_channels(group) > 0) return jaxe.fmod_cg_get_channel(group, 0);
            for (let i = 0; i < jaxe.fmod_cg_get_num_groups(group); i++) {
                const found = firstChannel(jaxe.fmod_cg_get_group(group, i));
                if (found > 0) return found;
            }
            return 0;
        }

        // The parent of an event's sound refuses release and dies with it
        const coin = jaxe.fmod_evd_create_instance(coinEvd);
        jaxe.fmod_evi_start(coin);
        await pump(5);
        const coinChannel = firstChannel(jaxe.fmod_evi_get_channel_group(coin));
        const coinSound = jaxe.fmod_chan_get_current_sound(coinChannel);
        const bankSound = jaxe.fmod_core_sound_get_sub_sound_parent(coinSound);
        check('subsound_parent_borrowed', bankSound > 0 && jaxe.isOwned(bankSound)
            && jaxe.slots[bankSound & 0xFFFF].parent === coinSound
            && jaxe.slots[bankSound & 0xFFFF].borrowed === jaxe.BORROWED_VOLATILE, `sound=${coinSound} parent=${bankSound}`);
        check('subsound_parent_release_refused', jaxe.fmod_core_release_sound(bankSound) === jaxe.ERR_INVALID_PARAM,
            `result=${jaxe.lastResult}`);
        // Its subsound is the sound it was reached from, which keeps its
        // own link
        const back = jaxe.fmod_core_sound_get_sub_sound(bankSound, 0);
        check('subsound_parent_no_loop', back === coinSound && jaxe.slots[coinSound & 0xFFFF].parent === coinChannel,
            `back=${back} sound=${coinSound}`);
        destroyPoint();
        check('subsound_parent_dies_at_destroy_point', !jaxe.handleIsLive(bankSound) && !jaxe.handleIsLive(coinSound), '');
        jaxe.fmod_evi_stop(coin, 1);
        jaxe.fmod_evi_release(coin);
        jaxe.fmod_chan_stop(coinChannel);

        // A subsound linked under a borrowed parent dies with it
        {
            const host = jaxe.handleAlloc(fake(0x7ff001), jaxe.TYPE_CHAN);
            const parent = jaxe.handleAlloc(fake(0x7ff002), jaxe.TYPE_SOUND);
            const child = jaxe.handleAlloc(fake(0x7ff003), jaxe.TYPE_SOUND);
            jaxe.markOwned(parent);
            jaxe.setOwner(parent, host);
            jaxe.setVolatile(parent);
            jaxe.linkParent(child, parent);
            check('link_parent_sets_kids', jaxe.slots[parent & 0xFFFF].kids === true, '');
            jaxe.freeVolatile();
            check('linked_subsound_dies_with_parent', !jaxe.handleIsLive(parent) && !jaxe.handleIsLive(child)
                && jaxe.handleIsLive(host), '');
            jaxe.handleFree(host);
        }

        // Groups below an instance's own group are volatile and go at the
        // next destroy point. The instance's own group stays linked.
        const nested = jaxe.fmod_evd_create_instance(nestedEvd);
        jaxe.fmod_evi_start(nested);
        await pump(5);
        const nestedGroup = jaxe.fmod_evi_get_channel_group(nested);
        const nestedBelow = below(nestedGroup, []);
        check('walk_below_instance_minted', nestedBelow.length > 0, `below=${nestedBelow.length}`);
        check('walk_below_instance_volatile', nestedBelow.every(h => jaxe.slots[h & 0xFFFF].borrowed === jaxe.BORROWED_VOLATILE),
            nestedBelow.map(h => jaxe.slots[h & 0xFFFF].borrowed).join(','));
        destroyPoint();
        check('walk_below_instance_dies_at_destroy_point', nestedBelow.every(h => !jaxe.handleIsLive(h)), '');
        check('walk_instance_own_group_linked', jaxe.handleIsLive(nestedGroup)
            && jaxe.slots[nestedGroup & 0xFFFF].borrowed === jaxe.BORROWED_LINKED
            && jaxe.fmod_evi_get_channel_group(nested) === nestedGroup, `group=${nestedGroup}`);
        jaxe.fmod_evi_stop(nested, 1);
        jaxe.fmod_evi_release(nested);

        // Two instances feed one group. A walk up from the second never
        // meets the handle the first one's walk minted.
        const holdA = jaxe.fmod_evd_create_instance(holdEvd);
        const holdB = jaxe.fmod_evd_create_instance(holdEvd);
        jaxe.fmod_evi_start(holdA);
        jaxe.fmod_evi_start(holdB);
        await pump(5);
        const groupA = jaxe.fmod_evi_get_channel_group(holdA);
        const upA = jaxe.fmod_cg_get_parent_group(groupA);
        // A walk down from A's side reaches B's group before B hands it out
        const besideA = [];
        for (let i = 0; i < jaxe.fmod_cg_get_num_groups(upA); i++) {
            const g = jaxe.fmod_cg_get_group(upA, i);
            if (g > 0 && g !== groupA) besideA.push(g);
        }
        const groupB = jaxe.fmod_evi_get_channel_group(holdB);
        if (besideA.length === 0) {
            skip('anchor_after_other_walk_fresh_handle', `no sibling group reached: a=${groupA}`);
        } else {
            check('anchor_after_other_walk_fresh_handle', groupB > 0 && besideA.indexOf(groupB) < 0
                && besideA.every(g => !jaxe.handleIsLive(g) || jaxe.slots[g & 0xFFFF].raw !== jaxe.slots[groupB & 0xFFFF].raw),
                `b=${groupB} beside=${besideA}`);
        }
        const upB = jaxe.fmod_cg_get_parent_group(groupB);
        const shared = upA > 0 && upB > 0 && jaxe.slots[upB & 0xFFFF].raw === jaxe.slots[upA & 0xFFFF].raw;
        if (!jaxe.handleIsLive(upA) && upB > 0) {
            check('walk_other_instance_fresh_handle', upB !== upA, `a=${upA} b=${upB}`);
        } else if (shared) {
            check('walk_other_instance_fresh_handle', false, `a=${upA} b=${upB} both live on one group`);
        } else {
            skip('walk_other_instance_fresh_handle', `the instances feed different groups: a=${upA} b=${upB}`);
        }
        // A walk from a bus leaves an instance's own group as it is
        jaxe.fmod_bus_lock_channel_group(rootBus);
        const fromBus = below(jaxe.fmod_bus_get_channel_group(rootBus), []);
        check('walk_from_bus_keeps_instance_group', fromBus.indexOf(groupA) >= 0 && jaxe.handleIsLive(groupA)
            && jaxe.slots[groupA & 0xFFFF].parent === holdA, `group=${groupA} walked=${fromBus}`);
        jaxe.fmod_bus_unlock_channel_group(rootBus);
        jaxe.fmod_evi_stop(holdA, 1);
        jaxe.fmod_evi_release(holdA);
        jaxe.fmod_evi_stop(holdB, 1);
        jaxe.fmod_evi_release(holdB);

        // A DSP a graph walk reached first takes the lifetime of the group
        // the game fetches it from. A later walk leaves it linked.
        const gameGroup = jaxe.fmod_cg_create('walk-order');
        const inputs = [];
        for (let i = 0; i < jaxe.fmod_dsp_get_num_inputs(masterHead); i++) inputs.push(jaxe.fmod_dsp_get_input_dsp(masterHead, i));
        const gameHead = jaxe.fmod_cg_get_dsp(gameGroup, -1);
        if (inputs.indexOf(gameHead) < 0) {
            skip('dsp_adopted_by_group', `the walk did not reach the new group: head=${gameHead} inputs=${inputs}`);
        } else {
            check('dsp_adopted_by_group', jaxe.slots[gameHead & 0xFFFF].parent === gameGroup
                && jaxe.slots[gameHead & 0xFFFF].borrowed === jaxe.BORROWED_LINKED, `head=${gameHead}`);
            destroyPoint();
            const again = [];
            for (let i = 0; i < jaxe.fmod_dsp_get_num_inputs(masterHead); i++) again.push(jaxe.fmod_dsp_get_input_dsp(masterHead, i));
            check('dsp_linked_stays_linked', jaxe.handleIsLive(gameHead) && again.indexOf(gameHead) >= 0
                && jaxe.slots[gameHead & 0xFFFF].borrowed === jaxe.BORROWED_LINKED, '');
        }
        jaxe.fmod_cg_release(gameGroup);
        check('dsp_dies_with_game_group', !jaxe.handleIsLive(gameHead), '');

        // The table rules on plain slots: a linked handle keeps its first
        // owner, and a walked group from another tree counts as foreign
        {
            const ownerA = jaxe.handleAlloc(fake(0x7ff101), jaxe.TYPE_EVI);
            const ownerB = jaxe.handleAlloc(fake(0x7ff102), jaxe.TYPE_EVI);
            const bus = jaxe.handleAlloc(fake(0x7ff103), jaxe.TYPE_BUS);
            const groupOfA = jaxe.handleAlloc(fake(0x7ff104), jaxe.TYPE_CHANGROUP);
            const walkedInA = jaxe.handleAlloc(fake(0x7ff105), jaxe.TYPE_CHANGROUP);
            const dspX = jaxe.handleAlloc(fake(0x7ff106), jaxe.TYPE_DSP);
            for (const h of [groupOfA, walkedInA, dspX]) jaxe.markOwned(h);
            jaxe.setOwner(groupOfA, ownerA);
            jaxe.setOwner(walkedInA, groupOfA);
            jaxe.setVolatile(walkedInA);
            check('walked_elsewhere_rules', jaxe.walkedElsewhere(walkedInA, ownerB) && jaxe.walkedElsewhere(walkedInA, bus)
                && !jaxe.walkedElsewhere(walkedInA, ownerA) && !jaxe.walkedElsewhere(groupOfA, ownerB)
                && !jaxe.walkedElsewhere(walkedInA, 0), '');
            jaxe.setOwner(dspX, groupOfA);
            check('adopt_keeps_first_owner', !jaxe.adopt(dspX, bus) && jaxe.slots[dspX & 0xFFFF].parent === groupOfA, '');
            jaxe.setVolatile(dspX);
            check('adopt_refuses_loop', !jaxe.adopt(groupOfA, walkedInA) && !jaxe.adopt(dspX, dspX), '');
            check('adopt_links_volatile', jaxe.adopt(dspX, bus) && jaxe.slots[dspX & 0xFFFF].parent === bus
                && jaxe.slots[dspX & 0xFFFF].borrowed === jaxe.BORROWED_LINKED, '');
            // The mints apply the rule: a group a walk minted in A's tree
            // is foreign to B's anchored mint and to a walk from B
            const stale = fake(0x7ff105);
            const anchored = jaxe.mintAnchored(stale, ownerB);
            check('mint_anchored_drops_foreign_walk', anchored > 0 && anchored !== walkedInA && !jaxe.handleIsLive(walkedInA)
                && jaxe.slots[anchored & 0xFFFF].parent === ownerB && jaxe.slots[anchored & 0xFFFF].borrowed === jaxe.BORROWED_LINKED, '');
            const walkedInB = jaxe.mintBorrowed(fake(0x7ff107), jaxe.TYPE_CHANGROUP, anchored, true);
            const fromA = jaxe.mintBorrowed(fake(0x7ff107), jaxe.TYPE_CHANGROUP, groupOfA, true);
            check('mint_borrowed_drops_foreign_walk', fromA > 0 && fromA !== walkedInB && !jaxe.handleIsLive(walkedInB)
                && jaxe.slots[fromA & 0xFFFF].parent === groupOfA, `b=${walkedInB} a=${fromA}`);
            const again = jaxe.mintBorrowed(fake(0x7ff107), jaxe.TYPE_CHANGROUP, groupOfA, true);
            check('mint_borrowed_keeps_own_walk', again === fromA, `again=${again}`);
            for (const h of [ownerA, ownerB, bus]) jaxe.handleFree(h);
            check('adopted_dies_with_new_owner', !jaxe.handleIsLive(dspX) && !jaxe.handleIsLive(walkedInA), '');
            check('mint_rules_leave_no_slots', !jaxe.handleIsLive(anchored) && !jaxe.handleIsLive(fromA), '');
        }
        jaxe.rawPtr = realRawPtr;
        jaxe.gSystem.flushCommands();
        await pump(5);
        drainEvents();
        check('walk_lifetimes_leave_no_slots', jaxe.liveCount === walkLive,
            `live=${jaxe.liveCount} before=${walkLive}`);
    }

    // A short-lived handle dies at the next update drain or at the next
    // accepted call that stops, releases, or unloads anything. Linked and
    // game-owned handles live on across drains.
    {
        const coinEvd = jaxe.fmod_sys_get_event('event:/SFX/Coin');
        const rootBus = jaxe.fmod_sys_get_bus('bus:/');
        const masterBank = jaxe.fmod_sys_get_bank('bank:/Master');
        const shortLive = jaxe.liveCount;
        const countOk = () => jaxe.volatileCount === jaxe.slots.filter(s => s.alive && s.borrowed === jaxe.BORROWED_VOLATILE).length;
        const pcm = jaxe.fmod_core_pcm_create(48000, 1, 9600);
        const pcmChannel = jaxe.fmod_core_pcm_play(pcm, 0, true);
        const fresh = () => jaxe.fmod_chan_get_current_sound(pcmChannel);
        const first = fresh();
        const gameGroup = jaxe.fmod_cg_create('short-lived');
        const gameHead = jaxe.fmod_cg_get_dsp(gameGroup, -1);
        check('short_lived_count_tracks_kinds', first > 0 && jaxe.volatileCount === 1 && countOk(),
            `sound=${first} count=${jaxe.volatileCount}`);
        // The auto-update timer calls FMOD's update straight, which leaves
        // them to the drain
        for (let i = 0; i < 2; i++) { jaxe.gSystem.update(); await sleep(15); }
        check('short_lived_survives_until_drain', jaxe.handleIsLive(first), '');
        drainEvents();
        check('short_lived_dies_at_drain', !jaxe.handleIsLive(first) && jaxe.volatileCount === 0, `count=${jaxe.volatileCount}`);
        // fmod_sys_update hands the queue to FMOD, which can free what a
        // stop left before the drain. The handles end there.
        const beforeUpdate = fresh();
        jaxe.fmod_sys_update();
        check('short_lived_dies_at_sys_update', beforeUpdate > 0 && !jaxe.handleIsLive(beforeUpdate) && countOk(), `handle=${beforeUpdate}`);
        check('linked_and_game_survive_drain', jaxe.handleIsLive(gameHead) && jaxe.handleIsLive(gameGroup)
            && jaxe.handleIsLive(pcmChannel) && jaxe.handleIsLive(pcm), '');
        // A handle minted after a drain lives until the next one
        const between = fresh();
        for (let i = 0; i < 2; i++) { jaxe.gSystem.update(); await sleep(15); }
        check('short_lived_lives_between_drains', jaxe.handleIsLive(between), '');
        drainEvents();
        check('short_lived_dies_at_next_drain', !jaxe.handleIsLive(between), '');
        // A refused call keeps it
        const kept = fresh();
        jaxe.fmod_evi_stop(0, 1);
        check('short_lived_survives_refused_stop', jaxe.handleIsLive(kept), '');
        // Each accepted call that stops, releases, or unloads something
        const dropAt = (label, call) => {
            const h = fresh();
            const r = call();
            check(label, h > 0 && r === 0 && !jaxe.handleIsLive(h) && countOk(), `result=${r} handle=${h}`);
        };
        const inst = jaxe.fmod_evd_create_instance(coinEvd);
        jaxe.fmod_evi_start(inst);
        jaxe.gSystem.flushCommands();
        dropAt('short_lived_dies_at_instance_stop', () => jaxe.fmod_evi_stop(inst, 1));
        dropAt('short_lived_dies_at_instance_release', () => jaxe.fmod_evi_release(inst));
        const scratchSound = jaxe.fmod_core_create_sound_pcm(new Uint8Array(800).buffer, 800, 8000, 1);
        const other = jaxe.fmod_core_play_sound(scratchSound, 0, true);
        dropAt('short_lived_dies_at_channel_stop', () => jaxe.fmod_chan_stop(other));
        dropAt('short_lived_dies_at_group_stop', () => jaxe.fmod_cg_stop(gameGroup));
        const sg = jaxe.fmod_sys_create_sound_group('short-lived');
        dropAt('short_lived_dies_at_sound_group_stop', () => jaxe.fmod_sg_stop(sg));
        dropAt('short_lived_dies_at_sound_group_release', () => jaxe.fmod_sg_release(sg));
        dropAt('short_lived_dies_at_bus_stop', () => jaxe.fmod_bus_stop_all_events(rootBus, 1));
        const zone = jaxe.fmod_sys_create_reverb3d();
        dropAt('short_lived_dies_at_reverb_release', () => jaxe.fmod_r3d_release(zone));
        jaxe.fmod_evd_load_sample_data(coinEvd);
        dropAt('short_lived_dies_at_event_sample_unload', () => jaxe.fmod_evd_unload_sample_data(coinEvd));
        jaxe.fmod_bank_load_sample_data(masterBank);
        dropAt('short_lived_dies_at_bank_sample_unload', () => jaxe.fmod_bank_unload_sample_data(masterBank));
        {
            // Both sample unloads return without running the queue. A flush
            // in them held the game thread for two Studio periods per call.
            let flushes = 0;
            const sys = jaxe.gSystem;
            const realFlush = sys.flushCommands;
            const realSampleFlush = sys.flushSampleLoading;
            sys.flushCommands = function () { flushes++; return realFlush.apply(sys, arguments); };
            sys.flushSampleLoading = function () { flushes++; return realSampleFlush.apply(sys, arguments); };
            jaxe.fmod_evd_load_sample_data(coinEvd);
            const eventUnload = jaxe.fmod_evd_unload_sample_data(coinEvd);
            jaxe.fmod_bank_load_sample_data(masterBank);
            const bankUnload = jaxe.fmod_bank_unload_sample_data(masterBank);
            sys.flushCommands = realFlush;
            sys.flushSampleLoading = realSampleFlush;
            check('sample_unload_does_not_flush', eventUnload === 0 && bankUnload === 0 && flushes === 0,
                `event=${eventUnload} bank=${bankUnload} flushes=${flushes}`);
        }
        if (jaxe.fmod_sys_start_command_capture('/short-lived.cmd.txt') === 0) {
            jaxe.gSystem.flushCommands();
            dropAt('short_lived_dies_at_capture_stop', () => jaxe.fmod_sys_stop_command_capture());
            const replay = jaxe.fmod_sys_load_command_replay('/short-lived.cmd.txt');
            jaxe.fmod_replay_start(replay);
            dropAt('short_lived_dies_at_replay_stop', () => jaxe.fmod_replay_stop(replay));
            dropAt('short_lived_dies_at_replay_release', () => jaxe.fmod_replay_release(replay));
            jaxe.FMOD.FS_unlink('/short-lived.cmd.txt');
        } else {
            skip('short_lived_dies_at_capture_stop', `result=${jaxe.lastResult}`);
        }
        // A call that runs the command queue drops them too. A blocking
        // load counts even when FMOD refuses it.
        dropAt('short_lived_dies_at_flush', () => jaxe.fmod_sys_flush_commands());
        dropAt('short_lived_dies_at_sample_loading_flush', () => jaxe.fmod_sys_flush_sample_loading());
        dropAt('short_lived_dies_at_bus_lock', () => jaxe.fmod_bus_lock_channel_group(rootBus));
        jaxe.fmod_bus_unlock_channel_group(rootBus);
        {
            const loadDrop = (label, call, dies) => {
                const h = fresh();
                const bank = call();
                const r = jaxe.lastResult;
                check(label, h > 0 && jaxe.handleIsLive(h) === !dies && countOk(), `result=${r} handle=${h}`);
                if (bank) jaxe.fmod_bank_unload(bank);
            };
            loadDrop('short_lived_dies_at_refused_blocking_load', () => jaxe.fmod_sys_load_bank_file('/NoSuchBank.bank', 0), true);
            loadDrop('short_lived_survives_nonblocking_load', () => jaxe.fmod_sys_load_bank_file('/NoSuchBank.bank', 1), false);
            loadDrop('short_lived_dies_at_refused_memory_load', () => jaxe.fmod_sys_load_bank_memory(new Uint8Array(64).buffer, 64, 0), true);
            loadDrop('short_lived_survives_nonblocking_memory_load', () => jaxe.fmod_sys_load_bank_memory(new Uint8Array(64).buffer, 64, 1), false);
            // The fetched bank of an async load loads blocking once the
            // fetch lands, which drops them between two drains
            const realFetch = global.fetch;
            const strings = fs.readFileSync(path.join(BANKS, 'Master.strings.bank'));
            global.fetch = () => Promise.resolve({ ok: true,
                arrayBuffer: () => Promise.resolve(strings.buffer.slice(strings.byteOffset, strings.byteOffset + strings.length)) });
            const beforeFetch = fresh();
            const placeholder = jaxe.fmod_sys_load_bank_async('assets/Master.strings.bank');
            const liveWhileFetching = jaxe.handleIsLive(beforeFetch);
            await sleep(30);
            global.fetch = realFetch;
            check('short_lived_dies_at_async_load_completion', placeholder > 0 && liveWhileFetching && !jaxe.handleIsLive(beforeFetch) && countOk(),
                `placeholder=${placeholder} whileFetching=${liveWhileFetching}`);
            jaxe.fmod_bank_unload(placeholder);
        }
        // The released programmer sound's drain drops them too. Plain
        // objects stand in for the wrappers.
        const realRawPtr = jaxe.rawPtr;
        jaxe.rawPtr = obj => (obj && obj.fakeRaw) ? obj.fakeRaw : realRawPtr(obj);
        const fake = raw => ({ $$: { ptr: raw }, fakeRaw: raw });
        const recorded = fake(0x7ff201);
        recorded.release = () => 0;
        const recordedHandle = jaxe.handleAlloc(recorded, jaxe.TYPE_SOUND);
        const beforeRelease = fresh();
        jaxe.releaseRecordedObject(recorded, jaxe.TYPE_SOUND, true);
        check('short_lived_dies_at_programmer_sound_release', !jaxe.handleIsLive(recordedHandle) && !jaxe.handleIsLive(beforeRelease), '');
        const beforeKeep = fresh();
        const kept2 = fake(0x7ff202);
        jaxe.handleAlloc(kept2, jaxe.TYPE_DSP);
        jaxe.releaseRecordedObject(kept2, jaxe.TYPE_DSP, false);
        check('short_lived_survives_plugin_record', jaxe.handleIsLive(beforeKeep), '');
        jaxe.rawPtr = realRawPtr;
        jaxe.fmod_chan_stop(pcmChannel);
        jaxe.fmod_core_pcm_release(pcm);
        jaxe.fmod_cg_release(gameGroup);
        jaxe.fmod_core_release_sound(scratchSound);
        await pump(3);
        drainEvents();
        check('short_lived_leave_no_slots', jaxe.liveCount === shortLive && jaxe.volatileCount === 0,
            `live=${jaxe.liveCount} before=${shortLive} volatile=${jaxe.volatileCount}`);
        // With the count at 0 the drop scans nothing. A slot marked behind
        // the helpers' backs shows it.
        {
            const hidden = jaxe.handleAlloc({ $$: { ptr: 0 } }, jaxe.TYPE_CHANGROUP);
            jaxe.slots[hidden & 0xFFFF].borrowed = jaxe.BORROWED_VOLATILE;
            jaxe.freeVolatile();
            check('short_lived_drop_skips_at_zero', jaxe.handleIsLive(hidden), '');
            jaxe.slots[hidden & 0xFFFF].borrowed = jaxe.BORROWED_NONE;
            jaxe.handleFree(hidden);
        }
    }

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

    // A refused instance release keeps the instance's callback state and
    // its group's shim callback, and both still deliver
    {
        const relInst = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(relInst);
        await pump(3);
        check('refused_release_mask_installed', jaxe.fmod_evi_set_callback_mask(relInst, 0x22) === 0, '');
        const relGroup = jaxe.fmod_evi_get_channel_group(relInst);
        check('refused_release_group_callback_installed', jaxe.fmod_cg_set_callback(relGroup, true) === 0, '');
        const relGroupW = jaxe.resolveCg(relGroup);
        const relGroupRaw = jaxe.rawPtr(relGroupW);
        const relCalls = [];
        const realRelGroupSet = relGroupW.setCallback;
        relGroupW.setCallback = function (cb) {
            relCalls.push(cb === null ? 'off' : 'on');
            return realRelGroupSet.call(relGroupW, cb);
        };
        const relW = jaxe.handleResolve(relInst, jaxe.TYPE_EVI);
        const realRelRelease = relW.release;
        relW.release = () => 40;
        const refusedRel = jaxe.fmod_evi_release(relInst);
        relW.release = realRelRelease;
        relGroupW.setCallback = realRelGroupSet;
        check('refused_instance_release_reports', refusedRel === 40, `result=${refusedRel}`);
        check('refused_instance_release_keeps_slot', jaxe.handleResolve(relInst, jaxe.TYPE_EVI) != null, '');
        check('refused_instance_release_keeps_mask', jaxe.cbMasks[relInst] === 0x22, `mask=${jaxe.cbMasks[relInst]}`);
        check('refused_instance_release_cycles_group_callback',
            relCalls.join(',') === 'off,on' && jaxe.chanCallbackHandles.get(relGroupRaw) === relGroup,
            `calls=${relCalls.join(',')}`);
        jaxe.fmod_evi_stop(relInst, 1);
        let sawRelStop = false;
        for (let i = 0; i < 100 && !sawRelStop; i++) {
            await pump(1);
            for (const ev of drainEvents()) if (ev.handle === relInst && ev.type === 0x20) sawRelStop = true;
        }
        check('refused_instance_release_callback_still_delivers', sawRelStop, '');
        jaxe.fmod_cg_set_callback(relGroup, false);
        jaxe.fmod_evi_release(relInst);
        await pump(3);
        drainEvents();
    }

    // A successful unload whose scope was unknown puts every survivor's
    // callbacks back: the instance mask and the group's shim callback
    {
        const extrasBytes = fs.readFileSync(path.join(BANKS, 'Extras.bank'));
        const extrasBuf = extrasBytes.buffer.slice(extrasBytes.byteOffset, extrasBytes.byteOffset + extrasBytes.length);
        const extras = jaxe.fmod_sys_load_bank_memory(extrasBuf, extrasBytes.length, 0);
        check('survivor_extras_bank_loaded', extras > 0, `handle=${extras}`);
        const survInst = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(survInst);
        await pump(3);
        check('survivor_mask_installed', jaxe.fmod_evi_set_callback_mask(survInst, 0x22) === 0, '');
        const survGroup = jaxe.fmod_evi_get_channel_group(survInst);
        check('survivor_group_callback_installed', jaxe.fmod_cg_set_callback(survGroup, true) === 0, '');
        const survGroupW = jaxe.resolveCg(survGroup);
        const survGroupRaw = jaxe.rawPtr(survGroupW);
        const survCalls = [];
        const realSurvSet = survGroupW.setCallback;
        survGroupW.setCallback = function (cb) {
            survCalls.push(cb === null ? 'off' : 'on');
            return realSurvSet.call(survGroupW, cb);
        };
        const extrasW = jaxe.handleResolve(extras, jaxe.TYPE_BANK);
        const realExtrasCount = extrasW.getEventCount;
        const realExtrasList = extrasW.getEventList;
        extrasW.getEventCount = function (o) { o.val = 1; return jaxe.FMOD.OK; };
        extrasW.getEventList = () => 40;
        const okUnload = jaxe.fmod_bank_unload(extras);
        extrasW.getEventCount = realExtrasCount;
        extrasW.getEventList = realExtrasList;
        survGroupW.setCallback = realSurvSet;
        check('unlisted_bank_unload_succeeds', okUnload === 0, `result=${okUnload}`);
        check('unlisted_unload_restores_survivor_mask', jaxe.cbMasks[survInst] === 0x22, `mask=${jaxe.cbMasks[survInst]}`);
        check('unlisted_unload_restores_survivor_group_callback',
            survCalls.join(',') === 'off,on' && jaxe.chanCallbackHandles.get(survGroupRaw) === survGroup,
            `calls=${survCalls.join(',')} mapped=${jaxe.chanCallbackHandles.get(survGroupRaw)}`);
        jaxe.fmod_evi_stop(survInst, 1);
        let sawSurvStop = false;
        for (let i = 0; i < 100 && !sawSurvStop; i++) {
            await pump(1);
            for (const ev of drainEvents()) if (ev.handle === survInst && ev.type === 0x20) sawSurvStop = true;
        }
        check('unlisted_unload_survivor_callback_still_delivers', sawSurvStop, '');
        jaxe.fmod_cg_set_callback(survGroup, false);
        jaxe.fmod_evi_release(survInst);
        await pump(3);
        drainEvents();
    }

    // A restore skips a group its instance does not own, so a new group
    // at a recycled address never inherits the old callback
    {
        const ownInst = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(ownInst);
        const otherInst = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(otherInst);
        await pump(3);
        const ownGroup = jaxe.fmod_evi_get_channel_group(ownInst);
        const otherGroup = jaxe.fmod_evi_get_channel_group(otherInst);
        check('ownership_groups_differ', ownGroup > 0 && otherGroup > 0 && ownGroup !== otherGroup,
            `own=${ownGroup} other=${otherGroup}`);
        check('ownership_group_callback_installed', jaxe.fmod_cg_set_callback(ownGroup, true) === 0, '');
        const ownGroupW = jaxe.resolveCg(ownGroup);
        const ownRaw = jaxe.rawPtr(ownGroupW);
        const taken = jaxe.uninstallInstanceGroupCallbacks(null);
        check('ownership_uninstall_took_the_group',
            taken.length === 1 && taken[0].raw === ownRaw && taken[0].inst === ownInst
            && !jaxe.chanCallbackHandles.has(ownRaw),
            `taken=${taken.length} inst=${taken.length ? taken[0].inst : 0} own=${ownInst}`);
        // The instance answers with another event's group here, as it
        // would after FMOD destroyed its own and handed the address on
        const ownW = jaxe.handleResolve(ownInst, jaxe.TYPE_EVI);
        const otherW = jaxe.handleResolve(otherInst, jaxe.TYPE_EVI);
        const realOwnGet = ownW.getChannelGroup;
        ownW.getChannelGroup = o => otherW.getChannelGroup(o);
        const restoreCalls = [];
        const realOwnSet = ownGroupW.setCallback;
        ownGroupW.setCallback = function (cb) {
            restoreCalls.push(cb === null ? 'off' : 'on');
            return realOwnSet.call(ownGroupW, cb);
        };
        jaxe.restoreInstanceGroupCallbacks(taken);
        ownGroupW.setCallback = realOwnSet;
        ownW.getChannelGroup = realOwnGet;
        check('restore_skips_a_group_the_instance_no_longer_owns',
            restoreCalls.length === 0 && !jaxe.chanCallbackHandles.has(ownRaw),
            `calls=${restoreCalls.join(',')} mapped=${jaxe.chanCallbackHandles.get(ownRaw)}`);
        // The same restore puts the callback back once the instance owns
        // the group again
        jaxe.restoreInstanceGroupCallbacks(taken);
        check('restore_reinstalls_a_group_the_instance_still_owns',
            jaxe.chanCallbackHandles.get(ownRaw) === ownGroup,
            `mapped=${jaxe.chanCallbackHandles.get(ownRaw)}`);
        jaxe.fmod_cg_set_callback(ownGroup, false);
        jaxe.fmod_evi_stop(ownInst, 1);
        jaxe.fmod_evi_stop(otherInst, 1);
        jaxe.fmod_evi_release(ownInst);
        jaxe.fmod_evi_release(otherInst);
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

    // The bank file load hands FMOD every flag bit the game passed
    {
        const realLoad = jaxe.gSystem.loadBankFile;
        let seenFlags = -1;
        jaxe.gSystem.loadBankFile = function (path, flags, out) { seenFlags = flags; return realLoad.call(this, path, flags, out); };
        jaxe.fmod_sys_load_bank_file('/NoSuchBank.bank', 6);
        jaxe.gSystem.loadBankFile = realLoad;
        check('load_bank_file_passes_every_flag', seenFlags === 6, `flags=${seenFlags}`);
    }
    // A command replay loads the banks its capture loaded and unloads them
    // at its stop, with no call through the shim. The BANK_UNLOAD record
    // that unload raises sweeps the lookup handles into the bank.
    {
        drainEvents();
        const capturePath = '/replay-bank.cmd';
        const captured = jaxe.fmod_sys_start_command_capture(capturePath, 0);
        const extras = jaxe.fmod_sys_load_bank_file('/Extras.bank', 0);
        // The strings bank can be gone by now, so the lookup goes by GUID
        const bankId = '{2e34b84a-be93-4215-87db-9f769538a3a9}';
        await pump(2);
        jaxe.fmod_sys_stop_command_capture();
        jaxe.fmod_bank_unload(extras);
        await pump(2);
        drainEvents();
        check('replay_capture_loads_bank', captured === 0 && extras > 0, `capture=${captured} bank=${extras}`);
        const replay = jaxe.fmod_sys_load_command_replay(capturePath, 0);
        check('replay_bank_replay_starts', replay > 0 && jaxe.fmod_replay_start(replay) === 0, `replay=${replay} result=${jaxe.lastResult}`);
        let replayBank = 0;
        for (let i = 0; i < 50 && replayBank === 0; i++) {
            await pump(1);
            drainEvents();
            replayBank = jaxe.fmod_sys_get_bank_by_id(bankId);
        }
        const ibuf = new Array(1024).fill(0);
        const eventCount = replayBank > 0 ? jaxe.fmod_bank_get_event_list(replayBank, ibuf) : 0;
        const events = ibuf.slice(0, eventCount);
        check('replay_bank_loaded_by_replay', replayBank > 0 && eventCount > 0, `bank=${replayBank} events=${eventCount}`);
        jaxe.fmod_replay_stop(replay);
        for (let i = 0; i < 10; i++) { await pump(1); drainEvents(); }
        const staleEvents = events.filter(h => jaxe.fmod_debug_handle_is_live(h) && !jaxe.fmod_evd_is_valid(h)).length;
        const deadEvents = events.filter(h => !jaxe.fmod_debug_handle_is_live(h)).length;
        check('replay_bank_unload_sweeps_lookups', jaxe.fmod_sys_get_bank_by_id(bankId) === 0 && !jaxe.fmod_debug_handle_is_live(replayBank)
            && staleEvents === 0 && deadEvents > 0, `bankLive=${jaxe.fmod_debug_handle_is_live(replayBank)} stale=${staleEvents} dead=${deadEvents}`);
        jaxe.fmod_replay_release(replay);
    }
    console.log(`LIFECYCLE_TEST: failures = ${fails}`);
    console.log(fails === 0 ? 'LIFECYCLE_TEST: COMPLETE' : 'LIFECYCLE_TEST: FAILED');
    process.exit(fails === 0 ? 0 : 1);
}

main().catch(e => { console.log('HARNESS ERROR', e); process.exit(1); });
