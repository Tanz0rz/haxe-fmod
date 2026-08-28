// Runs the custom 3D rolloff and geometry bindings of jaxe.js against the
// real FMOD 2.03.12 wasm under Node. The web build rejects the rolloff
// point array and has no geometry at all, so every function here must
// report 68 (ERR_UNSUPPORTED) on a live handle, keep reporting 30
// (ERR_INVALID_HANDLE) on a dead one where a handle is involved, and
// leave the handle table untouched.
// Usage: node geometry-rolloff-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`GEO_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

async function waitForInit() {
    // The init call loads the wasm module, onRuntimeInitialized above finishes it
    const initResult = jaxe.fmod_sys_init_ex(64, 0, 0, 0, 512, 4, 40, 65536, 3);
    check('sys_init_ex', initResult === 0, `result=${initResult}`);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('GEO_TEST: INIT TIMEOUT'); process.exit(1); }
}

// Three packed points as float32 xyz triples, the shape the Haxe wrapper sends
function packedPoints() {
    const f = new Float32Array([0, 1, 0, 10, 0.5, 0, 20, 0, 0]);
    return f.buffer;
}

async function main() {
    await waitForInit();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const fbuf = new Array(1024).fill(0);
    const ibuf = new Array(1024).fill(0);
    const points = packedPoints();

    // Live handles of each rolloff type
    const stream = jaxe.fmod_core_pcm_create_3d(48000, 1, 4096);
    const chan = jaxe.fmod_core_pcm_play(stream, 0, true);
    check('rolloff_channel_live', chan > 0, `handle=${chan}`);
    const group = jaxe.fmod_cg_create('rolloff');
    check('rolloff_group_live', group > 0, `handle=${group}`);
    const sound = jaxe.fmod_core_create_sound_pcm(new Uint8Array(9600).buffer, 9600, 48000, 1);
    check('rolloff_sound_live', sound > 0, `handle=${sound}`);

    check('chan_set_3d_custom_rolloff_unsupported', jaxe.fmod_chan_set_3d_custom_rolloff(chan, points, 3) === 68, '');
    check('chan_set_3d_custom_rolloff_clear_unsupported', jaxe.fmod_chan_set_3d_custom_rolloff(chan, null, 0) === 68, '');
    check('chan_get_3d_custom_rolloff_unsupported', jaxe.fmod_chan_get_3d_custom_rolloff(chan, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);
    check('cg_set_3d_custom_rolloff_unsupported', jaxe.fmod_cg_set_3d_custom_rolloff(group, points, 3) === 68, '');
    check('cg_get_3d_custom_rolloff_unsupported', jaxe.fmod_cg_get_3d_custom_rolloff(group, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);
    check('core_sound_set_3d_custom_rolloff_unsupported', jaxe.fmod_core_sound_set_3d_custom_rolloff(sound, points, 3) === 68, '');
    check('core_sound_get_3d_custom_rolloff_unsupported', jaxe.fmod_core_sound_get_3d_custom_rolloff(sound, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);

    // Dead handles still resolve to INVALID_HANDLE ahead of the unsupported report
    check('chan_set_3d_custom_rolloff_invalid', jaxe.fmod_chan_set_3d_custom_rolloff(0, points, 3) === 30, '');
    check('chan_get_3d_custom_rolloff_invalid', jaxe.fmod_chan_get_3d_custom_rolloff(0, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 30, '');
    check('cg_set_3d_custom_rolloff_invalid', jaxe.fmod_cg_set_3d_custom_rolloff(0, points, 3) === 30, '');
    check('cg_get_3d_custom_rolloff_invalid', jaxe.fmod_cg_get_3d_custom_rolloff(0, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_set_3d_custom_rolloff_invalid', jaxe.fmod_core_sound_set_3d_custom_rolloff(0, points, 3) === 30, '');
    check('core_sound_get_3d_custom_rolloff_invalid', jaxe.fmod_core_sound_get_3d_custom_rolloff(0, fbuf) === -1
        && jaxe.fmod_sys_last_result() === 30, '');

    jaxe.fmod_chan_stop(chan);
    jaxe.fmod_core_pcm_release(stream);
    jaxe.fmod_cg_release(group);
    jaxe.fmod_core_release_sound(sound);

    // Geometry: nothing can be created, so every call reports 68
    const geo = jaxe.fmod_sys_create_geometry(4, 16);
    check('sys_create_geometry_unsupported', geo === 0 && jaxe.fmod_sys_last_result() === 68,
        `handle=${geo} result=${jaxe.fmod_sys_last_result()}`);
    check('sys_set_geometry_settings_unsupported', jaxe.fmod_sys_set_geometry_settings(1000) === 68, '');
    check('sys_get_geometry_settings_unsupported', jaxe.fmod_sys_get_geometry_settings() === 0
        && jaxe.fmod_sys_last_result() === 68, '');
    check('sys_get_geometry_occlusion_unsupported', jaxe.fmod_sys_get_geometry_occlusion(-5, 0, 0, 5, 0, 0, fbuf) === 68, '');
    const loaded = jaxe.fmod_sys_load_geometry(new Uint8Array(16).buffer, 16);
    check('sys_load_geometry_unsupported', loaded === 0 && jaxe.fmod_sys_last_result() === 68,
        `handle=${loaded} result=${jaxe.fmod_sys_last_result()}`);
    check('geo_release_unsupported', jaxe.fmod_geo_release(geo) === 68, '');
    check('geo_add_polygon_unsupported', jaxe.fmod_geo_add_polygon(geo, 1, 0.5, true, points, 3) === -1
        && jaxe.fmod_sys_last_result() === 68, '');
    check('geo_get_num_polygons_unsupported', jaxe.fmod_geo_get_num_polygons(geo) === -1
        && jaxe.fmod_sys_last_result() === 68, '');
    check('geo_get_max_polygons_unsupported', jaxe.fmod_geo_get_max_polygons(geo, ibuf) === 68, '');
    check('geo_get_polygon_num_vertices_unsupported', jaxe.fmod_geo_get_polygon_num_vertices(geo, 0) === -1
        && jaxe.fmod_sys_last_result() === 68, '');
    check('geo_set_polygon_vertex_unsupported', jaxe.fmod_geo_set_polygon_vertex(geo, 0, 0, 0, 1, 0) === 68, '');
    check('geo_get_polygon_vertex_unsupported', jaxe.fmod_geo_get_polygon_vertex(geo, 0, 0, fbuf) === 68, '');
    check('geo_set_polygon_attributes_unsupported', jaxe.fmod_geo_set_polygon_attributes(geo, 0, 1, 1, false) === 68, '');
    check('geo_get_polygon_attributes_unsupported', jaxe.fmod_geo_get_polygon_attributes(geo, 0, fbuf) === 68, '');
    check('geo_set_active_unsupported', jaxe.fmod_geo_set_active(geo, true) === 68, '');
    check('geo_get_active_unsupported', jaxe.fmod_geo_get_active(geo) === false
        && jaxe.fmod_sys_last_result() === 68, '');
    check('geo_set_rotation_unsupported', jaxe.fmod_geo_set_rotation(geo, 0, 0, 1, 0, 1, 0) === 68, '');
    check('geo_get_rotation_unsupported', jaxe.fmod_geo_get_rotation(geo, fbuf) === 68, '');
    check('geo_set_position_unsupported', jaxe.fmod_geo_set_position(geo, 0, 0, 0) === 68, '');
    check('geo_get_position_unsupported', jaxe.fmod_geo_get_position(geo, fbuf) === 68, '');
    check('geo_set_scale_unsupported', jaxe.fmod_geo_set_scale(geo, 1, 1, 1) === 68, '');
    check('geo_get_scale_unsupported', jaxe.fmod_geo_get_scale(geo, fbuf) === 68, '');
    check('geo_save_unsupported', jaxe.fmod_geo_save(geo, null, 0) === -1
        && jaxe.fmod_sys_last_result() === 68, '');

    check('no_handle_leaks_geometry_rolloff', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`GEO_TEST: failures = ${failures}`);
    console.log('GEO_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
