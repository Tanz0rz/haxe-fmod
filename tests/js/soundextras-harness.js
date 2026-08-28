// Runs the sound extras of jaxe.js against the real FMOD 2.03.12 wasm under
// Node: tracker music, subsounds, tags, and the advanced settings passed
// through fmod_sys_init_ex. The web build cannot load a tracker module,
// cannot hand a tag payload to JavaScript, and rejects every call to its
// advanced settings getters, so those report 68 (ERR_UNSUPPORTED) on a
// live handle and keep reporting 30 (ERR_INVALID_HANDLE) on a dead one.
// The subsound calls and the tag count work and are checked for real.
// Usage: node soundextras-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`SOUNDEXTRAS_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

let advancedApplied = null;
jaxe.onRuntimeInitialized = function () {
    try {
        var outval = {};
        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;
        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;
        jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
        jaxe.applyPendingCoreSettings(jaxe.gSystemCore, jaxe.pendingInit);
        // The advanced settings go through the same helper the game path
        // uses. A throw here would mean the JS struct lost a field.
        try {
            jaxe.applyPendingAdvancedSettings(jaxe.gSystemCore, jaxe.gSystem, jaxe.pendingInit);
            advancedApplied = true;
        } catch (e) {
            advancedApplied = e.message;
        }
        jaxe.gSystem.initialize(64, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.coreInitFlags(jaxe.pendingInit), null);
        jaxe.FmodIsInitialized = true;
    } catch (e) {
        console.log('INIT THREW:', e.message);
        process.exit(1);
    }
    return jaxe.FMOD.OK;
};

async function waitForInit() {
    // Every advanced setting is nonzero so the apply path touches each field
    const initResult = jaxe.fmod_sys_init_ex(64, 0, 0, 0, 512, 4, 40, 65536, 3,
        8, 9, 10, 0.01, 800, 9300, 250, 2000, 12345,
        65536, 16384, 30, 524288, 4096, "secret");
    check('sys_init_ex_accepts_advanced_settings', initResult === 0, `result=${initResult}`);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('SOUNDEXTRAS_TEST: INIT TIMEOUT'); process.exit(1); }
}

async function main() {
    await waitForInit();
    check('advanced_settings_apply_no_throw', advancedApplied === true, `value=${advancedApplied}`);
    check('pending_init_keeps_advanced_settings', jaxe.pendingInit.randomSeed === 12345
        && jaxe.pendingInit.commandQueueSize === 65536 && Math.abs(jaxe.pendingInit.vol0VirtualVol - 0.01) < 1e-6,
        `seed=${jaxe.pendingInit.randomSeed} queue=${jaxe.pendingInit.commandQueueSize}`);

    const baseline = jaxe.fmod_debug_live_handle_count();
    const ibuf = new Array(16).fill(0);
    const fbuf = new Array(16).fill(0);

    // --- advanced settings readback: the web getter rejects every call ---
    check('sys_get_advanced_settings_unsupported', jaxe.fmod_sys_get_advanced_settings(ibuf, fbuf) === 68
        && ibuf[6] === 0 && fbuf[0] === 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('sys_get_studio_advanced_settings_unsupported', jaxe.fmod_sys_get_studio_advanced_settings(ibuf) === 68
        && ibuf[0] === 0, `result=${jaxe.fmod_sys_last_result()}`);

    // --- a plain PCM sound stands in for every handle-level check ---
    const pcm = new Uint8Array(4096).buffer;
    const sound = jaxe.fmod_core_create_sound_pcm(pcm, 4096, 8000, 1);
    check('core_create_sound_pcm', sound > 0, `handle=${sound}`);

    // Tracker music: no module can load on the web, so 68 on a live handle
    check('core_sound_get_music_num_channels_unsupported', jaxe.fmod_core_sound_get_music_num_channels(sound) === -1
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);
    check('core_sound_set_music_channel_volume_unsupported', jaxe.fmod_core_sound_set_music_channel_volume(sound, 0, 0.5) === 68, '');
    check('core_sound_get_music_channel_volume_unsupported', jaxe.fmod_core_sound_get_music_channel_volume(sound, 0) === 0
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);
    check('core_sound_set_music_speed_unsupported', jaxe.fmod_core_sound_set_music_speed(sound, 1.5) === 68, '');
    check('core_sound_get_music_speed_unsupported', jaxe.fmod_core_sound_get_music_speed(sound) === 0
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);

    // Subsounds work on the web build
    check('core_sound_get_num_sub_sounds', jaxe.fmod_core_sound_get_num_sub_sounds(sound) === 0
        && jaxe.fmod_sys_last_result() === 0, `result=${jaxe.fmod_sys_last_result()}`);
    const missingSub = jaxe.fmod_core_sound_get_sub_sound(sound, 0);
    check('core_sound_get_sub_sound_missing', missingSub === 0 && jaxe.fmod_sys_last_result() === 31,
        `handle=${missingSub} result=${jaxe.fmod_sys_last_result()}`);
    const parent = jaxe.fmod_core_sound_get_sub_sound_parent(sound);
    check('core_sound_get_sub_sound_parent_top_level', parent === 0 && jaxe.fmod_sys_last_result() === 0,
        `handle=${parent} result=${jaxe.fmod_sys_last_result()}`);

    // Tag count works, the tag payload cannot cross embind
    ibuf[0] = 99;
    check('core_sound_get_num_tags', jaxe.fmod_core_sound_get_num_tags(sound, ibuf) === 0 && ibuf[0] === 0,
        `updated=${ibuf[0]} result=${jaxe.fmod_sys_last_result()}`);
    ibuf[1] = 99;
    check('core_sound_get_tag_unsupported', jaxe.fmod_core_sound_get_tag(sound, "", 0, ibuf, fbuf) === ""
        && jaxe.fmod_sys_last_result() === 68 && ibuf[1] === 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('core_sound_get_tag_string_unsupported', jaxe.fmod_core_sound_get_tag_string(sound, "", 0) === ""
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);

    // Dead handle: every call reports 30 ahead of the unsupported path
    jaxe.fmod_core_release_sound(sound);
    check('core_sound_get_music_num_channels_stale', jaxe.fmod_core_sound_get_music_num_channels(sound) === -1
        && jaxe.fmod_sys_last_result() === 30, `result=${jaxe.fmod_sys_last_result()}`);
    check('core_sound_set_music_channel_volume_stale', jaxe.fmod_core_sound_set_music_channel_volume(sound, 0, 0.5) === 30, '');
    check('core_sound_get_music_channel_volume_stale', jaxe.fmod_core_sound_get_music_channel_volume(sound, 0) === 0
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_set_music_speed_stale', jaxe.fmod_core_sound_set_music_speed(sound, 1.5) === 30, '');
    check('core_sound_get_music_speed_stale', jaxe.fmod_core_sound_get_music_speed(sound) === 0
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_get_num_sub_sounds_stale', jaxe.fmod_core_sound_get_num_sub_sounds(sound) === -1
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_get_sub_sound_stale', jaxe.fmod_core_sound_get_sub_sound(sound, 0) === 0
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_get_sub_sound_parent_stale', jaxe.fmod_core_sound_get_sub_sound_parent(sound) === 0
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_get_num_tags_stale', jaxe.fmod_core_sound_get_num_tags(sound, ibuf) === -1
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_get_tag_stale', jaxe.fmod_core_sound_get_tag(sound, "", 0, ibuf, fbuf) === ""
        && jaxe.fmod_sys_last_result() === 30, '');
    check('core_sound_get_tag_string_stale', jaxe.fmod_core_sound_get_tag_string(sound, "", 0) === ""
        && jaxe.fmod_sys_last_result() === 30, '');

    check('no_handle_leaks_sound_extras', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`SOUNDEXTRAS_TEST: failures = ${failures}`);
    console.log('SOUNDEXTRAS_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
