// Exercises the Core PCM stream and channel surface of jaxe.js against the
// real FMOD 2.03.12 wasm: ring write/drain through a live OPENUSER sound,
// channel control round-trips, underrun accounting, and handle lifetime.
// Uses NOSOUND_NRT output so update() pumps the mixer deterministically and
// pcmread demand is driven from this script.
// Usage: node pcm-harness.js  (needs FMOD_SDK_WEB)

const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

// No banks needed: the Core PCM surface runs on the core system alone
jaxe.onRuntimeInitialized = function () {
    var o = {};
    jaxe.FMOD.Studio_System_Create(o); jaxe.gSystem = o.val;
    jaxe.gSystem.getCoreSystem(o); jaxe.gSystemCore = o.val;
    jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
    jaxe.gSystem.initialize(256, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let failures = 0;
function check(label, cond, detail) {
    console.log(`PCM_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) { failures++; process.exitCode = 1; }
}

function pump(n) {
    for (let i = 0; i < n; i++) jaxe.gSystem.update();
}

async function main() {
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD).catch(e => { console.log('MODULE REJECTED', e); process.exit(1); });
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await new Promise(r => setTimeout(r, 50));
    if (!jaxe.FmodIsInitialized) { console.log('PCM_TEST: INIT TIMEOUT'); process.exit(1); }
    console.log('PCM_TEST: initialized');

    // The pcmread copy needs the module heap view
    check('heapu8_exported', jaxe.FMOD.HEAPU8 instanceof Uint8Array,
        `typeof=${typeof jaxe.FMOD.HEAPU8}`);

    // Bad args are rejected before any FMOD call
    check('pcm_create_bad_args', jaxe.fmod_core_pcm_create(0, 1, 4096) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_PARAM);

    const RATE = 48000;
    const ps = jaxe.fmod_core_pcm_create(RATE, 1, 65536);
    check('pcm_create', ps !== 0, `handle=${ps} result=${jaxe.lastResult}`);
    if (ps === 0) { process.exit(1); }

    // Half a second of a 440Hz sine (16-bit mono) fed through the ring
    const samples = Math.floor(RATE * 0.5);
    const buf = new ArrayBuffer(samples * 2);
    const view = new Int16Array(buf);
    for (let i = 0; i < samples; i++) {
        view[i] = Math.round(Math.sin(2 * Math.PI * 440 * i / RATE) * 0x6000);
    }
    const spaceBefore = jaxe.fmod_core_pcm_space(ps);
    const wrote = jaxe.fmod_core_pcm_write(ps, buf, buf.byteLength);
    check('pcm_write', wrote === Math.min(buf.byteLength, spaceBefore),
        `wrote=${wrote} space=${spaceBefore}`);
    check('pcm_space_shrinks', jaxe.fmod_core_pcm_space(ps) === spaceBefore - wrote);

    const ch = jaxe.fmod_core_pcm_play(ps, false);
    check('pcm_play', ch !== 0, `handle=${ch} result=${jaxe.lastResult}`);

    // NRT updates make the mixer drain the ring through pcmread
    pump(30);
    const spaceAfter = jaxe.fmod_core_pcm_space(ps);
    check('mixer_drained_ring', spaceAfter > spaceBefore - wrote,
        `before=${spaceBefore - wrote} after=${spaceAfter}`);

    // Channel round-trips
    check('chan_set_volume', jaxe.fmod_chan_set_volume(ch, 0.5) === jaxe.FMOD.OK);
    check('chan_get_volume', Math.abs(jaxe.fmod_chan_get_volume(ch) - 0.5) < 0.001,
        `value=${jaxe.fmod_chan_get_volume(ch)}`);
    check('chan_set_pitch', jaxe.fmod_chan_set_pitch(ch, 1.5) === jaxe.FMOD.OK);
    check('chan_get_pitch', Math.abs(jaxe.fmod_chan_get_pitch(ch) - 1.5) < 0.001,
        `value=${jaxe.fmod_chan_get_pitch(ch)}`);
    check('chan_is_playing', jaxe.fmod_chan_is_playing(ch) === true);
    check('chan_set_paused', jaxe.fmod_chan_set_paused(ch, true) === jaxe.FMOD.OK);
    check('chan_get_paused', jaxe.fmod_chan_get_paused(ch) === true);
    jaxe.fmod_chan_set_paused(ch, false);

    // Drain past empty: reads must pad with silence and count underruns
    pump(200);
    const under = jaxe.fmod_core_pcm_underruns(ps);
    check('underruns_counted', under > 0, `underruns=${under}`);
    check('underruns_cleared', jaxe.fmod_core_pcm_underruns(ps) === 0);

    // Stop frees the channel slot even when FMOD already dropped the channel
    const stopRes = jaxe.fmod_chan_stop(ch);
    check('chan_stop', typeof stopRes === 'number', `result=${stopRes}`);
    check('chan_handle_freed', jaxe.fmod_chan_set_volume(ch, 1.0) === jaxe.ERR_INVALID_HANDLE);

    check('pcm_release', jaxe.fmod_core_pcm_release(ps) === jaxe.FMOD.OK,
        `result=${jaxe.lastResult}`);
    check('pcm_handle_freed', jaxe.fmod_core_pcm_space(ps) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_HANDLE);

    // Stale handles across the whole new surface return the handle error
    check('stale_pcm_write', jaxe.fmod_core_pcm_write(ps, buf, 4) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_HANDLE);
    check('stale_pcm_play', jaxe.fmod_core_pcm_play(ps, false) === 0
        && jaxe.lastResult === jaxe.ERR_INVALID_HANDLE);
    check('stale_chan_getters', jaxe.fmod_chan_get_volume(ch) === 0.0
        && jaxe.fmod_chan_is_playing(ch) === false
        && jaxe.fmod_chan_get_paused(ch) === false);

    console.log(`PCM_TEST: failures = ${failures}`);
    console.log('PCM_TEST: COMPLETE');
    process.exit(failures ? 1 : 0);
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
