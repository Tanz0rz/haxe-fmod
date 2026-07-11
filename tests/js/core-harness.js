// Prototype rig for the Core dynamic-audio surface, run against the real
// FMOD 2.03.12 wasm build under Node. This is the phase-1 gate for the Core
// bindings: it has to prove the embind surface actually behaves (created
// sounds play, the pcmread callback fires with sane sizes, channels respond,
// DSP types exist) before any Haxe API gets designed around it.
// Usage: node core-harness.js  (needs FMOD_SDK_WEB)

const path = require('path');
const fs = require('fs');

if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');

global.window = {
    location: { pathname: '/game/index.html' },
    setInterval: setInterval,
    clearInterval: clearInterval,
};
global.document = { addEventListener: function () {} };
const FMODModule = require(path.join(SDK, 'fmodstudio.js'));

let failures = 0;
function check(label, cond, detail) {
    console.log(`CORE_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}
function info(label, detail) {
    console.log(`CORE_TEST: ${label} info=${detail}`);
}

const FMOD = {};
FMOD['onRuntimeInitialized'] = main;
FMODModule(FMOD);

let gCore = null;

function ok(r, what) {
    if (r !== FMOD.OK) throw new Error(`${what} -> FMOD result ${r}`);
    return r;
}

function main() {
    try {
        const out = {};
        ok(FMOD.Studio_System_Create(out), 'Studio_System_Create');
        const studio = out.val;
        ok(studio.getCoreSystem(out), 'getCoreSystem');
        gCore = out.val;
        ok(gCore.setOutput(FMOD.OUTPUTTYPE_NOSOUND_NRT), 'setOutput NRT');
        ok(studio.initialize(256, FMOD.STUDIO_INIT_NORMAL, FMOD.INIT_NORMAL, null), 'initialize');
        check('boot', true);

        testOpenUserPcmRead(studio);
        testChannelControl(studio);
        testDspEnumeration();

        console.log(`CORE_TEST: failures = ${failures}`);
        console.log('CORE_TEST: COMPLETE');
        process.exit(failures ? 1 : 0);
    } catch (e) {
        console.log(`CORE_TEST: FATAL ${e.message}`);
        process.exit(1);
    }
}

// Pump the NRT mixer. With NOSOUND_NRT every update consumes mix blocks as
// fast as it can, so pcmread demand is driven synchronously from here.
function pump(studio, times) {
    for (let i = 0; i < times; i++) studio.update();
}

//// OPENUSER + pcmread: stream a generated sine and prove the mixer pulls it

function testOpenUserPcmRead(studio) {
    const SAMPLE_RATE = 48000;
    const CHANNELS = 1;
    let readCalls = 0;
    let bytesServed = 0;
    let badLengths = 0;
    let phase = 0;

    // 16-bit PCM sine at 440Hz, written straight into the wasm heap
    const pcmread = function (sound, data, datalen) {
        readCalls++;
        bytesServed += datalen;
        if (datalen <= 0 || (datalen % 2) !== 0) badLengths++;
        const samples = datalen >> 1;
        for (let i = 0; i < samples; i++) {
            const v = Math.round(Math.sin(phase) * 0x6000);
            FMOD.setValue(data + i * 2, v, 'i16');
            phase += 2 * Math.PI * 440 / SAMPLE_RATE;
        }
        return FMOD.OK;
    };

    const exinfo = FMOD.CREATESOUNDEXINFO();
    exinfo.numchannels = CHANNELS;
    exinfo.defaultfrequency = SAMPLE_RATE;
    exinfo.format = FMOD.SOUND_FORMAT_PCM16;
    exinfo.decodebuffersize = 4096;
    exinfo.length = SAMPLE_RATE * 2; // one second of 16-bit mono
    exinfo.pcmreadcallback = pcmread;

    const out = {};
    const r = gCore.createSound('', FMOD.OPENUSER | FMOD.LOOP_NORMAL | FMOD.CREATESTREAM, exinfo, out);
    check('openuser_create', r === FMOD.OK, `result=${r}`);
    if (r !== FMOD.OK) return;
    const sound = out.val;

    const chOut = {};
    const pr = gCore.playSound(sound, null, false, chOut);
    check('openuser_play', pr === FMOD.OK, `result=${pr}`);
    const channel = chOut.val;

    pump(studio, 30);
    check('pcmread_fires', readCalls > 0, `calls=${readCalls} bytes=${bytesServed}`);
    check('pcmread_lengths_sane', badLengths === 0, `bad=${badLengths}`);

    const playingOut = {};
    channel.isPlaying(playingOut);
    check('openuser_channel_playing', playingOut.val === true, `playing=${playingOut.val}`);

    // Keep pulling: a looping stream must keep demanding data
    const callsBefore = readCalls;
    pump(studio, 30);
    check('pcmread_streams_continuously', readCalls > callsBefore,
        `before=${callsBefore} after=${readCalls}`);

    check('openuser_stop', channel.stop() === FMOD.OK);
    check('openuser_release', sound.release() === FMOD.OK);
    pump(studio, 5);

    // The module must survive create/play/stop/release with a JS callback
    // installed (the html5 lesson: exercise it, do not trust the symbol)
    const out2 = {};
    const r2 = gCore.createSound('', FMOD.OPENUSER | FMOD.LOOP_NORMAL | FMOD.CREATESTREAM, exinfo, out2);
    check('openuser_recreate_after_release', r2 === FMOD.OK, `result=${r2}`);
    if (r2 === FMOD.OK) out2.val.release();
}

//// Channel control round-trips on a fresh OPENUSER sound

function testChannelControl(studio) {
    const exinfo = FMOD.CREATESOUNDEXINFO();
    exinfo.numchannels = 1;
    exinfo.defaultfrequency = 48000;
    exinfo.format = FMOD.SOUND_FORMAT_PCM16;
    exinfo.decodebuffersize = 4096;
    exinfo.length = 48000 * 2;
    exinfo.pcmreadcallback = function (sound, data, datalen) {
        const samples = datalen >> 1;
        for (let i = 0; i < samples; i++) FMOD.setValue(data + i * 2, 0, 'i16');
        return FMOD.OK;
    };

    const out = {};
    if (gCore.createSound('', FMOD.OPENUSER | FMOD.LOOP_NORMAL | FMOD.CREATESTREAM, exinfo, out) !== FMOD.OK) {
        check('channel_setup', false, 'createSound failed');
        return;
    }
    const sound = out.val;
    const chOut = {};
    gCore.playSound(sound, null, true, chOut); // start paused
    const ch = chOut.val;

    const f = {};
    check('channel_set_volume', ch.setVolume(0.5) === FMOD.OK);
    ch.getVolume(f);
    check('channel_get_volume', Math.abs(f.val - 0.5) < 0.001, `value=${f.val}`);

    check('channel_set_pitch', ch.setPitch(1.5) === FMOD.OK);
    ch.getPitch(f);
    check('channel_get_pitch', Math.abs(f.val - 1.5) < 0.001, `value=${f.val}`);

    const b = {};
    ch.getPaused(b);
    check('channel_starts_paused', b.val === true, `paused=${b.val}`);
    check('channel_unpause', ch.setPaused(false) === FMOD.OK);
    pump(studio, 10);
    ch.getPaused(b);
    check('channel_unpaused', b.val === false, `paused=${b.val}`);

    // Master channel group is the attach point for slice-2 bus-level DSPs
    const grpOut = {};
    check('master_channelgroup', gCore.getMasterChannelGroup(grpOut) === FMOD.OK);

    check('channel_stop', ch.stop() === FMOD.OK);
    pump(studio, 5);

    // A stopped channel handle must fail with a channel error, not throw
    let stale;
    try {
        stale = ch.setVolume(1.0);
        check('stale_channel_errors', stale !== FMOD.OK, `result=${stale}`);
    } catch (e) {
        check('stale_channel_errors', false, `THREW ${e.message}`);
    }

    sound.release();
    pump(studio, 5);
}

//// DSP type enumeration: the golden list defines what slice 2 may bind

function testDspEnumeration() {
    // FMOD_DSP_TYPE from the 2.03.12 SDK's own fmod_dsp_effects.h: a
    // contiguous enum. The 1.x-era plugin host types no longer exist.
    const DSP_TYPES = {
        MIXER: 1, OSCILLATOR: 2, LOWPASS: 3, ITLOWPASS: 4, HIGHPASS: 5,
        ECHO: 6, FADER: 7, FLANGE: 8, DISTORTION: 9, NORMALIZE: 10,
        LIMITER: 11, PARAMEQ: 12, PITCHSHIFT: 13, CHORUS: 14, ITECHO: 15,
        COMPRESSOR: 16, SFXREVERB: 17, LOWPASS_SIMPLE: 18, DELAY: 19,
        TREMOLO: 20, SEND: 21, RETURN: 22, HIGHPASS_SIMPLE: 23, PAN: 24,
        THREE_EQ: 25, FFT: 26, LOUDNESS_METER: 27, CONVOLUTIONREVERB: 28,
        CHANNELMIX: 29, TRANSCEIVER: 30, OBJECTPAN: 31, MULTIBAND_EQ: 32,
        MULTIBAND_DYNAMICS: 33,
    };

    const supported = [];
    for (const [name, type] of Object.entries(DSP_TYPES)) {
        const out = {};
        let r;
        try {
            r = gCore.createDSPByType(type, out);
        } catch (e) {
            r = `THREW ${e.constructor.name}`;
        }
        if (r === FMOD.OK) {
            supported.push(name);
            out.val.release();
        } else {
            info(`dsp_unsupported_${name}`, `result=${r}`);
        }
    }
    info('dsp_supported', supported.join(','));

    // Frozen from the verified 2.03.12 run: every type in the enum is
    // supported by the wasm build. A diff here means the FMOD web build
    // changed what it ships, which changes what the Core bindings may
    // expose on html5.
    const GOLDEN = 'MIXER,OSCILLATOR,LOWPASS,ITLOWPASS,HIGHPASS,ECHO,FADER,FLANGE,'
        + 'DISTORTION,NORMALIZE,LIMITER,PARAMEQ,PITCHSHIFT,CHORUS,ITECHO,'
        + 'COMPRESSOR,SFXREVERB,LOWPASS_SIMPLE,DELAY,TREMOLO,SEND,RETURN,'
        + 'HIGHPASS_SIMPLE,PAN,THREE_EQ,FFT,LOUDNESS_METER,CONVOLUTIONREVERB,'
        + 'CHANNELMIX,TRANSCEIVER,OBJECTPAN,MULTIBAND_EQ,MULTIBAND_DYNAMICS';
    check('dsp_golden_list', supported.join(',') === GOLDEN, supported.join(','));

    // Round-trip a lowpass cutoff to prove DSP parameters work. Note:
    // getParameterInfo is NOT usable on html5 (embind has no binding for
    // FMOD_DSP_PARAMETER_DESC), so parameter metadata is native-only.
    const out = {};
    if (gCore.createDSPByType(DSP_TYPES.LOWPASS_SIMPLE, out) === FMOD.OK) {
        const dsp = out.val;
        const set = dsp.setParameterFloat(0, 2000.0); // 0 = cutoff, 10..22000 Hz
        const f = {};
        // embind drops the valuestr length arg: (index, valueOut, valuestrOut)
        const get = dsp.getParameterFloat(0, f, null);
        check('dsp_param_roundtrip', set === FMOD.OK && get === FMOD.OK && Math.abs(f.val - 2000.0) < 1,
            `set=${set} get=${get} value=${f && f.val}`);
        dsp.release();
    } else {
        check('dsp_param_roundtrip', false, 'lowpass_simple unavailable');
    }
}
