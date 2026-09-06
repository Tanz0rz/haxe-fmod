// Proves the callback records carry FMOD's structs against the real FMOD
// 2.03.12 wasm under Node: a timeline beat from real playback arrives with
// bar, position, tempo, and time signature filled, and a programmer sound
// record (invoked directly, the example bank has no programmer instrument)
// hands the created sound over as a live sound handle with its subsound
// index, then frees that handle when the destroy record drains.
// Usage: node callback-structs-harness.js  (needs FMOD_SDK_WEB)
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

let fails = 0;
function check(label, cond, detail) {
    console.log(`CBSTRUCT_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function pump(n) {
    for (let i = 0; i < n; i++) { jaxe.fmod_sys_update(); await sleep(15); }
}
// One drained record in the layout CallbackDispatcher.decode reads
function record() {
    return {
        handle: jaxe.fmod_cb_handle(), type: jaxe.fmod_cb_type(),
        i1: jaxe.fmod_cb_int(0), i2: jaxe.fmod_cb_int(1), i3: jaxe.fmod_cb_int(2),
        i4: jaxe.fmod_cb_int(3), i5: jaxe.fmod_cb_int(4),
        f1: jaxe.fmod_cb_float(), str: jaxe.fmod_cb_string(),
    };
}
function drain() {
    const out = [];
    while (jaxe.fmod_cb_next()) out.push(record());
    return out;
}

async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await sleep(50);
    if (!jaxe.FmodIsInitialized) { console.log('INIT TIMEOUT'); process.exit(1); }

    // --- FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES from real playback ---
    const evd = jaxe.fmod_sys_get_event('event:/Music/MainLevel');
    check('get_event', evd > 0, `handle=${evd}`);
    const music = jaxe.fmod_evd_create_instance(evd);
    check('create_instance', music > 0, `handle=${music}`);
    jaxe.fmod_evi_set_callback_mask(music, 0x1000 /* TIMELINE_BEAT */);
    check('start', jaxe.fmod_evi_start(music) === 0, '');
    await pump(100);
    const beats = drain().filter(ev => ev.type === 0x1000);
    check('beats_delivered', beats.length > 0, `count=${beats.length}`);
    if (beats.length > 0) {
        const b = beats[beats.length - 1];
        check('beat_bar_and_beat', b.i1 >= 1 && b.i2 >= 1, `bar=${b.i1} beat=${b.i2}`);
        check('beat_position_ms', b.i3 >= 0, `position=${b.i3}`);
        check('beat_tempo', b.f1 > 0, `tempo=${b.f1}`);
        check('beat_time_signature', b.i4 > 0 && b.i5 > 0, `sig=${b.i4}/${b.i5}`);
    }
    jaxe.fmod_evi_stop(music, 1);
    jaxe.fmod_evi_release(music);
    await pump(5);
    drain();

    // --- FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES through the queue ---
    // ps_assign is refused on html5 (FMOD glue defect, see ps-test.js), so
    // the resolution runs on a white-box key and the handler is invoked the
    // way FMOD would invoke it. The record must carry the sound as a handle.
    const speak = jaxe.fmod_evd_create_instance(jaxe.fmod_sys_get_event('event:/Dialogue/Speak'));
    check('speak_instance', speak > 0, `handle=${speak}`);
    const inst = jaxe.handleResolve(speak, jaxe.TYPE_EVI);
    const baseline = jaxe.liveCount;
    jaxe.psKeys[speak] = 'hello';
    const props = { name: 'Line', sound: null, subsoundIndex: 0 };
    check('create_returns_ok', jaxe.callbackHandler(0x80, inst, props) === 0, '');
    check('create_resolved_sound', props.sound != null, '');
    const created = drain().filter(ev => ev.type === 0x80);
    check('create_record_queued', created.length === 1, `count=${created.length}`);
    if (created.length === 1) {
        const c = created[0];
        check('create_record_name', c.str === 'Line', `name=${c.str}`);
        check('create_record_sound_handle', c.i1 > 0 && jaxe.handleResolve(c.i1, jaxe.TYPE_SOUND) != null, `sound=${c.i1}`);
        check('create_record_subsound', c.i2 >= 0 && c.i2 === (props.subsoundIndex | 0), `subsound=${c.i2}`);
        check('create_record_library_owned', c.i3 === 1, `i3=${c.i3}`);
        check('create_record_handle_counted', jaxe.liveCount === baseline + 1, `live=${jaxe.liveCount} baseline=${baseline}`);
        // The sound handle is usable from the game thread while it lives
        // (the table's FSB container reports 0 ms, the subsound holds the
        // audio, -1 would mean the handle does not resolve)
        const lenBefore = jaxe.fmod_core_get_sound_length(c.i1, jaxe.FMOD.TIMEUNIT_MS);
        check('create_record_sound_usable', lenBefore >= 0, `length=${lenBefore}`);
        check('destroy_returns_ok', jaxe.callbackHandler(0x100, inst, props) === 0, '');
        const destroyed = drain().filter(ev => ev.type === 0x100);
        check('destroy_record_queued', destroyed.length === 1, `count=${destroyed.length}`);
        if (destroyed.length === 1) {
            check('destroy_record_same_sound', destroyed[0].i1 === c.i1, `create=${c.i1} destroy=${destroyed[0].i1}`);
            check('destroy_record_name', destroyed[0].str === 'Line', `name=${destroyed[0].str}`);
        }
        check('destroy_frees_handle', jaxe.handleResolve(c.i1, jaxe.TYPE_SOUND) == null, '');
        check('destroy_restores_count', jaxe.liveCount === baseline, `live=${jaxe.liveCount} baseline=${baseline}`);
    }
    // A key that matches nothing delivers a null sound and no handle
    jaxe.psKeys[speak] = 'no_such_key';
    const none = { name: 'Line', sound: null, subsoundIndex: 0 };
    jaxe.callbackHandler(0x80, inst, none);
    const unresolved = drain().filter(ev => ev.type === 0x80);
    check('unresolved_record_null_sound', unresolved.length === 1 && unresolved[0].i1 === 0 && unresolved[0].i3 === 0,
        unresolved.length ? `sound=${unresolved[0].i1} i3=${unresolved[0].i3}` : 'no record');
    check('unresolved_leaves_count', jaxe.liveCount === baseline, `live=${jaxe.liveCount}`);
    delete jaxe.psKeys[speak];
    jaxe.fmod_evi_release(speak);

    console.log(`CBSTRUCT_TEST: done fails=${fails}`);
    process.exit(fails ? 1 : 0);
}
main();
