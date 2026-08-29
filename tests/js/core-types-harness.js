// Runs the core type bindings of jaxe.js against the real FMOD 2.03.12
// wasm under Node: the packed FMOD_CREATESOUNDEXINFO on the memory create,
// sync point handles as sorted indices, loop points with a unit per end,
// the system ERROR mask (accepted, never raised by the web build), and
// the second string slot of the callback queue.
// Usage: node core-types-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`CORETYPES_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
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
    if (!jaxe.FmodIsInitialized) { console.log('CORETYPES_TEST: INIT TIMEOUT'); process.exit(1); }
}

// The exinfo slots as Sound.packExInfo lays them out
function exinfo(fields) {
    const ibuf = new Array(20).fill(0);
    const order = ['length', 'fileoffset', 'numchannels', 'defaultfrequency', 'format', 'decodebuffersize',
        'initialsubsound', 'numsubsounds', 'maxpolyphony', 'suggestedsoundtype', 'minmidigranularity',
        'nonblockthreadid', 'filebuffersize', 'channelorder', 'initialsoundgroup', 'initialseekposition',
        'initialseekpostype', 'ignoresetfilesystem', 'audioqueuepolicy'];
    order.forEach((name, i) => { if (fields[name] !== undefined) ibuf[i] = fields[name]; });
    const list = fields.inclusionlist || [];
    ibuf[19] = list.length;
    for (const entry of list) ibuf.push(entry);
    return ibuf;
}

async function main() {
    await waitForInit();
    const F = jaxe.FMOD;
    const baseline = jaxe.fmod_debug_live_handle_count();
    const frames = 4800;
    const pcm = new ArrayBuffer(frames * 2);

    // Raw PCM through the memory create with a packed exinfo
    const group = jaxe.fmod_sys_create_sound_group('exinfo');
    check('exinfo_group', group !== 0, `result=${jaxe.lastResult}`);
    const raw = jaxe.fmod_core_create_sound_memory_ex(pcm, pcm.byteLength, F.OPENRAW >>> 0,
        exinfo({ numchannels: 1, defaultfrequency: 48000, format: F.SOUND_FORMAT_PCM16, initialsoundgroup: group }), '', '', '');
    check('exinfo_memory_raw', raw !== 0, `handle=${raw} result=${jaxe.lastResult}`);
    check('exinfo_memory_length', jaxe.fmod_core_get_sound_length(raw, F.TIMEUNIT_PCM) === frames,
        `pcm=${jaxe.fmod_core_get_sound_length(raw, F.TIMEUNIT_PCM)}`);
    const format = [];
    jaxe.fmod_sound_get_format(raw, format);
    check('exinfo_memory_format', format[1] === F.SOUND_FORMAT_PCM16 && format[2] === 1, `format=${format[1]} channels=${format[2]}`);
    check('exinfo_initial_sound_group', jaxe.fmod_sound_get_sound_group(raw) === group,
        `group=${group} got=${jaxe.fmod_sound_get_sound_group(raw)}`);
    const badGuid = jaxe.fmod_core_create_sound_memory_ex(pcm, pcm.byteLength, F.OPENRAW >>> 0,
        exinfo({ numchannels: 1, defaultfrequency: 48000, format: F.SOUND_FORMAT_PCM16 }), '', '', 'not-a-guid');
    check('exinfo_bad_guid', badGuid === 0 && jaxe.lastResult === F.ERR_INVALID_PARAM, `handle=${badGuid} result=${jaxe.lastResult}`);
    const shortBuf = jaxe.fmod_core_create_sound_memory_ex(pcm, pcm.byteLength, F.OPENRAW >>> 0, [1, 2, 3], '', '', '');
    check('exinfo_short_ibuf', shortBuf === 0 && jaxe.lastResult === F.ERR_INVALID_PARAM, `result=${jaxe.lastResult}`);
    const goodGuid = jaxe.fmod_core_create_sound_memory_ex(pcm, pcm.byteLength, F.OPENRAW >>> 0,
        exinfo({ numchannels: 1, defaultfrequency: 48000, format: F.SOUND_FORMAT_PCM16 }), '', '', '{0225c47b-e69f-4785-b89c-fd321387934a}');
    check('exinfo_guid_parses', goodGuid !== 0, `handle=${goodGuid} result=${jaxe.lastResult}`);
    check('exinfo_path_uninitialized_args', jaxe.fmod_core_create_sound_ex(42, 0, exinfo({}), '', '', '') === 0
        && jaxe.lastResult === F.ERR_INVALID_PARAM, `result=${jaxe.lastResult}`);
    jaxe.fmod_core_release_sound(goodGuid);
    jaxe.fmod_core_release_sound(raw);
    jaxe.fmod_sg_release(group);

    // Sync point handles: indices in offset order, so an earlier point
    // pushes the later ones up
    const snd = jaxe.fmod_core_create_sound_pcm(pcm, pcm.byteLength, 48000, 1);
    check('sound_create', snd !== 0, `handle=${snd} result=${jaxe.lastResult}`);
    const a = jaxe.fmod_sound_add_sync_point(snd, 30, F.TIMEUNIT_MS, 'a');
    const b = jaxe.fmod_sound_add_sync_point(snd, 10, F.TIMEUNIT_MS, 'b');
    const c = jaxe.fmod_sound_add_sync_point(snd, 20, F.TIMEUNIT_MS, 'c');
    check('sync_add_indices', a === 0 && b === 0 && c === 1, `a=${a} b=${b} c=${c}`);
    const names = [0, 1, 2].map(i => jaxe.fmod_sound_get_sync_point_name(snd, i));
    check('sync_sorted_names', names.join(',') === 'b,c,a', `names=${names.join(',')}`);
    check('sync_offset_unit', jaxe.fmod_sound_get_sync_point_offset(snd, 1, F.TIMEUNIT_PCM) === 960,
        `pcm=${jaxe.fmod_sound_get_sync_point_offset(snd, 1, F.TIMEUNIT_PCM)}`);
    check('sync_out_of_range', jaxe.fmod_sound_get_sync_point_offset(snd, 3, F.TIMEUNIT_MS) === -1
        && jaxe.lastResult === F.ERR_INVALID_PARAM, `result=${jaxe.lastResult}`);
    check('sync_add_bad_handle', jaxe.fmod_sound_add_sync_point(0, 1, F.TIMEUNIT_MS, 'x') === -1
        && jaxe.lastResult === F.ERR_INVALID_HANDLE, `result=${jaxe.lastResult}`);
    check('sync_add_bad_name', jaxe.fmod_sound_add_sync_point(snd, 1, F.TIMEUNIT_MS, 7) === -1
        && jaxe.lastResult === F.ERR_INVALID_PARAM, `result=${jaxe.lastResult}`);
    check('sync_delete_shifts', jaxe.fmod_sound_delete_sync_point(snd, 0) === F.OK
        && jaxe.fmod_sound_get_num_sync_points(snd) === 2 && jaxe.fmod_sound_get_sync_point_name(snd, 0) === 'c', '');

    // Loop points with a unit per end
    jaxe.fmod_sound_set_mode(snd, F.LOOP_NORMAL >>> 0);
    check('loop_points_mixed_set', jaxe.fmod_sound_set_loop_points(snd, 480, F.TIMEUNIT_PCM, 50, F.TIMEUNIT_MS) === F.OK, `result=${jaxe.lastResult}`);
    const mixed = [];
    jaxe.fmod_sound_get_loop_points(snd, F.TIMEUNIT_MS, F.TIMEUNIT_PCM, mixed);
    check('loop_points_mixed_get', mixed[0] === 10 && mixed[1] === 2400, `start=${mixed[0]} end=${mixed[1]}`);
    const ch = jaxe.fmod_core_play_sound(snd, 0, true);
    check('chan_play', ch !== 0, `handle=${ch}`);
    check('chan_loop_points_mixed_set', jaxe.fmod_chan_set_loop_points(ch, 20, F.TIMEUNIT_MS, 1920, F.TIMEUNIT_PCM) === F.OK, `result=${jaxe.lastResult}`);
    const chMs = [];
    jaxe.fmod_chan_get_loop_points(ch, F.TIMEUNIT_MS, F.TIMEUNIT_MS, chMs);
    check('chan_loop_points_mixed_get', chMs[0] === 20 && chMs[1] === 40, `start=${chMs[0]} end=${chMs[1]}`);
    jaxe.fmod_chan_stop(ch);

    // The ERROR mask is accepted but the web build never raises it
    check('error_mask_accepted', jaxe.fmod_sys_set_callback_mask(0x80 | 0x1 | 0x2) === F.OK, `result=${jaxe.lastResult}`);
    jaxe.fmod_sound_get_sync_point_offset(snd, 99, F.TIMEUNIT_MS);
    jaxe.gSystemCore.update();
    let errorRecords = 0;
    let otherRecords = 0;
    while (jaxe.fmod_cb_next()) {
        if (jaxe.fmod_cb_type() === (0x20000000 | 0x80)) errorRecords++; else otherRecords++;
    }
    check('error_web_silent', errorRecords === 0, `errors=${errorRecords} others=${otherRecords}`);
    check('error_mask_cleared', jaxe.fmod_sys_set_callback_mask(0) === F.OK, `result=${jaxe.lastResult}`);

    // The encoder path of the shim, fed the record the native side would
    // see, lands in the two string slots
    jaxe.systemCallback(null, 0x80, { result: 31, instancetype: 5, functionname: 'Sound::getSyncPoint', functionparams: '(0x1, 99)' }, null, null);
    check('error_record_queued', jaxe.fmod_cb_next() && jaxe.fmod_cb_type() === (0x20000000 | 0x80), `type=${jaxe.fmod_cb_type()}`);
    check('error_record_fields', jaxe.fmod_cb_int(0) === 31 && jaxe.fmod_cb_int(1) === 5 && jaxe.fmod_cb_int(2) === 0
        && jaxe.fmod_cb_string() === 'Sound::getSyncPoint' && jaxe.fmod_cb_string2() === '(0x1, 99)',
        `i1=${jaxe.fmod_cb_int(0)} i2=${jaxe.fmod_cb_int(1)} str=${jaxe.fmod_cb_string()} str2=${jaxe.fmod_cb_string2()}`);
    check('error_queue_drained', !jaxe.fmod_cb_next(), '');
    jaxe.systemCallback(null, 0x1, null, null, null);
    check('plain_record_empty_str2', jaxe.fmod_cb_next() && jaxe.fmod_cb_string2() === '', `str2=${jaxe.fmod_cb_string2()}`);
    while (jaxe.fmod_cb_next()) {}

    jaxe.fmod_core_release_sound(snd);
    check('no_handle_leaks', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(failures === 0 ? 'CORETYPES_TEST: COMPLETE' : `CORETYPES_TEST: FAILED (${failures})`);
    process.exit(failures === 0 ? 0 : 1);
}

main().catch(e => { console.log('CORETYPES_TEST: THREW', e && e.stack || e); process.exit(1); });
