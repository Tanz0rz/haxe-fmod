// Runs the Studio API parity bindings of jaxe.js against the real FMOD
// 2.03.12 wasm under Node: capture and replay flags, the replay cursor in
// seconds, bank loading from memory with flags, the listener attenuation
// position, the parameter description GUID on every reader, the sound
// info fields for an audio table key, and the callback drain turning a
// plugin DSP into a handle and carrying the nested beat's event GUID.
// Usage: node studio-parity-harness.js  (needs FMOD_SDK_WEB)

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
    jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    var b = {};
    jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, cond, detail) {
    console.log(`STUDIO_PARITY_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('STUDIO_PARITY_TEST: INIT TIMEOUT'); process.exit(1); }

    // Lookup handles are cached for the session, so the description is
    // taken before the baseline
    const jump = jaxe.fmod_sys_get_event('event:/SFX/Jump');
    const baseline = jaxe.fmod_debug_live_handle_count();
    const fbuf = new Array(1024).fill(0);
    const ibuf = new Array(1024).fill(0);

    // Capture and replay flags, the cursor in seconds
    check('capture_start_flags', jaxe.fmod_sys_start_command_capture('/parity.cmd.txt', 3) === 0, '');
    jaxe.fmod_sys_update();
    check('capture_stop', jaxe.fmod_sys_stop_command_capture() === 0, '');
    const replay = jaxe.fmod_sys_load_command_replay('/parity.cmd.txt', 2 | 4);
    check('replay_load_flags', replay !== 0, `handle=${replay} result=${jaxe.fmod_sys_last_result()}`);
    const length = jaxe.fmod_replay_get_length(replay);
    check('replay_seek_to_time_seconds', jaxe.fmod_replay_seek_to_time(replay, 0.0) === 0, `length=${length}`);
    check('replay_seek_past_end', jaxe.fmod_replay_seek_to_time(replay, length + 0.5) === 0, '');
    check('replay_get_command_at_time_seconds', jaxe.fmod_replay_get_command_at_time(replay, 0.0) === 0, '');
    check('replay_release', jaxe.fmod_replay_release(replay) === 0, '');
    check('replay_seek_stale', jaxe.fmod_replay_seek_to_time(replay, 0.0) === 30, '');

    // A bank from memory with a flag. The example bank is loaded from disk
    // already, so ALREADY_LOADED (70) proves the flagged call reached FMOD.
    const bankBytes = fs.readFileSync(path.join(BANKS, 'Master.bank'));
    const bankData = bankBytes.buffer.slice(bankBytes.byteOffset, bankBytes.byteOffset + bankBytes.byteLength);
    const memoryBank = jaxe.fmod_sys_load_bank_memory(bankData, bankData.byteLength, 2);
    check('bank_memory_flags', memoryBank !== 0 || jaxe.fmod_sys_last_result() === 70,
        `handle=${memoryBank} result=${jaxe.fmod_sys_last_result()}`);
    if (memoryBank !== 0) jaxe.fmod_bank_unload(memoryBank);

    // Listener attenuation position round trip
    const attrs = [1, 2, 3, 0, 0, 0, 0, 0, 1, 0, 1, 0, 7, 8, 9];
    check('listener_set_attenuation', jaxe.fmod_sys_set_listener_attributes(0, attrs, true) === 0, '');
    check('listener_get_attenuation', jaxe.fmod_sys_get_listener_attributes(0, fbuf) === 0
        && fbuf[0] === 1 && fbuf[12] === 7 && fbuf[13] === 8 && fbuf[14] === 9,
        `pos=${fbuf[0]},${fbuf[1]},${fbuf[2]} attenuation=${fbuf[12]},${fbuf[13]},${fbuf[14]}`);
    check('listener_attenuation_follows', jaxe.fmod_sys_set_listener_attributes(0, attrs, false) === 0
        && jaxe.fmod_sys_get_listener_attributes(0, fbuf) === 0
        && fbuf[12] === 1 && fbuf[13] === 2 && fbuf[14] === 3,
        `attenuation=${fbuf[12]},${fbuf[13]},${fbuf[14]}`);
    jaxe.fmod_sys_set_listener_attributes(0, [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0], false);

    // The parameter description GUID on every reader matches lookupID
    const intensityGuid = jaxe.fmod_sys_lookup_id('parameter:/Intensity');
    const byName = jaxe.fmod_sys_get_parameter_description_by_name('Intensity', fbuf, ibuf);
    check('param_guid_by_name', byName === 'Intensity' && intensityGuid.length === 38
        && jaxe.fmod_sys_last_parameter_guid() === intensityGuid,
        `guid=${jaxe.fmod_sys_last_parameter_guid()} lookup=${intensityGuid}`);
    const count = jaxe.fmod_sys_get_parameter_description_count();
    let indexedOk = count > 0;
    for (let i = 0; i < count; i++) {
        const name = jaxe.fmod_sys_get_parameter_description_by_index(i, fbuf, ibuf);
        if (jaxe.fmod_sys_last_parameter_guid() !== jaxe.fmod_sys_lookup_id('parameter:/' + name)) indexedOk = false;
    }
    check('param_guid_by_index', indexedOk, `count=${count}`);
    const surface = jaxe.fmod_evd_get_parameter_description_by_name(jump, 'Surface', fbuf, ibuf);
    const surfaceGuid = jaxe.fmod_sys_last_parameter_guid();
    const surfaceIndexed = jaxe.fmod_evd_get_parameter_description_by_index(jump, 0, fbuf, ibuf);
    check('event_param_guid', surface === 'Surface' && surfaceGuid.length === 38
        && surfaceIndexed.length > 0 && jaxe.fmod_sys_last_parameter_guid().length === 38,
        `guid=${surfaceGuid}`);

    // Sound info fields for an audio table key, zeros for a missing one
    const soundName = jaxe.fmod_sys_get_sound_info('hello', ibuf);
    check('sound_info_fields', jaxe.fmod_sys_last_result() === 0 && soundName === '/Master.bank'
        && (ibuf[1] & 0x200) !== 0 && ibuf[2] > 0 && ibuf[3] > 0 && ibuf[4] >= 0 && ibuf[5] >= 1 && ibuf[0] >= 0,
        `name=${soundName} index=${ibuf[0]} mode=${ibuf[1]} length=${ibuf[2]} offset=${ibuf[3]} initial=${ibuf[4]} subsounds=${ibuf[5]}`);
    check('sound_info_missing_zeroed', jaxe.fmod_sys_get_sound_info('no-such-key', ibuf) === ''
        && ibuf[0] === -1 && ibuf[1] === 0 && ibuf[2] === 0 && ibuf[3] === 0 && ibuf[4] === 0 && ibuf[5] === 0, '');

    // The callback drain: a plugin record's DSP becomes a handle in i1 and
    // a nested beat carries the event GUID in str. The handler is invoked
    // directly with the shapes the glue delivers (no authored plugin
    // effect exists to fire it naturally).
    const instance = jaxe.fmod_evd_create_instance(jump);
    check('plugin_instance_created', instance !== 0, `handle=${instance}`);
    const fakeEvent = { getUserData: function (out) { out.val = instance; return 0; } };
    const dspOut = {};
    jaxe.gSystemCore.createDSPByType(jaxe.FMOD.DSP_TYPE_LOWPASS, dspOut);
    const dspRaw = jaxe.rawPtr(dspOut.val);
    const handlesBefore = jaxe.fmod_debug_live_handle_count();
    jaxe.callbackHandler(0x200, fakeEvent, { name: 'fmod_gain', dsp: dspOut.val });
    check('plugin_created_drained', jaxe.fmod_cb_next() && jaxe.fmod_cb_type() === 0x200
        && jaxe.fmod_cb_string() === 'fmod_gain' && jaxe.fmod_cb_int(0) !== 0,
        `handle=${jaxe.fmod_cb_int(0)}`);
    const pluginHandle = jaxe.fmod_cb_int(0);
    check('plugin_created_handle_resolves', jaxe.rawPtr(jaxe.handleResolve(pluginHandle, jaxe.TYPE_DSP)) === dspRaw
        && jaxe.fmod_debug_live_handle_count() === handlesBefore + 1, '');
    jaxe.callbackHandler(0x400, fakeEvent, { name: 'fmod_gain', dsp: dspOut.val });
    check('plugin_destroyed_drained', jaxe.fmod_cb_next() && jaxe.fmod_cb_type() === 0x400
        && jaxe.fmod_cb_int(0) === pluginHandle && jaxe.fmod_cb_string() === 'fmod_gain', '');
    check('plugin_destroyed_slot_freed', jaxe.handleResolve(pluginHandle, jaxe.TYPE_DSP) === null
        && jaxe.fmod_debug_live_handle_count() === handlesBefore, '');
    dspOut.val.release();
    const nestedGuid = { Data1: 0x0225c47b, Data2: 0xe69f, Data3: 0x4785, Data4: [0xb8, 0x9c, 0xfd, 0x32, 0x13, 0x87, 0x93, 0x4a] };
    jaxe.callbackHandler(0x40000, fakeEvent, { bar: 1, beat: 2, position: 500, tempo: 120, timesignatureupper: 4, timesignaturelower: 4, eventid: nestedGuid });
    check('nested_beat_event_id', jaxe.fmod_cb_next() && jaxe.fmod_cb_type() === 0x40000
        && jaxe.fmod_cb_int(0) === 1 && jaxe.fmod_cb_string() === '{0225c47b-e69f-4785-b89c-fd321387934a}',
        `str=${jaxe.fmod_cb_string()}`);
    jaxe.callbackHandler(0x40000, fakeEvent, { bar: 1, beat: 3, position: 750, tempo: 120, timesignatureupper: 4, timesignaturelower: 4 });
    check('nested_beat_without_event_id', jaxe.fmod_cb_next() && jaxe.fmod_cb_string() === '' && jaxe.fmod_cb_int(1) === 3, '');
    check('queue_drained', !jaxe.fmod_cb_next(), '');
    jaxe.fmod_evi_release(instance);

    check('no_handle_leaks', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);
    console.log(`STUDIO_PARITY_TEST: ${failures === 0 ? 'COMPLETE' : 'FAILED'} failures=${failures}`);
    process.exit(failures === 0 ? 0 : 1);
}

main().catch(e => { console.log('STUDIO_PARITY_TEST: THREW', e && e.stack ? e.stack : e); process.exit(1); });
