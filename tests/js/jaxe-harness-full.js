// Loads the real jaxe.js shim under Node with browser stubs and runs the
// ApiProbeState sequence against the real FMOD 2.03.12 wasm, extended to
// cover the full domain-prefixed binding surface (sys_/bank_/evd_/evi_/vca_).
// Usage: node harness.js


// --- Browser stubs (jaxe.js expects window/document. FS preload uses XHR paths) ---
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
global.window = {
    location: { pathname: '/game/index.html' },
    setInterval: setInterval,
    clearInterval: clearInterval,
};
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js')); // non-logging build

// jaxe.js is a plain script defining `class jaxe { ... }` - evaluate it here
const src = fs.readFileSync(JAXE, 'utf8');
eval(src + '\nglobal.jaxe = jaxe;');

// Emscripten FS preload needs real URLs. in node, redirect the bank fetch to
// local files by overriding preRun to write banks straight into MEMFS.
jaxe.preRun = function () {
    for (const name of ['Master.bank', 'Master.strings.bank']) {
        const bytes = fs.readFileSync(path.join(BANKS, name));
        jaxe.FMOD.FS_createDataFile('/', name, bytes, true, false, false);
    }
};

// Node-safe replacement for jaxe.onRuntimeInitialized: same sequence but
// NOSOUND output (no AudioContext in node) and no driver-info query.
jaxe.onRuntimeInitialized = function () {
    try {
        var outval = {};
        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;
        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;
        jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
        jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
        var b = {};
        jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
        jaxe.loadedBanks['Master.bank'] = b.val;
        jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
        jaxe.loadedBanks['Master.strings.bank'] = b.val;
        jaxe.FmodIsInitialized = true;
    } catch (e) {
        console.log('INIT THREW:', e.message);
        process.exit(1);
    }
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, fn) {
    try {
        const r = fn();
        console.log(`JAXE_TEST: ${label} -> ${r}`);
        return r;
    } catch (e) {
        console.log(`JAXE_TEST: ${label} -> THREW ${e.constructor.name}: ${e.message}`);
        failures++;
        process.exitCode = 1;
        return null;
    }
}
// check + assert on the returned value
function expect(label, fn, pred) {
    const r = check(label, fn);
    if (!pred(r)) {
        console.log(`JAXE_TEST: FAIL ${label}: unexpected value ${JSON.stringify(r)}`);
        failures++;
        process.exitCode = 1;
    }
    return r;
}
function near(a, b) { return Math.abs(a - b) < 1e-4; }
const GUID_RE = /^\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}$/;
const BAD = 999999; // never-allocated handle

async function pump(n) {
    for (let i = 0; i < n; i++) { jaxe.fmod_update(); await new Promise(r => setTimeout(r, 10)); }
}

async function main() {
    // Mirror fmod_init but keep the module promise so failures surface
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    jaxe.FMOD['TOTAL_MEMORY'] = 64 * 1024 * 1024;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED:', e); process.exit(1); });
    // wait for FmodIsInitialized (onRuntimeInitialized sets it)
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('JAXE_TEST: INIT TIMEOUT'); process.exit(1); }
    console.log('JAXE_TEST: initialized');

    // --- ApiProbeState sequence (bus surface) ---
    const h = check('sys_get_bus', () => jaxe.fmod_sys_get_bus('bus:/'));
    check('bus_is_valid', () => jaxe.fmod_bus_is_valid(h));
    check('bus_get_path', () => jaxe.fmod_bus_get_path(h));
    check('bus_get_id', () => jaxe.fmod_bus_get_id(h));
    check('bus_set_volume', () => jaxe.fmod_bus_set_volume(h, 0.5));
    check('bus_get_volume', () => jaxe.fmod_bus_get_volume(h));
    check('bus_get_final_volume', () => jaxe.fmod_bus_get_final_volume(h));
    check('bus_set_paused', () => jaxe.fmod_bus_set_paused(h, true));
    check('bus_get_paused', () => jaxe.fmod_bus_get_paused(h));
    check('bus_set_paused(false)', () => jaxe.fmod_bus_set_paused(h, false));
    check('bus_set_mute', () => jaxe.fmod_bus_set_mute(h, true));
    check('bus_get_mute', () => jaxe.fmod_bus_get_mute(h));
    check('bus_set_mute(false)', () => jaxe.fmod_bus_set_mute(h, false));
    check('bus_stop_all_events', () => jaxe.fmod_bus_stop_all_events(h, 1));
    const cpu = [0, 0];
    check('bus_get_cpu_usage (expect 68 unsupported)', () => jaxe.fmod_bus_get_cpu_usage(h, cpu));
    const mem = [0, 0, 0];
    check('bus_get_memory_usage (expect 68 unsupported)', () => jaxe.fmod_bus_get_memory_usage(h, mem));
    check('debug_live_handle_count', () => jaxe.fmod_debug_live_handle_count());

    // --- Callback round trip (cb-test equivalent) ---
    const evi = check('create_instance', () => jaxe.fmod_create_instance('event:/Music/MainLevel'));
    check('evi_set_callback_mask', () => jaxe.fmod_evi_set_callback_mask(evi, 0x7FFFF));
    check('start', () => { jaxe.fmod_start(evi); return 'ok'; });
    for (let i = 0; i < 30; i++) { jaxe.fmod_update(); await new Promise(r => setTimeout(r, 20)); }
    check('stop allowfadeout', () => { jaxe.fmod_stop(evi, 0); return 'ok'; });
    let sawStopped = false, events = 0;
    for (let i = 0; i < 400 && !sawStopped; i++) {
        jaxe.fmod_update();
        while (jaxe.fmod_cb_next()) {
            events++;
            const type = jaxe.fmod_cb_type();
            if (type === 0x20) sawStopped = true;
            console.log(`JAXE_TEST: cb event type=0x${type.toString(16)} handle=${jaxe.fmod_cb_handle()}`);
        }
        if (i % 40 === 0) {
            console.log(`JAXE_TEST: playbackState at i=${i}: ${jaxe.fmod_get_playback_state(evi)} timeline=${jaxe.fmod_get_timeline_position(evi)}`);
        }
        await new Promise(r => setTimeout(r, 10));
    }
    console.log(`JAXE_TEST: Stopped received=${sawStopped} totalEvents=${events}`);
    if (!sawStopped) { failures++; process.exitCode = 1; }

    // ================= M3 surface =================
    const fbuf = new Array(64).fill(0);
    const ibuf = new Array(64).fill(0);

    // --- Studio System: handle dedupe across lookups ---
    expect('sys_get_bus dedupe', () => jaxe.fmod_sys_get_bus('bus:/'), r => r === h);
    const busId = check('bus_get_id for by-id lookup', () => jaxe.fmod_bus_get_id(h));
    expect('sys_get_bus_by_id dedupe', () => jaxe.fmod_sys_get_bus_by_id(busId), r => r === h);
    expect('sys_get_bus_by_id malformed', () => jaxe.fmod_sys_get_bus_by_id('nonsense'), r => r === 0);
    expect('  lastResult == 31', () => jaxe.fmod_sys_last_result(), r => r === 31);

    const evd = expect('sys_get_event', () => jaxe.fmod_sys_get_event('event:/Music/MainLevel'), r => r > 0);
    expect('sys_get_event dedupe', () => jaxe.fmod_sys_get_event('event:/Music/MainLevel'), r => r === evd);
    expect('sys_get_event missing', () => jaxe.fmod_sys_get_event('event:/Nope'), r => r === 0);
    expect('  lastResult == 74', () => jaxe.fmod_sys_last_result(), r => r === 74);

    const evdId = expect('evd_get_id', () => jaxe.fmod_evd_get_id(evd), r => GUID_RE.test(r));
    expect('sys_get_event_by_id dedupe', () => jaxe.fmod_sys_get_event_by_id(evdId), r => r === evd);
    expect('sys_lookup_id', () => jaxe.fmod_sys_lookup_id('event:/Music/MainLevel'), r => r === evdId);
    expect('sys_lookup_path round trip', () => jaxe.fmod_sys_lookup_path(evdId), r => r === 'event:/Music/MainLevel');
    expect('sys_lookup_path malformed', () => jaxe.fmod_sys_lookup_path('{zz}'), r => r === '');
    expect('  lastResult == 31', () => jaxe.fmod_sys_last_result(), r => r === 31);
    expect('sys_lookup_id missing', () => jaxe.fmod_sys_lookup_id('event:/Nope'), r => r === '');

    const bank = expect('sys_get_bank', () => jaxe.fmod_sys_get_bank('bank:/Master'), r => r > 0);
    expect('sys_get_bank dedupe', () => jaxe.fmod_sys_get_bank('bank:/Master'), r => r === bank);
    const bankId = expect('bank_get_id', () => jaxe.fmod_bank_get_id(bank), r => GUID_RE.test(r));
    expect('sys_get_bank_by_id dedupe', () => jaxe.fmod_sys_get_bank_by_id(bankId), r => r === bank);
    expect('sys_get_bank_count', () => jaxe.fmod_sys_get_bank_count(), r => r === 2);
    expect('sys_get_bank_list', () => jaxe.fmod_sys_get_bank_list(ibuf), r => r === 2 && ibuf.slice(0, 2).includes(bank));

    // --- global parameters (bank has none: error paths must be clean) ---
    expect('sys_get_parameter_description_count', () => jaxe.fmod_sys_get_parameter_description_count(), r => r === 0);
    expect('sys_get_param_by_name missing', () => jaxe.fmod_sys_get_param_by_name('nope'), r => r === 0);
    expect('  lastResult nonzero', () => jaxe.fmod_sys_last_result(), r => r !== 0);
    expect('sys_get_param_by_name_final missing', () => jaxe.fmod_sys_get_param_by_name_final('nope'), r => r === 0);
    expect('sys_set_param_by_name missing', () => jaxe.fmod_sys_set_param_by_name('nope', 1.0, false), r => r !== 0);
    expect('sys_set_param_by_name_with_label missing', () => jaxe.fmod_sys_set_param_by_name_with_label('nope', 'x', false), r => r !== 0);
    expect('sys_get_param_by_id missing', () => jaxe.fmod_sys_get_param_by_id(1, 2), r => r === 0);
    expect('sys_get_param_by_id_final missing', () => jaxe.fmod_sys_get_param_by_id_final(1, 2), r => r === 0);
    expect('sys_set_param_by_id missing', () => jaxe.fmod_sys_set_param_by_id(1, 2, 0.5, false), r => r !== 0);
    expect('sys_set_param_by_id_with_label missing', () => jaxe.fmod_sys_set_param_by_id_with_label(1, 2, 'x', false), r => r !== 0);
    expect('sys_get_parameter_description_by_index bad', () => jaxe.fmod_sys_get_parameter_description_by_index(0, fbuf, ibuf), r => r === '');
    expect('sys_get_parameter_description_by_name bad', () => jaxe.fmod_sys_get_parameter_description_by_name('nope', fbuf, ibuf), r => r === '');
    expect('sys_get_parameter_label bad', () => jaxe.fmod_sys_get_parameter_label('nope', 0), r => r === '');

    // --- listeners ---
    expect('sys_get_num_listeners', () => jaxe.fmod_sys_get_num_listeners(), r => r === 1);
    expect('sys_set_num_listeners', () => jaxe.fmod_sys_set_num_listeners(1), r => r === 0);
    expect('sys_set_listener_attributes', () => jaxe.fmod_sys_set_listener_attributes(0, [1, 2, 3, 0, 0, 0, 0, 0, 1, 0, 1, 0]), r => r === 0);
    expect('sys_get_listener_attributes', () => jaxe.fmod_sys_get_listener_attributes(0, fbuf),
        r => r === 0 && near(fbuf[0], 1) && near(fbuf[1], 2) && near(fbuf[2], 3) && near(fbuf[8], 1) && near(fbuf[10], 1));
    expect('sys_get_listener_weight', () => jaxe.fmod_sys_get_listener_weight(0), r => near(r, 1));
    expect('sys_set_listener_weight', () => jaxe.fmod_sys_set_listener_weight(0, 0.5), r => r === 0);
    expect('sys_get_listener_weight after set', () => jaxe.fmod_sys_get_listener_weight(0), r => near(r, 0.5));
    check('restore listener weight', () => jaxe.fmod_sys_set_listener_weight(0, 1.0));

    // --- profiling / flush ---
    expect('sys_flush_commands', () => jaxe.fmod_sys_flush_commands(), r => r === 0);
    expect('sys_flush_sample_loading', () => jaxe.fmod_sys_flush_sample_loading(), r => r === 0);
    fbuf.fill(-1);
    expect('sys_get_cpu_usage', () => jaxe.fmod_sys_get_cpu_usage(fbuf), r => r === 0 && fbuf[0] >= 0 && fbuf[6] >= 0);
    console.log('JAXE_TEST:   cpu fbuf[0..6] =', fbuf.slice(0, 7).map(v => v.toFixed(3)).join(','));
    ibuf.fill(-1); fbuf.fill(-1);
    expect('sys_get_buffer_usage', () => jaxe.fmod_sys_get_buffer_usage(ibuf, fbuf),
        r => r === 0 && ibuf[2] > 0 && ibuf[6] > 0 && fbuf[0] >= 0 && fbuf[1] >= 0);
    console.log('JAXE_TEST:   buffer ibuf[0..7] =', ibuf.slice(0, 8).join(','), 'fbuf[0..1] =', fbuf.slice(0, 2).join(','));
    expect('sys_reset_buffer_usage', () => jaxe.fmod_sys_reset_buffer_usage(), r => r === 0);
    expect('sys_get_memory_usage (expect 68 unsupported)', () => jaxe.fmod_sys_get_memory_usage(ibuf), r => r === 68);

    // --- VCA (bank has none: lookup misses + invalid-handle paths) ---
    expect('sys_get_vca missing', () => jaxe.fmod_sys_get_vca('vca:/Nope'), r => r === 0);
    expect('  lastResult == 74', () => jaxe.fmod_sys_last_result(), r => r === 74);
    expect('sys_get_vca_by_id missing', () => jaxe.fmod_sys_get_vca_by_id(evdId), r => r === 0);
    expect('sys_get_vca_by_id malformed', () => jaxe.fmod_sys_get_vca_by_id('bad'), r => r === 0);
    expect('vca_is_valid invalid', () => jaxe.fmod_vca_is_valid(BAD), r => r === false);
    expect('vca_get_id invalid', () => jaxe.fmod_vca_get_id(BAD), r => r === '');
    expect('  lastResult == 30', () => jaxe.fmod_sys_last_result(), r => r === 30);
    expect('vca_get_path invalid', () => jaxe.fmod_vca_get_path(BAD), r => r === '');
    expect('vca_get_volume invalid', () => jaxe.fmod_vca_get_volume(BAD), r => r === 0);
    expect('vca_get_final_volume invalid', () => jaxe.fmod_vca_get_final_volume(BAD), r => r === 0);
    expect('vca_set_volume invalid', () => jaxe.fmod_vca_set_volume(BAD, 0.5), r => r === 30);

    // --- Bank surface ---
    expect('bank_is_valid', () => jaxe.fmod_bank_is_valid(bank), r => r === true);
    expect('bank_get_path', () => jaxe.fmod_bank_get_path(bank), r => r === 'bank:/Master');
    expect('bank_get_loading_state', () => jaxe.fmod_bank_get_loading_state(bank), r => r === 3);
    expect('bank_load_sample_data', () => jaxe.fmod_bank_load_sample_data(bank), r => r === 0);
    check('flush sample loading', () => jaxe.fmod_sys_flush_sample_loading());
    await pump(5);
    expect('bank_get_sample_loading_state', () => jaxe.fmod_bank_get_sample_loading_state(bank), r => r === 3);
    expect('bank_unload_sample_data', () => jaxe.fmod_bank_unload_sample_data(bank), r => r === 0);
    expect('bank_get_event_count', () => jaxe.fmod_bank_get_event_count(bank), r => r === 3);
    const nEvents = expect('bank_get_event_list', () => jaxe.fmod_bank_get_event_list(bank, ibuf), r => r === 3);
    const eventHandles = ibuf.slice(0, nEvents);
    let sawMainLevel = false;
    for (const eh of eventHandles) {
        const p = check(`evd_get_path(${eh})`, () => jaxe.fmod_evd_get_path(eh));
        if (p === 'event:/Music/MainLevel') {
            sawMainLevel = true;
            expect('event list dedupe vs sys_get_event', () => eh, r => r === evd);
        }
    }
    if (!sawMainLevel) { console.log('JAXE_TEST: FAIL MainLevel not in event list'); failures++; process.exitCode = 1; }
    expect('bank_get_bus_count', () => jaxe.fmod_bank_get_bus_count(bank), r => r === 2);
    const nBuses = expect('bank_get_bus_list', () => jaxe.fmod_bank_get_bus_list(bank, ibuf), r => r === 2);
    expect('bus list dedupe vs sys_get_bus', () => ibuf.slice(0, nBuses).includes(h), r => r === true);
    expect('bank_get_vca_count', () => jaxe.fmod_bank_get_vca_count(bank), r => r === 0);
    expect('bank_get_vca_list', () => jaxe.fmod_bank_get_vca_list(bank, ibuf), r => r === 0);

    const stringsBank = expect('sys_get_bank strings', () => jaxe.fmod_sys_get_bank('bank:/Master.strings'), r => r > 0);
    const nStrings = expect('bank_get_string_count', () => jaxe.fmod_bank_get_string_count(stringsBank), r => r > 0);
    for (let i = 0; i < Math.min(nStrings, 3); i++) {
        expect(`bank_get_string_info(${i})`, () => jaxe.fmod_bank_get_string_info(stringsBank, i), r => typeof r === 'string' && r.length > 0);
        expect(`bank_get_string_guid(${i})`, () => jaxe.fmod_bank_get_string_guid(stringsBank, i), r => GUID_RE.test(r));
    }
    expect('bank_get_string_info bad index', () => jaxe.fmod_bank_get_string_info(stringsBank, 9999), r => r === '');
    expect('  lastResult nonzero', () => jaxe.fmod_sys_last_result(), r => r !== 0);

    // invalid bank handle sweep
    expect('bank_is_valid invalid', () => jaxe.fmod_bank_is_valid(BAD), r => r === false);
    expect('bank_get_id invalid', () => jaxe.fmod_bank_get_id(BAD), r => r === '');
    expect('bank_get_path invalid', () => jaxe.fmod_bank_get_path(BAD), r => r === '');
    expect('bank_unload invalid', () => jaxe.fmod_bank_unload(BAD), r => r === 30);
    expect('bank_load_sample_data invalid', () => jaxe.fmod_bank_load_sample_data(BAD), r => r === 30);
    expect('bank_unload_sample_data invalid', () => jaxe.fmod_bank_unload_sample_data(BAD), r => r === 30);
    expect('bank_get_loading_state invalid', () => jaxe.fmod_bank_get_loading_state(BAD), r => r === 1);
    expect('bank_get_sample_loading_state invalid', () => jaxe.fmod_bank_get_sample_loading_state(BAD), r => r === 1);
    expect('bank_get_event_count invalid', () => jaxe.fmod_bank_get_event_count(BAD), r => r === 0);
    expect('bank_get_event_list invalid', () => jaxe.fmod_bank_get_event_list(BAD, ibuf), r => r === 0);
    expect('bank_get_bus_count invalid', () => jaxe.fmod_bank_get_bus_count(BAD), r => r === 0);
    expect('bank_get_bus_list invalid', () => jaxe.fmod_bank_get_bus_list(BAD, ibuf), r => r === 0);
    expect('bank_get_vca_count invalid', () => jaxe.fmod_bank_get_vca_count(BAD), r => r === 0);
    expect('bank_get_vca_list invalid', () => jaxe.fmod_bank_get_vca_list(BAD, ibuf), r => r === 0);
    expect('bank_get_string_count invalid', () => jaxe.fmod_bank_get_string_count(BAD), r => r === 0);
    expect('bank_get_string_info invalid', () => jaxe.fmod_bank_get_string_info(BAD, 0), r => r === '');
    expect('bank_get_string_guid invalid', () => jaxe.fmod_bank_get_string_guid(BAD, 0), r => r === '');

    // --- EventDescription surface (MainLevel) ---
    expect('evd_is_valid', () => jaxe.fmod_evd_is_valid(evd), r => r === true);
    expect('evd_get_path', () => jaxe.fmod_evd_get_path(evd), r => r === 'event:/Music/MainLevel');
    expect('evd_get_length', () => jaxe.fmod_evd_get_length(evd), r => r === 124800);
    fbuf.fill(-1);
    expect('evd_get_min_max_distance', () => jaxe.fmod_evd_get_min_max_distance(evd, fbuf), r => r === 0 && fbuf[0] >= 0 && fbuf[1] >= 0);
    expect('evd_get_sound_size', () => jaxe.fmod_evd_get_sound_size(evd), r => r >= 0);
    expect('evd_is_snapshot', () => jaxe.fmod_evd_is_snapshot(evd), r => r === false);
    expect('evd_is_oneshot', () => jaxe.fmod_evd_is_oneshot(evd), r => r === false);
    expect('evd_is_stream', () => jaxe.fmod_evd_is_stream(evd), r => r === true);
    expect('evd_is_3d', () => jaxe.fmod_evd_is_3d(evd), r => r === false);
    expect('evd_is_doppler_enabled', () => jaxe.fmod_evd_is_doppler_enabled(evd), r => r === false);
    expect('evd_has_sustain_point', () => jaxe.fmod_evd_has_sustain_point(evd), r => r === false);
    expect('evd_load_sample_data', () => jaxe.fmod_evd_load_sample_data(evd), r => r === 0);
    check('flush sample loading', () => jaxe.fmod_sys_flush_sample_loading());
    await pump(5);
    expect('evd_get_sample_loading_state', () => jaxe.fmod_evd_get_sample_loading_state(evd), r => r === 3);
    expect('evd_unload_sample_data', () => jaxe.fmod_evd_unload_sample_data(evd), r => r === 0);

    // parameter descriptions
    const pCount = expect('evd_get_parameter_description_count', () => jaxe.fmod_evd_get_parameter_description_count(evd), r => r === 2);
    fbuf.fill(-1); ibuf.fill(-1);
    for (let i = 1; i < pCount; i++) {
        const n = check(`evd_get_parameter_description_by_index(${i})`, () => jaxe.fmod_evd_get_parameter_description_by_index(evd, i, fbuf, ibuf));
        console.log(`JAXE_TEST:   param[${i}] "${n}" min=${fbuf[0]} max=${fbuf[1]} def=${fbuf[2]} type=${ibuf[0]} flags=${ibuf[1]} id=(${ibuf[2]},${ibuf[3]})`);
    }
    fbuf.fill(-1); ibuf.fill(-1);
    const pName = expect('evd_get_parameter_description_by_index', () => jaxe.fmod_evd_get_parameter_description_by_index(evd, 0, fbuf, ibuf),
        r => typeof r === 'string' && r.length > 0);
    console.log(`JAXE_TEST:   param "${pName}" min=${fbuf[0]} max=${fbuf[1]} def=${fbuf[2]} type=${ibuf[0]} flags=${ibuf[1]} id=(${ibuf[2]},${ibuf[3]})`);
    const pid1 = ibuf[2], pid2 = ibuf[3];
    fbuf.fill(-1); ibuf.fill(-1);
    expect('evd_get_parameter_description_by_name', () => jaxe.fmod_evd_get_parameter_description_by_name(evd, pName, fbuf, ibuf),
        r => r === pName && ibuf[2] === pid1 && ibuf[3] === pid2);
    expect('evd_get_parameter_description_by_index bad', () => jaxe.fmod_evd_get_parameter_description_by_index(evd, 99, fbuf, ibuf), r => r === '');
    expect('evd_get_parameter_label (param has none)', () => jaxe.fmod_evd_get_parameter_label(evd, pName, 0), r => r === '');
    expect('evd_get_user_property_count', () => jaxe.fmod_evd_get_user_property_count(evd), r => r === 0);
    expect('evd_get_user_property_name bad index', () => jaxe.fmod_evd_get_user_property_name(evd, 0), r => r === '');
    expect('evd_get_user_property_type bad index', () => jaxe.fmod_evd_get_user_property_type(evd, 0), r => r === 0);
    expect('evd_get_user_property_float bad index', () => jaxe.fmod_evd_get_user_property_float(evd, 0), r => r === 0);
    expect('evd_get_user_property_string bad index', () => jaxe.fmod_evd_get_user_property_string(evd, 0), r => r === '');

    // invalid evd handle sweep
    expect('evd_is_valid invalid', () => jaxe.fmod_evd_is_valid(BAD), r => r === false);
    expect('evd_get_id invalid', () => jaxe.fmod_evd_get_id(BAD), r => r === '');
    expect('evd_get_path invalid', () => jaxe.fmod_evd_get_path(BAD), r => r === '');
    expect('evd_get_length invalid', () => jaxe.fmod_evd_get_length(BAD), r => r === 0);
    expect('evd_get_min_max_distance invalid', () => jaxe.fmod_evd_get_min_max_distance(BAD, fbuf), r => r === 30);
    expect('evd_get_sound_size invalid', () => jaxe.fmod_evd_get_sound_size(BAD), r => r === 0);
    expect('evd_is_snapshot invalid', () => jaxe.fmod_evd_is_snapshot(BAD), r => r === false);
    expect('evd_is_oneshot invalid', () => jaxe.fmod_evd_is_oneshot(BAD), r => r === false);
    expect('evd_is_stream invalid', () => jaxe.fmod_evd_is_stream(BAD), r => r === false);
    expect('evd_is_3d invalid', () => jaxe.fmod_evd_is_3d(BAD), r => r === false);
    expect('evd_is_doppler_enabled invalid', () => jaxe.fmod_evd_is_doppler_enabled(BAD), r => r === false);
    expect('evd_has_sustain_point invalid', () => jaxe.fmod_evd_has_sustain_point(BAD), r => r === false);
    expect('evd_create_instance invalid', () => jaxe.fmod_evd_create_instance(BAD), r => r === 0);
    expect('evd_get_instance_count invalid', () => jaxe.fmod_evd_get_instance_count(BAD), r => r === 0);
    expect('evd_get_instance_list invalid', () => jaxe.fmod_evd_get_instance_list(BAD, ibuf), r => r === 0);
    expect('evd_release_all_instances invalid', () => jaxe.fmod_evd_release_all_instances(BAD), r => r === 30);
    expect('evd_load_sample_data invalid', () => jaxe.fmod_evd_load_sample_data(BAD), r => r === 30);
    expect('evd_unload_sample_data invalid', () => jaxe.fmod_evd_unload_sample_data(BAD), r => r === 30);
    expect('evd_get_sample_loading_state invalid', () => jaxe.fmod_evd_get_sample_loading_state(BAD), r => r === 1);
    expect('evd_get_parameter_description_count invalid', () => jaxe.fmod_evd_get_parameter_description_count(BAD), r => r === 0);
    expect('evd_get_parameter_description_by_index invalid', () => jaxe.fmod_evd_get_parameter_description_by_index(BAD, 0, fbuf, ibuf), r => r === '');
    expect('evd_get_parameter_description_by_name invalid', () => jaxe.fmod_evd_get_parameter_description_by_name(BAD, 'x', fbuf, ibuf), r => r === '');
    expect('evd_get_parameter_label invalid', () => jaxe.fmod_evd_get_parameter_label(BAD, 'x', 0), r => r === '');
    expect('evd_get_user_property_count invalid', () => jaxe.fmod_evd_get_user_property_count(BAD), r => r === 0);
    expect('evd_get_user_property_name invalid', () => jaxe.fmod_evd_get_user_property_name(BAD, 0), r => r === '');
    expect('evd_get_user_property_type invalid', () => jaxe.fmod_evd_get_user_property_type(BAD, 0), r => r === 0);
    expect('evd_get_user_property_float invalid', () => jaxe.fmod_evd_get_user_property_float(BAD, 0), r => r === 0);
    expect('evd_get_user_property_string invalid', () => jaxe.fmod_evd_get_user_property_string(BAD, 0), r => r === '');

    // --- EventInstance surface ---
    // legacy instance `evi` (never released) must still be tracked
    const inst = expect('evd_create_instance', () => jaxe.fmod_evd_create_instance(evd), r => r > 0);
    expect('evd_get_instance_count', () => jaxe.fmod_evd_get_instance_count(evd), r => r === 2);
    const nInst = expect('evd_get_instance_list', () => jaxe.fmod_evd_get_instance_list(evd, ibuf), r => r === 2);
    const instList = ibuf.slice(0, nInst);
    expect('instance list dedupe (new evi)', () => instList.includes(inst), r => r === true);
    expect('instance list dedupe (legacy evi)', () => instList.includes(evi), r => r === true);
    expect('evi_get_description dedupe', () => jaxe.fmod_evi_get_description(inst), r => r === evd);

    expect('evi_is_valid', () => jaxe.fmod_evi_is_valid(inst), r => r === true);
    expect('evi_set_volume', () => jaxe.fmod_evi_set_volume(inst, 0.5), r => r === 0);
    expect('evi_get_volume', () => jaxe.fmod_evi_get_volume(inst), r => near(r, 0.5));
    expect('evi_get_volume_final', () => jaxe.fmod_evi_get_volume_final(inst), r => typeof r === 'number');
    expect('evi_set_pitch', () => jaxe.fmod_evi_set_pitch(inst, 1.25), r => r === 0);
    expect('evi_get_pitch', () => jaxe.fmod_evi_get_pitch(inst), r => near(r, 1.25));
    expect('evi_get_pitch_final', () => jaxe.fmod_evi_get_pitch_final(inst), r => typeof r === 'number');
    check('restore pitch', () => jaxe.fmod_evi_set_pitch(inst, 1.0));
    expect('evi_set_paused', () => jaxe.fmod_evi_set_paused(inst, true), r => r === 0);
    expect('evi_get_paused', () => jaxe.fmod_evi_get_paused(inst), r => r === true);
    expect('evi_set_paused(false)', () => jaxe.fmod_evi_set_paused(inst, false), r => r === 0);
    expect('evi_start', () => jaxe.fmod_evi_start(inst), r => r === 0);
    await pump(10);
    expect('evi_get_playback_state playing', () => jaxe.fmod_evi_get_playback_state(inst), r => r === 0);
    expect('evi_set_timeline_position', () => jaxe.fmod_evi_set_timeline_position(inst, 5000), r => r === 0);
    await pump(10);
    expect('evi_get_timeline_position', () => jaxe.fmod_evi_get_timeline_position(inst), r => r >= 5000);
    expect('evi_is_virtual', () => jaxe.fmod_evi_is_virtual(inst), r => typeof r === 'boolean');
    fbuf.fill(-1);
    expect('evi_get_min_max_distance', () => jaxe.fmod_evi_get_min_max_distance(inst, fbuf), r => r === 0 && fbuf[0] >= 0);
    expect('evi_set_3d_attributes', () => jaxe.fmod_evi_set_3d_attributes(inst, [1, 2, 3, 4, 5, 6, 0, 0, 1, 0, 1, 0]), r => r === 0);
    fbuf.fill(-1);
    expect('evi_get_3d_attributes round trip', () => jaxe.fmod_evi_get_3d_attributes(inst, fbuf),
        r => r === 0 && near(fbuf[0], 1) && near(fbuf[1], 2) && near(fbuf[2], 3)
            && near(fbuf[3], 4) && near(fbuf[4], 5) && near(fbuf[5], 6)
            && near(fbuf[8], 1) && near(fbuf[10], 1));
    const mask = expect('evi_get_listener_mask', () => jaxe.fmod_evi_get_listener_mask(inst), r => typeof r === 'number');
    expect('evi_set_listener_mask', () => jaxe.fmod_evi_set_listener_mask(inst, 1), r => r === 0);
    expect('evi_get_listener_mask after set', () => jaxe.fmod_evi_get_listener_mask(inst), r => r === 1);
    check('restore listener mask', () => jaxe.fmod_evi_set_listener_mask(inst, mask));
    expect('evi_get_property default', () => jaxe.fmod_evi_get_property(inst, 0), r => typeof r === 'number');
    expect('evi_set_property', () => jaxe.fmod_evi_set_property(inst, 0, 5.0), r => r === 0);
    expect('evi_get_property after set', () => jaxe.fmod_evi_get_property(inst, 0), r => near(r, 5.0));
    expect('evi_get_reverb_level', () => jaxe.fmod_evi_get_reverb_level(inst, 0), r => near(r, 0));
    expect('evi_set_reverb_level', () => jaxe.fmod_evi_set_reverb_level(inst, 0, 0.5), r => r === 0);
    expect('evi_get_reverb_level after set', () => jaxe.fmod_evi_get_reverb_level(inst, 0), r => near(r, 0.5));

    // parameters on the instance (uses the discovered param + its id)
    expect('evi_set_param_by_name', () => jaxe.fmod_evi_set_param_by_name(inst, pName, 0.7, true), r => r === 0);
    expect('evi_get_param_by_name', () => jaxe.fmod_evi_get_param_by_name(inst, pName), r => near(r, 0.7));
    await pump(5);
    expect('evi_get_param_by_name_final', () => jaxe.fmod_evi_get_param_by_name_final(inst, pName), r => near(r, 0.7));
    expect('evi_set_param_by_id', () => jaxe.fmod_evi_set_param_by_id(inst, pid1, pid2, 0.3, true), r => r === 0);
    expect('evi_get_param_by_id', () => jaxe.fmod_evi_get_param_by_id(inst, pid1, pid2), r => near(r, 0.3));
    await pump(5);
    expect('evi_get_param_by_id_final', () => jaxe.fmod_evi_get_param_by_id_final(inst, pid1, pid2), r => near(r, 0.3));
    expect('evi_set_param_by_name_with_label (no labels)', () => jaxe.fmod_evi_set_param_by_name_with_label(inst, pName, 'x', false), r => r !== 0);
    expect('evi_set_param_by_id_with_label (no labels)', () => jaxe.fmod_evi_set_param_by_id_with_label(inst, pid1, pid2, 'x', false), r => r !== 0);
    expect('evi_get_param_by_name missing', () => jaxe.fmod_evi_get_param_by_name(inst, 'nope'), r => r === 0);
    expect('  lastResult nonzero', () => jaxe.fmod_sys_last_result(), r => r !== 0);

    // profiling on instances is not exposed by the JS API
    expect('evi_get_cpu_usage (expect 68 unsupported)', () => jaxe.fmod_evi_get_cpu_usage(inst, ibuf), r => r === 68);
    expect('evi_get_memory_usage (expect 68 unsupported)', () => jaxe.fmod_evi_get_memory_usage(inst, ibuf), r => r === 68);

    expect('evi_key_off (no sustain point)', () => jaxe.fmod_evi_key_off(inst), r => typeof r === 'number');
    expect('evi_stop immediate', () => jaxe.fmod_evi_stop(inst, 1), r => r === 0);
    const liveBefore = jaxe.fmod_debug_live_handle_count();
    expect('evi_release', () => jaxe.fmod_evi_release(inst), r => r === 0);
    expect('handle freed on release', () => jaxe.fmod_debug_live_handle_count(), r => r === liveBefore - 1);
    expect('evi_is_valid after release', () => jaxe.fmod_evi_is_valid(inst), r => r === false);
    expect('evi_start stale handle', () => jaxe.fmod_evi_start(inst), r => r === 30);

    // invalid evi handle sweep
    expect('evi_get_description invalid', () => jaxe.fmod_evi_get_description(BAD), r => r === 0);
    expect('evi_start invalid', () => jaxe.fmod_evi_start(BAD), r => r === 30);
    expect('evi_stop invalid', () => jaxe.fmod_evi_stop(BAD, 0), r => r === 30);
    expect('evi_key_off invalid', () => jaxe.fmod_evi_key_off(BAD), r => r === 30);
    expect('evi_release invalid', () => jaxe.fmod_evi_release(BAD), r => r === 30);
    expect('evi_get_playback_state invalid', () => jaxe.fmod_evi_get_playback_state(BAD), r => r === 2);
    expect('evi_get_paused invalid', () => jaxe.fmod_evi_get_paused(BAD), r => r === false);
    expect('evi_set_paused invalid', () => jaxe.fmod_evi_set_paused(BAD, true), r => r === 30);
    expect('evi_get_volume invalid', () => jaxe.fmod_evi_get_volume(BAD), r => r === 0);
    expect('evi_get_volume_final invalid', () => jaxe.fmod_evi_get_volume_final(BAD), r => r === 0);
    expect('evi_set_volume invalid', () => jaxe.fmod_evi_set_volume(BAD, 1), r => r === 30);
    expect('evi_get_pitch invalid', () => jaxe.fmod_evi_get_pitch(BAD), r => r === 0);
    expect('evi_get_pitch_final invalid', () => jaxe.fmod_evi_get_pitch_final(BAD), r => r === 0);
    expect('evi_set_pitch invalid', () => jaxe.fmod_evi_set_pitch(BAD, 1), r => r === 30);
    expect('evi_get_timeline_position invalid', () => jaxe.fmod_evi_get_timeline_position(BAD), r => r === 0);
    expect('evi_set_timeline_position invalid', () => jaxe.fmod_evi_set_timeline_position(BAD, 0), r => r === 30);
    expect('evi_is_virtual invalid', () => jaxe.fmod_evi_is_virtual(BAD), r => r === false);
    expect('evi_get_min_max_distance invalid', () => jaxe.fmod_evi_get_min_max_distance(BAD, fbuf), r => r === 30);
    expect('evi_get_3d_attributes invalid', () => jaxe.fmod_evi_get_3d_attributes(BAD, fbuf), r => r === 30);
    expect('evi_set_3d_attributes invalid', () => jaxe.fmod_evi_set_3d_attributes(BAD, [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0]), r => r === 30);
    expect('evi_get_listener_mask invalid', () => jaxe.fmod_evi_get_listener_mask(BAD), r => r === 0);
    expect('evi_set_listener_mask invalid', () => jaxe.fmod_evi_set_listener_mask(BAD, 1), r => r === 30);
    expect('evi_get_property invalid', () => jaxe.fmod_evi_get_property(BAD, 0), r => r === 0);
    expect('evi_set_property invalid', () => jaxe.fmod_evi_set_property(BAD, 0, 0), r => r === 30);
    expect('evi_get_reverb_level invalid', () => jaxe.fmod_evi_get_reverb_level(BAD, 0), r => r === 0);
    expect('evi_set_reverb_level invalid', () => jaxe.fmod_evi_set_reverb_level(BAD, 0, 0), r => r === 30);
    expect('evi_get_param_by_name invalid', () => jaxe.fmod_evi_get_param_by_name(BAD, 'x'), r => r === 0);
    expect('evi_get_param_by_name_final invalid', () => jaxe.fmod_evi_get_param_by_name_final(BAD, 'x'), r => r === 0);
    expect('evi_set_param_by_name invalid', () => jaxe.fmod_evi_set_param_by_name(BAD, 'x', 0, false), r => r === 30);
    expect('evi_set_param_by_name_with_label invalid', () => jaxe.fmod_evi_set_param_by_name_with_label(BAD, 'x', 'y', false), r => r === 30);
    expect('evi_get_param_by_id invalid', () => jaxe.fmod_evi_get_param_by_id(BAD, 1, 2), r => r === 0);
    expect('evi_get_param_by_id_final invalid', () => jaxe.fmod_evi_get_param_by_id_final(BAD, 1, 2), r => r === 0);
    expect('evi_set_param_by_id invalid', () => jaxe.fmod_evi_set_param_by_id(BAD, 1, 2, 0, false), r => r === 30);
    expect('evi_set_param_by_id_with_label invalid', () => jaxe.fmod_evi_set_param_by_id_with_label(BAD, 1, 2, 'x', false), r => r === 30);
    expect('evi_get_cpu_usage invalid', () => jaxe.fmod_evi_get_cpu_usage(BAD, ibuf), r => r === 30);
    expect('evi_get_memory_usage invalid', () => jaxe.fmod_evi_get_memory_usage(BAD, ibuf), r => r === 30);

    // --- releaseAllInstances (legacy `evi` is the only one left) ---
    expect('evd_release_all_instances', () => jaxe.fmod_evd_release_all_instances(evd), r => r === 0);
    await pump(5);
    // released-but-tracked handles must degrade cleanly, not crash
    check('evi_get_playback_state on released-out instance', () => jaxe.fmod_evi_get_playback_state(evi));
    check('legacy fmod_release to drop stale handle', () => { jaxe.fmod_release(evi); return 'ok'; });

    // --- bank unload / reload via the domain-prefixed API ---
    expect('bank_unload', () => jaxe.fmod_bank_unload(bank), r => r === 0);
    expect('bank_is_valid after unload', () => jaxe.fmod_bank_is_valid(bank), r => r === false);
    await pump(5);
    expect('sys_get_bank after unload', () => jaxe.fmod_sys_get_bank('bank:/Master'), r => r === 0);
    const bank2 = expect('sys_load_bank_file blocking', () => jaxe.fmod_sys_load_bank_file('Master.bank', 0), r => r > 0);
    expect('loading state after blocking load', () => jaxe.fmod_bank_get_loading_state(bank2), r => r === 3);
    expect('event count after reload', () => jaxe.fmod_bank_get_event_count(bank2), r => r === 3);
    expect('bank_unload again', () => jaxe.fmod_bank_unload(bank2), r => r === 0);
    await pump(5);
    const bank3 = expect('sys_load_bank_file nonblocking', () => jaxe.fmod_sys_load_bank_file('Master.bank', 1), r => r > 0);
    let state = -1;
    for (let i = 0; i < 100; i++) {
        state = jaxe.fmod_bank_get_loading_state(bank3);
        if (state === 3) break;
        await pump(2);
    }
    expect('nonblocking load reaches LOADED', () => state, r => r === 3);
    expect('event count after nonblocking reload', () => jaxe.fmod_bank_get_event_count(bank3), r => r === 3);
    expect('sys_load_bank_file already loaded', () => jaxe.fmod_sys_load_bank_file('Master.bank', 0), r => r === 0);
    expect('  lastResult == 70 already loaded', () => jaxe.fmod_sys_last_result(), r => r === 70);

    // --- async HTTP bank load (fetch is faked. node never hits the network) ---
    const prevFetch = global.fetch;
    const prevAsyncTimeout = jaxe.ASYNC_FETCH_TIMEOUT_MS;
    const bankBytes = fs.readFileSync(path.join(BANKS, 'Master.bank'));
    const bankArrayBuffer = bankBytes.buffer.slice(bankBytes.byteOffset, bankBytes.byteOffset + bankBytes.byteLength);

    // success path: fake fetch serves the bank bytes after a short delay
    expect('bank_unload before async load', () => jaxe.fmod_bank_unload(bank3), r => r === 0);
    await pump(5);
    global.fetch = () => new Promise(resolve => setTimeout(() => resolve({
        ok: true,
        arrayBuffer: () => Promise.resolve(bankArrayBuffer),
    }), 20));
    const abank = expect('sys_load_bank_async', () => jaxe.fmod_sys_load_bank_async('Master.bank'), r => r > 0);
    expect('async loading state pending', () => jaxe.fmod_bank_get_loading_state(abank), r => r === 2);
    let astate = -1;
    for (let i = 0; i < 100; i++) {
        astate = jaxe.fmod_bank_get_loading_state(abank);
        if (astate === 3) break;
        await pump(2);
    }
    expect('async load reaches LOADED', () => astate, r => r === 3);
    expect('event count after async load', () => jaxe.fmod_bank_get_event_count(abank), r => r === 3);

    // timeout: never-settling fetch (rejects on abort like the real one)
    // must flip the placeholder to ERROR once ASYNC_FETCH_TIMEOUT_MS passes
    jaxe.ASYNC_FETCH_TIMEOUT_MS = 100;
    global.fetch = (url, opts) => new Promise((resolve, reject) => {
        if (opts && opts.signal) opts.signal.addEventListener('abort', () => reject(new Error('aborted')));
    });
    const tbank = expect('sys_load_bank_async hung fetch', () => jaxe.fmod_sys_load_bank_async('Hung.bank'), r => r > 0);
    let tstate = -1;
    for (let i = 0; i < 100; i++) {
        tstate = jaxe.fmod_bank_get_loading_state(tbank);
        if (tstate === 4) break;
        await new Promise(r => setTimeout(r, 10));
    }
    expect('hung fetch times out to ERROR', () => tstate, r => r === 4);
    expect('bank_unload timed-out placeholder', () => jaxe.fmod_bank_unload(tbank), r => r === 0);

    // unload-while-pending: cancels the fetch and frees the handle
    const liveBeforePending = jaxe.fmod_debug_live_handle_count();
    const pbank = expect('sys_load_bank_async pending', () => jaxe.fmod_sys_load_bank_async('Pending.bank'), r => r > 0);
    expect('live handle count while pending', () => jaxe.fmod_debug_live_handle_count(), r => r === liveBeforePending + 1);
    expect('bank_unload while pending', () => jaxe.fmod_bank_unload(pbank), r => r === 0);
    expect('bank_is_valid after pending unload', () => jaxe.fmod_bank_is_valid(pbank), r => r === false);
    expect('handleResolve null after pending unload', () => jaxe.handleResolve(pbank, jaxe.TYPE_BANK), r => r === null);
    expect('live handle count restored', () => jaxe.fmod_debug_live_handle_count(), r => r === liveBeforePending);

    // late completion after unload: this fake ignores the abort signal (a
    // response already in flight when abort lands), so the fetch resolves
    // 200ms after the unload - the cancelled flag must drop the bank
    let lateResolve = null;
    global.fetch = () => new Promise(resolve => { lateResolve = resolve; });
    const lbank = expect('sys_load_bank_async late completion', () => jaxe.fmod_sys_load_bank_async('Late.bank'), r => r > 0);
    expect('bank_unload before late completion', () => jaxe.fmod_bank_unload(lbank), r => r === 0);
    const banksBeforeLate = jaxe.fmod_sys_get_bank_count();
    await new Promise(r => setTimeout(r, 200));
    lateResolve({ ok: true, arrayBuffer: () => Promise.resolve(bankArrayBuffer) });
    await pump(10);
    expect('bank count unchanged after late completion', () => jaxe.fmod_sys_get_bank_count(), r => r === banksBeforeLate);

    jaxe.ASYNC_FETCH_TIMEOUT_MS = prevAsyncTimeout;
    global.fetch = prevFetch;

    // --- sys_unload_all last (invalidates everything) ---
    expect('sys_unload_all', () => jaxe.fmod_sys_unload_all(), r => r === 0);
    await pump(5);
    expect('sys_get_bank_count after unload_all', () => jaxe.fmod_sys_get_bank_count(), r => r === 0);

    console.log(`JAXE_TEST: live handles at end = ${jaxe.fmod_debug_live_handle_count()}`);
    console.log(`JAXE_TEST: failures = ${failures}`);
    console.log('JAXE_TEST: COMPLETE' + (process.exitCode ? ' (WITH FAILURES)' : ''));
    process.exit(process.exitCode || 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
