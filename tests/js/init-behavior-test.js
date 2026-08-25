// Validates jaxe.js init-time behavior that the wasm harnesses cannot reach
// (they replace preRun/onRuntimeInitialized to run under Node): the
// before-init update guard, the Emscripten memory knob, the software-format
// branch when only a speaker mode is requested, and the channel-count
// fallback. Runs against the real shim with a recording mock of the FMOD
// module, so no SDK download is needed.
// Usage: node init-behavior-test.js
const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');

global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };

const calls = [];
global.FMODModule = function () { calls.push(['FMODModule']); };

eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

let fails = 0;
function check(label, cond, detail) {
    console.log(`INIT_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}

// --- update before init must be a no-op, not a TypeError, matching the
// native shims' not-yet-initialized guard (init is ALWAYS async on html5) ---
let updateThrew = false;
try {
    jaxe.fmod_sys_update();
} catch (e) {
    updateThrew = true;
}
check('update_before_init_safe', !updateThrew, '');

// --- module config: this Emscripten build reads INITIAL_MEMORY ---
jaxe.fmod_sys_init_ex(64, 0, 3, 0);
check('initial_memory_set', jaxe.FMOD['INITIAL_MEMORY'] === 64 * 1024 * 1024,
    `INITIAL_MEMORY=${jaxe.FMOD['INITIAL_MEMORY']}`);
check('module_kicked_off', calls.length === 1, '');

// --- drive the real onRuntimeInitialized with a recording mock system ---
const DRIVER_RATE = 47999;
function mockSystems() {
    const core = {
        setDSPBufferSize: function () {},
        getDriverInfo: function (i, a, b, outval) { outval.val = DRIVER_RATE; },
        setSoftwareFormat: function (rate, mode, raw) { calls.push(['setSoftwareFormat', rate, mode, raw]); },
    };
    const studio = {
        getCoreSystem: function (outval) { outval.val = core; },
        initialize: function (channels, studioFlags, coreFlags) { calls.push(['initialize', channels, studioFlags, coreFlags]); },
        loadBankFile: function (p, flags, outval) { outval.val = { bankPath: p }; },
        update: function () {},
    };
    jaxe.FMOD.Studio_System_Create = function (outval) { outval.val = studio; };
    jaxe.FMOD.SPEAKERMODE_DEFAULT = 0;
    jaxe.FMOD.STUDIO_INIT_NORMAL = 0;
    jaxe.FMOD.STUDIO_INIT_LIVEUPDATE = 1;
    jaxe.FMOD.INIT_NORMAL = 0;
    jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL = 0;
    jaxe.FMOD.OK = 0;
}

function initCalls() {
    return {
        format: calls.filter(c => c[0] === 'setSoftwareFormat').pop(),
        init: calls.filter(c => c[0] === 'initialize').pop(),
    };
}

// speakerMode without sampleRate must reach FMOD with the driver rate,
// matching the native shims' `sampleRate > 0 || speakerMode > 0` branch
mockSystems();
jaxe.pendingInit = { numChannels: 64, sampleRate: 0, speakerMode: 3, studioFlags: 0 };
jaxe.onRuntimeInitialized();
let got = initCalls();
check('speaker_mode_without_rate_honored',
    got.format && got.format[1] === DRIVER_RATE && got.format[2] === 3,
    JSON.stringify(got.format));
check('num_channels_forwarded', got.init && got.init[1] === 64, JSON.stringify(got.init));

// missing channel count falls back to 128 like the native shims
calls.length = 0;
mockSystems();
jaxe.FmodIsInitialized = false;
jaxe.fmod_sys_set_auto_update(false);
jaxe.pendingInit = { numChannels: 0, sampleRate: 0, speakerMode: 0, studioFlags: 0 };
jaxe.onRuntimeInitialized();
got = initCalls();
check('num_channels_default_128', got.init && got.init[1] === 128, JSON.stringify(got.init));
check('default_format_uses_driver_rate',
    got.format && got.format[1] === DRIVER_RATE && got.format[2] === 0,
    JSON.stringify(got.format));

// explicit rate and mode pass through unchanged
calls.length = 0;
mockSystems();
jaxe.FmodIsInitialized = false;
jaxe.fmod_sys_set_auto_update(false);
jaxe.pendingInit = { numChannels: 32, sampleRate: 44100, speakerMode: 5, studioFlags: 0 };
jaxe.onRuntimeInitialized();
got = initCalls();
check('explicit_rate_and_mode',
    got.format && got.format[1] === 44100 && got.format[2] === 5,
    JSON.stringify(got.format));

// --- callback marshaling for shapes the wasm harnesses cannot author:
// FMOD's JS glue delivers timeline beats with flat keys and has no
// marshaler for the nested-beat struct, so the nested branch must read
// the flat keys instead of enqueueing zeros ---
function drain() {
    const events = [];
    while (jaxe.fmod_cb_next()) {
        events.push({
            type: jaxe.fmod_cb_type(),
            bar: jaxe.fmod_cb_int(0), beat: jaxe.fmod_cb_int(1),
            position: jaxe.fmod_cb_int(2), sigUpper: jaxe.fmod_cb_int(3),
            sigLower: jaxe.fmod_cb_int(4), tempo: jaxe.fmod_cb_float(),
        });
    }
    return events;
}
const cbFakeEvent = { getUserData: function (out) { out.val = 4242; return 0; } };
const flatBeat = { bar: 3, beat: 2, position: 4500, tempo: 128, timesignatureupper: 6, timesignaturelower: 8 };

jaxe.callbackHandler(0x40000 /* NESTED_TIMELINE_BEAT */, cbFakeEvent, flatBeat);
got = drain();
check('nested_beat_reads_flat_keys',
    got.length === 1 && got[0].bar === 3 && got[0].beat === 2 && got[0].position === 4500
    && got[0].sigUpper === 6 && got[0].sigLower === 8 && Math.abs(got[0].tempo - 128) < 0.001,
    JSON.stringify(got[0]));

// the nested shape stays supported in case a future glue adds it
jaxe.callbackHandler(0x40000, cbFakeEvent, { properties: flatBeat });
got = drain();
check('nested_beat_reads_nested_shape',
    got.length === 1 && got[0].bar === 3 && got[0].sigLower === 8,
    JSON.stringify(got[0]));

// top-level beats keep the flat read they always had
jaxe.callbackHandler(0x1000 /* TIMELINE_BEAT */, cbFakeEvent, flatBeat);
got = drain();
check('top_level_beat_flat_keys', got.length === 1 && got[0].bar === 3, JSON.stringify(got[0]));

jaxe.fmod_sys_set_auto_update(false);
console.log(`INIT_TEST: failures = ${fails}`);
console.log(fails === 0 ? 'INIT_TEST: COMPLETE' : 'INIT_TEST: FAILED');
process.exit(fails === 0 ? 0 : 1);
