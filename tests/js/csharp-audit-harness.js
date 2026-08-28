// Runs the bindings added by the audit against FMOD's C# integration in
// jaxe.js against the real FMOD 2.03.12 wasm under Node: bus port indices
// (no web call, ERR_UNSUPPORTED), parameter labels by index, parameter
// batches by ID on the system and on an instance, and the software
// channel, mixer buffer, and stream buffer readback.
// Usage: node csharp-audit-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`CSHARP_AUDIT_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
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
    if (!jaxe.FmodIsInitialized) { console.log('CSHARP_AUDIT_TEST: INIT TIMEOUT'); process.exit(1); }

    // Lookup handles are cached for the session, so the descriptions and
    // the bus are taken before the baseline
    const jump = jaxe.fmod_sys_get_event('event:/SFX/Jump');
    const music = jaxe.fmod_sys_get_event('event:/Music/MainLevel');
    const master = jaxe.fmod_sys_get_bus('bus:/');
    const baseline = jaxe.fmod_debug_live_handle_count();
    const fbuf = new Array(1024).fill(0);
    const ibuf = new Array(1024).fill(0);

    // Bus port indices have no web call
    check('bus_get_port_index_unsupported', jaxe.fmod_bus_get_port_index(master) === -1 && jaxe.fmod_sys_last_result() === 68,
        `result=${jaxe.fmod_sys_last_result()}`);
    check('bus_set_port_index_unsupported', jaxe.fmod_bus_set_port_index(master, 3) === 68, '');
    check('bus_port_index_stale', jaxe.fmod_bus_get_port_index(0) === -1 && jaxe.fmod_sys_last_result() === 30, '');

    // Labels by index agree with labels by name
    const surface = jaxe.fmod_evd_get_parameter_description_by_index(jump, 0, fbuf, ibuf);
    const byName = jaxe.fmod_evd_get_parameter_label(jump, surface, 0);
    const byIndex = jaxe.fmod_evd_get_parameter_label_by_index(jump, 0, 0);
    check('evd_label_by_index', surface.length > 0 && byIndex === byName, `name=${surface} label=${byIndex}`);
    check('evd_label_by_index_miss', jaxe.fmod_evd_get_parameter_label_by_index(jump, 99, 0) === ''
        && jaxe.fmod_sys_last_result() !== 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('evd_label_by_index_stale', jaxe.fmod_evd_get_parameter_label_by_index(0, 0, 0) === ''
        && jaxe.fmod_sys_last_result() === 30, '');

    // A parameter batch on an instance, read back by id. The music event's
    // first parameter is local to the event (the jump event's is global).
    const local = jaxe.fmod_evd_get_parameter_description_by_index(music, 0, fbuf, ibuf);
    const instance = jaxe.fmod_evd_create_instance(music);
    const id1 = ibuf[2], id2 = ibuf[3], max = fbuf[1];
    check('evi_local_parameter', local.length > 0 && (ibuf[1] & 4) === 0, `name=${local} flags=${ibuf[1]}`);
    ibuf[0] = id1; ibuf[1] = id2; fbuf[0] = max;
    check('evi_set_parameters_by_ids', jaxe.fmod_evi_set_parameters_by_ids(instance, ibuf, fbuf, 1, false) === 0,
        `result=${jaxe.fmod_sys_last_result()}`);
    jaxe.fmod_sys_update();
    check('evi_set_parameters_by_ids_value', Math.abs(jaxe.fmod_evi_get_param_by_id(instance, id1, id2) - max) < 0.001,
        `value=${jaxe.fmod_evi_get_param_by_id(instance, id1, id2)} max=${max}`);
    check('evi_set_parameters_by_ids_empty', jaxe.fmod_evi_set_parameters_by_ids(instance, ibuf, fbuf, 0, false) === 0, '');
    check('evi_set_parameters_by_ids_bad_count', jaxe.fmod_evi_set_parameters_by_ids(instance, ibuf, fbuf, -1, false) === 31, '');
    check('evi_set_parameters_by_ids_stale', jaxe.fmod_evi_set_parameters_by_ids(0, ibuf, fbuf, 1, false) === 30, '');
    jaxe.fmod_evi_release(instance);

    // A global parameter batch
    jaxe.fmod_sys_get_parameter_description_by_name('Intensity', fbuf, ibuf);
    const gid1 = ibuf[2], gid2 = ibuf[3], mid = (fbuf[0] + fbuf[1]) / 2;
    ibuf[0] = gid1; ibuf[1] = gid2; fbuf[0] = mid;
    check('sys_set_parameters_by_ids', jaxe.fmod_sys_set_parameters_by_ids(ibuf, fbuf, 1, false) === 0,
        `result=${jaxe.fmod_sys_last_result()}`);
    jaxe.fmod_sys_update();
    check('sys_set_parameters_by_ids_value', Math.abs(jaxe.fmod_sys_get_param_by_id(gid1, gid2) - mid) < 0.001,
        `value=${jaxe.fmod_sys_get_param_by_id(gid1, gid2)} mid=${mid}`);
    check('sys_set_parameters_by_ids_capacity', jaxe.fmod_sys_set_parameters_by_ids(ibuf, fbuf, 513, false) === 31, '');

    // Init readback from the running core system
    check('sys_software_channels', jaxe.fmod_sys_get_software_channels() > 0, `channels=${jaxe.fmod_sys_get_software_channels()}`);
    check('sys_dsp_buffer_size', jaxe.fmod_sys_get_dsp_buffer_size(ibuf) === 0 && ibuf[0] > 0 && ibuf[1] > 0,
        `length=${ibuf[0]} buffers=${ibuf[1]}`);
    check('sys_stream_buffer_size', jaxe.fmod_sys_get_stream_buffer_size(ibuf) === 0 && ibuf[0] > 0 && ibuf[1] === 8,
        `size=${ibuf[0]} unit=${ibuf[1]}`);

    check('no_handle_leaks', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);
    console.log(`CSHARP_AUDIT_TEST: COMPLETE failures=${failures}`);
    process.exit(failures ? 1 : 0);
}

main();
