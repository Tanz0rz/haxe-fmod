// Runs the init settings of jaxe.js against the real FMOD 2.03.12 wasm
// under Node: the output type, the mixer buffer, the resampler, raw
// speakers, memory tracking, driver info, and the pre-create hooks the
// web build cannot serve (memory pool, thread attributes, file logging,
// console ports), which must report 68 (ERR_UNSUPPORTED) and leave the
// handle table alone. Unlike the other harnesses this one lets the shim's
// own onRuntimeInitialized run, since that is where the settings apply.
// Usage: node init-settings-harness.js  (needs FMOD_SDK_WEB)

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

let failures = 0;
function check(label, cond, detail) {
    console.log(`INIT_SETTINGS_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

const NOSOUND_NRT = 4;
const WASAPI = 6;
const CUBIC = 3;
const RAW = 1;
const MEMORY_TRACKING = 2; // studioFlags bit1

// The web build rejects getAdvancedSettings, so the struct handed to
// setAdvancedSettings is captured on its way through instead
let appliedAdvanced = null;
const applyAdvanced = jaxe.applyPendingAdvancedSettings;
jaxe.applyPendingAdvancedSettings = function (core, studio, init) {
    const real = core.setAdvancedSettings;
    core.setAdvancedSettings = function (adv) { appliedAdvanced = adv; return real.call(core, adv); };
    applyAdvanced(core, studio, init);
    core.setAdvancedSettings = real;
};

async function waitForInit() {
    // A native-only output is refused before the module starts, and the
    // refusal leaves init available for the real call
    const refused = jaxe.fmod_sys_set_init_format(WASAPI, 0, 0);
    check('init_refuses_native_output', refused === 68 && jaxe.pendingFormat === null, `result=${refused}`);
    check('init_format_accepted', jaxe.fmod_sys_set_init_format(NOSOUND_NRT, CUBIC, 4) === 0, '');

    const initResult = jaxe.fmod_sys_init_ex(64, 48000, RAW, MEMORY_TRACKING, 1024, 4, 40, 65536, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "");
    check('sys_init_ex', initResult === 0, `result=${initResult}`);
    check('init_format_locked_after_init', jaxe.fmod_sys_set_init_format(0, 0, 0) === jaxe.ERR_INITIALIZED, '');
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('INIT_SETTINGS_TEST: INIT TIMEOUT'); process.exit(1); }
    // The auto-update timer would keep the process alive
    jaxe.fmod_sys_set_auto_update(false);
}

async function main() {
    await waitForInit();
    const master = jaxe.fmod_cg_get_master();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const ibuf = new Array(1024).fill(0);
    const fbuf = new Array(1024).fill(0);
    const out = {};

    // What landed before initialize
    check('output_type_applied', jaxe.fmod_sys_get_output() === NOSOUND_NRT, `output=${jaxe.fmod_sys_get_output()}`);
    const a = {}, b = {};
    jaxe.gSystemCore.getDSPBufferSize(a, b);
    check('dsp_buffer_size_applied', a.val === 1024 && b.val === 4, `length=${a.val} count=${b.val}`);
    const rate = {}, mode = {}, raw = {};
    jaxe.gSystemCore.getSoftwareFormat(rate, mode, raw);
    check('raw_speaker_format_applied', rate.val === 48000 && mode.val === RAW && raw.val === 4,
        `rate=${rate.val} mode=${mode.val} raw=${raw.val}`);
    check('resampler_applied', appliedAdvanced !== null && appliedAdvanced.resamplerMethod === CUBIC,
        `resampler=${appliedAdvanced && appliedAdvanced.resamplerMethod}`);
    check('memory_tracking_flag', jaxe.studioInitFlags(jaxe.pendingInit) === (jaxe.FMOD.STUDIO_INIT_MEMORY_TRACKING | 0),
        `flags=${jaxe.studioInitFlags(jaxe.pendingInit)}`);

    // Driver info against the NoSound driver
    const name = jaxe.fmod_sys_get_driver_info(0, ibuf);
    check('sys_get_driver_info', jaxe.fmod_sys_last_result() === 0 && name.length > 0 && ibuf[0] > 0 && ibuf[2] > 0,
        `name=${name} rate=${ibuf[0]} mode=${ibuf[1]} channels=${ibuf[2]}`);
    const guid = jaxe.fmod_sys_get_driver_guid(0);
    check('sys_get_driver_guid', jaxe.fmod_sys_last_result() === 0 && guid.length === 38 && guid[0] === '{', `guid=${guid}`);
    check('sys_get_driver_info_out_of_range', jaxe.fmod_sys_get_driver_info(99, ibuf) === '' && jaxe.fmod_sys_last_result() !== 0
        && ibuf[0] === 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('sys_get_driver_guid_out_of_range', jaxe.fmod_sys_get_driver_guid(99) === '', '');

    // The pre-create hooks the web build has no answer for
    check('memory_initialize_unsupported', jaxe.fmod_sys_memory_initialize(1 << 20) === 68, '');
    check('thread_set_attributes_unsupported', jaxe.fmod_sys_thread_set_attributes(0, -32769, 0, -1) === 68, '');
    check('debug_initialize_file_unsupported', jaxe.fmod_sys_debug_initialize(1, 1, '/fmod.log') === 68, '');
    const tty = jaxe.fmod_sys_debug_initialize(1, 0, '');
    check('debug_initialize_tty_reports', tty === 0 || tty === 68, `result=${tty}`);
    check('debug_initialize_rejects_non_string', jaxe.fmod_sys_debug_initialize(1, 0, null) === 31, '');

    // Console ports: a live group is refused as unsupported, a dead one as invalid
    check('attach_port_unsupported', jaxe.fmod_sys_attach_channel_group_to_port(0, -1, master, false) === 68, '');
    check('detach_port_unsupported', jaxe.fmod_sys_detach_channel_group_from_port(master) === 68, '');
    const group = jaxe.fmod_cg_create('ports');
    jaxe.fmod_cg_release(group);
    check('attach_port_dead_handle', jaxe.fmod_sys_attach_channel_group_to_port(0, -1, group, true) === 30, '');
    check('detach_port_dead_handle', jaxe.fmod_sys_detach_channel_group_from_port(group) === 30, '');

    // Memory stats still work with tracking on
    check('memory_stats_with_tracking', jaxe.fmod_sys_get_memory_stats(true, ibuf) === 0 && ibuf[0] > 0, `current=${ibuf[0]} max=${ibuf[1]}`);

    check('no_handle_leaks', jaxe.fmod_debug_live_handle_count() === baseline,
        `before=${baseline} after=${jaxe.fmod_debug_live_handle_count()}`);
    console.log(`INIT_SETTINGS_TEST: COMPLETE failures=${failures}`);
    process.exit(failures > 0 ? 1 : 0);
}

main().catch(e => { console.log('INIT_SETTINGS_TEST: THREW', e && e.stack || e); process.exit(1); });
