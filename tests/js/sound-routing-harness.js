// Runs the sound creation and playback routing surface of jaxe.js against
// the real FMOD 2.03.12 wasm under Node: fmod_core_create_sound with a full
// FMOD_MODE and an initial subsound, fmod_core_create_sound_memory with an
// encoded image (an FSB slice cut out of the Master bank, the one encoded
// format the web build decodes), the channel group argument of every play
// call, and the refusal of the game-sound and instrument-name programmer
// sound forms (the glue defect pinned by ps-test.js applies to them too).
// Usage: node sound-routing-harness.js  (needs FMOD_SDK_WEB)

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
const WAV = path.join(REPO, 'example-project', 'EZPlatformer', 'fmod', 'Assets', 'Jump.wav');

global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

jaxe.preRun = function () {
    for (const n of ['Master.bank', 'Master.strings.bank']) {
        jaxe.FMOD.FS_createDataFile('/', n, fs.readFileSync(path.join(BANKS, n)), true, false, false);
    }
    jaxe.FMOD.FS_createDataFile('/', 'Jump.wav', fs.readFileSync(WAV), true, false, false);
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

let fails = 0;
function check(label, cond, detail) {
    console.log(`SOUND_ROUTING_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) fails++;
}

const OK = 0, ERR_FILE_NOTFOUND = 18, ERR_FORMAT = 19, ERR_INVALID_HANDLE = 30, ERR_INVALID_PARAM = 31, ERR_UNSUPPORTED = 68;
const MODE_3D = 0x10, CREATESTREAM = 0x80, CREATECOMPRESSEDSAMPLE = 0x200, NONBLOCKING = 0x10000, LOOP_NORMAL = 0x2;

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('INIT TIMEOUT'); process.exit(1); }
    // The master group and the event description are persistent lookup
    // handles, warm both before the baseline
    jaxe.fmod_cg_get_master();
    jaxe.fmod_sys_get_event('event:/Dialogue/Speak');
    const baseline = jaxe.fmod_debug_live_handle_count();

    // --- create_sound with a full mode: the flags reach the glue (a stream
    // request on a wav still fails on the codec, not on the mode), a
    // missing file with an initial subsound is a clean not-found, and
    // NONBLOCKING is dropped rather than rejected (the glue reports it
    // unsupported, see the shim comment)
    check('create_sound_stream_flag_reaches_glue',
        jaxe.fmod_core_create_sound('Jump.wav', CREATESTREAM | MODE_3D, -1) === 0 && jaxe.fmod_sys_last_result() === ERR_FORMAT,
        `last=${jaxe.fmod_sys_last_result()}`);
    check('create_sound_initial_subsound_missing_file',
        jaxe.fmod_core_create_sound('Nope.fsb', 0, 1) === 0 && jaxe.fmod_sys_last_result() === ERR_FILE_NOTFOUND,
        `last=${jaxe.fmod_sys_last_result()}`);
    check('create_sound_nonblocking_not_rejected',
        jaxe.fmod_core_create_sound('Nope.wav', NONBLOCKING, -1) === 0 && jaxe.fmod_sys_last_result() === ERR_FILE_NOTFOUND,
        `last=${jaxe.fmod_sys_last_result()}`);
    check('create_sound_bad_path', jaxe.fmod_core_create_sound(42, 0, -1) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_PARAM, '');

    // --- create_sound_memory: a wav image hits the codec limit, an FSB
    // image cut out of the bank (the slice getSoundInfo describes for the
    // audio table key) loads for real with two subsounds
    const wav = fs.readFileSync(WAV);
    const wavBuffer = wav.buffer.slice(wav.byteOffset, wav.byteOffset + wav.byteLength);
    check('memory_wav_format_limit',
        jaxe.fmod_core_create_sound_memory(wavBuffer, wavBuffer.byteLength, 0) === 0 && jaxe.fmod_sys_last_result() === ERR_FORMAT,
        `last=${jaxe.fmod_sys_last_result()}`);
    check('memory_null_rejected', jaxe.fmod_core_create_sound_memory(null, 4, 0) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_PARAM, '');
    check('memory_zero_len_rejected', jaxe.fmod_core_create_sound_memory(wavBuffer, 0, 0) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_PARAM, '');
    check('memory_lied_len_rejected', jaxe.fmod_core_create_sound_memory(wavBuffer, wavBuffer.byteLength + 1, 0) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_PARAM, '');

    var info = { exinfo: {} };
    check('audio_table_info', jaxe.gSystem.getSoundInfo('hello', info) === OK && typeof info.name_or_data === 'string', '');
    const bank = fs.readFileSync(path.join(BANKS, path.basename(info.name_or_data)));
    const off = info.exinfo.fileoffset | 0, len = info.exinfo.length | 0;
    const slice = bank.buffer.slice(bank.byteOffset + off, bank.byteOffset + off + len);
    // The image is copied before it reaches the glue, so wiping the source
    // afterwards must not touch the sound
    const image = new Uint8Array(slice.slice(0));
    const fsb = jaxe.fmod_core_create_sound_memory(image.buffer, len, CREATECOMPRESSEDSAMPLE | NONBLOCKING);
    check('memory_fsb_loads', fsb > 0, `handle=${fsb} last=${jaxe.fmod_sys_last_result()}`);
    image.fill(0);
    check('memory_fsb_subsounds', jaxe.fmod_core_sound_get_num_sub_sounds(fsb) === 2, `n=${jaxe.fmod_core_sound_get_num_sub_sounds(fsb)}`);
    check('memory_fsb_ready', jaxe.fmod_sound_get_open_state(fsb) === 0, `state=${jaxe.fmod_sound_get_open_state(fsb)}`);
    const sub = jaxe.fmod_core_sound_get_sub_sound(fsb, 1);
    // 1 is FMOD_TIMEUNIT_MS, the unit argument core_get_sound_length takes
    check('memory_fsb_subsound', sub > 0 && jaxe.fmod_core_get_sound_length(sub, 1) > 0, `sub=${sub} len=${jaxe.fmod_core_get_sound_length(sub, 1)}`);

    // --- play routing: every play call takes a group handle, 0 is the
    // master group, a stale one refuses
    const group = jaxe.fmod_cg_create('routing');
    check('group', group > 0, '');
    const ch = jaxe.fmod_core_play_sound(sub, group, true);
    check('play_sound_into_group', ch > 0 && jaxe.fmod_chan_get_channel_group(ch) === group,
        `ch=${ch} group=${jaxe.fmod_chan_get_channel_group(ch)} want=${group}`);
    const master = jaxe.fmod_cg_get_master();
    const chMaster = jaxe.fmod_core_play_sound(sub, 0, true);
    check('play_sound_default_master', chMaster > 0 && jaxe.fmod_chan_get_channel_group(chMaster) === master,
        `group=${jaxe.fmod_chan_get_channel_group(chMaster)} master=${master}`);
    check('play_sound_stale_group_refused',
        jaxe.fmod_core_play_sound(sub, 99999, true) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_HANDLE,
        `last=${jaxe.fmod_sys_last_result()}`);
    jaxe.fmod_chan_stop(ch);
    jaxe.fmod_chan_stop(chMaster);
    jaxe.fmod_core_release_sound(fsb);

    const osc = jaxe.fmod_dsp_create_by_type(3 /* OSCILLATOR */);
    const oscCh = jaxe.fmod_sys_play_dsp(osc, group, true);
    check('play_dsp_into_group', oscCh > 0 && jaxe.fmod_chan_get_channel_group(oscCh) === group,
        `ch=${oscCh} group=${jaxe.fmod_chan_get_channel_group(oscCh)}`);
    check('play_dsp_stale_group_refused',
        jaxe.fmod_sys_play_dsp(osc, 99999, true) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_HANDLE, '');
    jaxe.fmod_chan_stop(oscCh);
    jaxe.fmod_dsp_release(osc);

    const pcm = jaxe.fmod_core_pcm_create(48000, 1, 16384);
    const pcmCh = jaxe.fmod_core_pcm_play(pcm, group, true);
    check('pcm_play_into_group', pcmCh > 0 && jaxe.fmod_chan_get_channel_group(pcmCh) === group,
        `ch=${pcmCh} group=${jaxe.fmod_chan_get_channel_group(pcmCh)}`);
    check('pcm_play_stale_group_refused',
        jaxe.fmod_core_pcm_play(pcm, 99999, true) === 0 && jaxe.fmod_sys_last_result() === ERR_INVALID_HANDLE, '');
    jaxe.fmod_chan_stop(pcmCh);
    jaxe.fmod_core_pcm_release(pcm);
    jaxe.fmod_cg_release(group);

    // --- programmer sound forms: same refusal as ps_assign after the
    // argument checks native makes
    const evi = jaxe.fmod_evd_create_instance(jaxe.fmod_sys_get_event('event:/Dialogue/Speak'));
    const pcmBytes = new ArrayBuffer(1024);
    const owned = jaxe.fmod_core_create_sound_pcm(pcmBytes, 1024, 8000, 1);
    check('ps_assign_sound_unsupported', jaxe.fmod_ps_assign_sound(evi, owned, -1) === ERR_UNSUPPORTED, '');
    check('ps_assign_sound_stale_sound', jaxe.fmod_ps_assign_sound(evi, 99999, -1) === ERR_INVALID_HANDLE, '');
    check('ps_assign_sound_bad_subsound', jaxe.fmod_ps_assign_sound(evi, owned, -2) === ERR_INVALID_PARAM, '');
    check('ps_assign_sound_stale_instance', jaxe.fmod_ps_assign_sound(99999, owned, -1) === ERR_INVALID_HANDLE, '');
    check('ps_assign_named_unsupported', jaxe.fmod_ps_assign_named(evi, 'Line', 'hello') === ERR_UNSUPPORTED, '');
    check('ps_assign_named_bad_args', jaxe.fmod_ps_assign_named(evi, 5, 'hello') === ERR_INVALID_PARAM, '');
    check('ps_assign_named_overlong_name', jaxe.fmod_ps_assign_named(evi, 'n'.repeat(64), 'hello') === ERR_INVALID_PARAM, '');
    check('ps_assign_named_stale_instance', jaxe.fmod_ps_assign_named(99999, 'Line', 'hello') === ERR_INVALID_HANDLE, '');
    check('ps_mask_not_armed', (jaxe.effectiveCallbackMask(evi) & 0x180) === 0, '');
    // The create and destroy events carry the instrument name
    const inst = jaxe.handleResolve(evi, jaxe.TYPE_EVI);
    while (jaxe.fmod_cb_next()) { /* drain */ }
    jaxe.callbackHandler(0x80, inst, { name: 'Line', sound: null, subsoundIndex: 0 });
    jaxe.callbackHandler(0x100, inst, { name: 'Line', sound: null, subsoundIndex: 0 });
    let names = [];
    while (jaxe.fmod_cb_next()) names.push(jaxe.fmod_cb_type() + ':' + jaxe.fmod_cb_string());
    check('ps_events_carry_instrument_name', names.join(',') === '128:Line,256:Line', names.join(','));
    jaxe.fmod_core_release_sound(owned);
    jaxe.fmod_evi_release(evi);
    jaxe.fmod_sys_update();
    while (jaxe.fmod_cb_next()) { /* drain */ }

    check('no_handle_leaks', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(fails ? `SOUND_ROUTING_TEST FAILED: ${fails}` : 'SOUND_ROUTING_TEST COMPLETE');
    process.exit(fails ? 1 : 0);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
