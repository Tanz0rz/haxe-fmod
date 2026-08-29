// Runs the DSP data parameter bindings of jaxe.js against the real FMOD
// 2.03.12 wasm under Node: the unit description, the metering readback
// for both sides, the per channel FFT spectrum, the data parameter byte
// images the glue can type (overall gain, FFT) and the ones it cannot
// (loudness meter info), the packed 3D attribute setters, and the
// parameter descriptor texts, which embind cannot marshal and so report
// 68 (ERR_UNSUPPORTED), and the typed data parameter structs (sidechain,
// finite length, attenuation range, dynamic response, loudness weighting).
// Usage: node dspdata-harness.js  (needs FMOD_SDK_WEB)

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
    console.log(`DSPDATA_TEST: ${label} pass=${!!cond}${detail ? ' ' + detail : ''}`);
    if (!cond) {
        failures++;
        process.exitCode = 1;
    }
}

async function waitForInit() {
    const initResult = jaxe.fmod_sys_init_ex(64, 0, 0, 0, 512, 4, 40, 65536, 3);
    check('sys_init_ex', initResult === 0, `result=${initResult}`);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) {
        await new Promise(r => setTimeout(r, 50));
    }
    if (!jaxe.FmodIsInitialized) { console.log('DSPDATA_TEST: INIT TIMEOUT'); process.exit(1); }
}

function pump(n) {
    for (let i = 0; i < n; i++) jaxe.fmod_sys_update();
}

async function main() {
    await waitForInit();
    const master = jaxe.fmod_cg_get_master();
    const baseline = jaxe.fmod_debug_live_handle_count();
    const ibuf = new Array(1024).fill(7);
    const fbuf = new Array(1024).fill(0);

    // A 1 kHz oscillator feeds the analyzers a real signal
    const osc = jaxe.fmod_dsp_create_by_type(2 /* OSCILLATOR */);
    jaxe.fmod_dsp_set_param_int(osc, 0, 0);
    jaxe.fmod_dsp_set_param_float(osc, 1, 1000.0);
    const channel = jaxe.fmod_sys_play_dsp(osc, false);
    check('play_dsp', channel !== 0, `handle=${channel}`);

    const fft = jaxe.fmod_dsp_create_by_type(26 /* FFT */);
    check('cg_add_dsp_fft', jaxe.fmod_cg_add_dsp(master, 0, fft) === 0, '');
    check('dsp_set_metering_enabled', jaxe.fmod_dsp_set_metering_enabled(fft, true, true) === 0, '');
    // Before the mixer has run through the unit the glue reports zero
    // channels (its level arrays are always 32 long, so the count must
    // not fall back to their length)
    ibuf.fill(7);
    const unmixed = jaxe.fmod_dsp_get_metering_info(fft, false, fbuf, ibuf);
    check('dsp_get_metering_info_before_mix', unmixed === 0 && jaxe.fmod_sys_last_result() === 0 && ibuf[1] === 0,
        `channels=${unmixed} result=${jaxe.fmod_sys_last_result()}`);
    pump(40);

    // getInfo
    const name = jaxe.fmod_dsp_get_info(fft, ibuf);
    check('dsp_get_info', name === 'FMOD FFT' && jaxe.fmod_sys_last_result() === 0 && ibuf[0] > 0,
        `name=${name} version=${ibuf[0]} channels=${ibuf[1]} config=${ibuf[2]}x${ibuf[3]}`);
    ibuf.fill(7);
    check('dsp_get_info_stale', jaxe.fmod_dsp_get_info(999999, ibuf) === '' && jaxe.fmod_sys_last_result() === 30
        && ibuf[0] === 0 && ibuf[3] === 0, `result=${jaxe.fmod_sys_last_result()}`);

    // metering, both sides: a stereo mix reports two channels with real
    // levels on both, not the 32 slots the glue fills
    const outCh = jaxe.fmod_dsp_get_metering_info(fft, false, fbuf, ibuf);
    check('dsp_get_metering_info_output', outCh > 0 && outCh < 32 && ibuf[1] === outCh && ibuf[0] > 0 && fbuf[0] > 0.1
        && fbuf[outCh - 1] > 0.1 && fbuf[outCh] > 0.05,
        `channels=${outCh} samples=${ibuf[0]} peak=${fbuf[0]} rms=${fbuf[outCh]}`);
    const inCh = jaxe.fmod_dsp_get_metering_info(fft, true, fbuf, ibuf);
    check('dsp_get_metering_info_input', inCh > 0 && ibuf[1] === inCh && fbuf[0] > 0.1,
        `channels=${inCh} samples=${ibuf[0]} peak=${fbuf[0]}`);
    check('dsp_get_metering_legacy_agrees', jaxe.fmod_dsp_get_metering(fft, fbuf) === outCh, '');

    // per channel FFT spectrum
    fbuf.fill(0);
    const bins = jaxe.fmod_dsp_fft_get_spectrum_channel(fft, 0, fbuf, 64, ibuf);
    check('dsp_fft_get_spectrum_channel', bins === 64 && ibuf[0] >= 1 && ibuf[1] >= 64,
        `bins=${bins} channels=${ibuf[0]} length=${ibuf[1]}`);
    let energy = 0;
    for (let i = 0; i < bins; i++) energy += fbuf[i];
    check('dsp_fft_spectrum_has_energy', energy > 0, `sum=${energy}`);
    const numChannels = ibuf[0];
    check('dsp_fft_get_spectrum_channel_out_of_range', jaxe.fmod_dsp_fft_get_spectrum_channel(fft, numChannels, fbuf, 64, ibuf) === 0
        && ibuf[0] === numChannels, `channels=${ibuf[0]}`);
    check('dsp_fft_get_spectrum_legacy_agrees', jaxe.fmod_dsp_fft_get_spectrum(fft, fbuf, 64) === 64, '');

    // getParameterData images: the FFT block is 136 bytes on wasm32
    const lenOnly = jaxe.fmod_dsp_get_param_data(fft, 4, null, 0);
    check('dsp_get_param_data_fft_length', lenOnly === 136, `length=${lenOnly}`);
    const image = new ArrayBuffer(136);
    check('dsp_get_param_data_fft_copy', jaxe.fmod_dsp_get_param_data(fft, 4, image, 136) === 136, '');
    const view = new DataView(image);
    check('dsp_get_param_data_fft_fields', view.getInt32(0, true) === ibuf[1] && view.getInt32(4, true) === numChannels,
        `length=${view.getInt32(0, true)} channels=${view.getInt32(4, true)}`);
    // a float parameter has no data block
    check('dsp_get_param_data_float_param', jaxe.fmod_dsp_get_param_data(fft, 2, null, 0) === -1
        && jaxe.fmod_sys_last_result() !== 0, `result=${jaxe.fmod_sys_last_result()}`);

    // overall gain on a fader: linear_gain 1, additive 0
    const fader = jaxe.fmod_dsp_create_by_type(7 /* FADER */);
    const gainIndex = jaxe.fmod_dsp_get_data_parameter_index(fader, -1);
    check('dsp_get_data_parameter_index_overallgain', gainIndex >= 0, `index=${gainIndex}`);
    const gainImage = new ArrayBuffer(8);
    const gainLen = jaxe.fmod_dsp_get_param_data(fader, gainIndex, gainImage, 8);
    const gainView = new DataView(gainImage);
    check('dsp_get_param_data_overallgain', gainLen === 8 && Math.abs(gainView.getFloat32(0, true) - 1) < 0.001
        && gainView.getFloat32(4, true) === 0, `length=${gainLen} gain=${gainView.getFloat32(0, true)}`);

    // loudness meter info: the glue returns the block without fields
    const loud = jaxe.fmod_dsp_create_by_type(27 /* LOUDNESS_METER */);
    check('cg_add_dsp_loudness', jaxe.fmod_cg_add_dsp(master, 0, loud) === 0, '');
    pump(40);
    check('dsp_get_param_data_loudness_unsupported', jaxe.fmod_dsp_get_param_data(loud, 2, null, 0) === -1
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);

    // 3D attributes on a pan unit, the multi form is its 3D position
    const pan = jaxe.fmod_dsp_create_by_type(24 /* PAN */);
    const multiIndex = jaxe.fmod_dsp_get_data_parameter_index(pan, -5);
    check('dsp_get_data_parameter_index_3d_multi', multiIndex >= 0, `index=${multiIndex}`);
    fbuf.fill(0);
    // relative[0] at 1,2,3 facing +z, weight 1, absolute at 7,8,9
    [1, 2, 3, 0, 0, 0, 0, 0, 1, 0, 1, 0].forEach((v, i) => { fbuf[i] = v; });
    fbuf[96] = 1.0;
    [7, 8, 9, 0, 0, 0, 0, 0, 1, 0, 1, 0].forEach((v, i) => { fbuf[104 + i] = v; });
    check('dsp_set_param_3d_attributes_multi', jaxe.fmod_dsp_set_param_3d_attributes_multi(pan, multiIndex, 1, fbuf) === 0,
        `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_set_param_3d_attributes_multi_zero_listeners', jaxe.fmod_dsp_set_param_3d_attributes_multi(pan, multiIndex, 0, fbuf) === 31, '');
    check('dsp_set_param_3d_attributes_multi_too_many', jaxe.fmod_dsp_set_param_3d_attributes_multi(pan, multiIndex, 9, fbuf) === 31, '');
    // the single form on a parameter that wants the multi struct is a size mismatch
    const single = jaxe.fmod_dsp_set_param_3d_attributes(pan, multiIndex, fbuf);
    check('dsp_set_param_3d_attributes_wrong_size', single !== 0, `result=${single}`);
    check('dsp_set_param_3d_attributes_stale', jaxe.fmod_dsp_set_param_3d_attributes(999999, 0, fbuf) === 30, '');

    // typed data parameters: the compressor's sidechain switch round trips
    const compressor = jaxe.fmod_dsp_create_by_type(16 /* COMPRESSOR */);
    const sidechainIndex = jaxe.fmod_dsp_get_data_parameter_index(compressor, -3);
    check('dsp_get_data_parameter_index_sidechain', sidechainIndex === 5, `index=${sidechainIndex}`);
    fbuf.fill(0);
    fbuf[0] = 1;
    check('dsp_set_param_typed_sidechain', jaxe.fmod_dsp_set_param_typed(compressor, sidechainIndex, 1, fbuf, ibuf) === 0,
        `result=${jaxe.fmod_sys_last_result()}`);
    fbuf.fill(9);
    check('dsp_get_param_typed_sidechain', jaxe.fmod_dsp_get_param_typed(compressor, sidechainIndex, 1, fbuf, ibuf) === 0 && fbuf[0] === 1,
        `result=${jaxe.fmod_sys_last_result()} enable=${fbuf[0]}`);
    fbuf.fill(0);
    check('dsp_set_param_typed_sidechain_off', jaxe.fmod_dsp_set_param_typed(compressor, sidechainIndex, 1, fbuf, ibuf) === 0
        && jaxe.fmod_dsp_get_param_typed(compressor, sidechainIndex, 1, fbuf, ibuf) === 0 && fbuf[0] === 0, `enable=${fbuf[0]}`);
    // the pan units take an attenuation range but do not hand it back
    const rangeIndex = jaxe.fmod_dsp_get_data_parameter_index(pan, -6);
    fbuf[0] = 1.5;
    fbuf[1] = 250;
    check('dsp_set_param_typed_attenuation_range', rangeIndex >= 0 && jaxe.fmod_dsp_set_param_typed(pan, rangeIndex, 3, fbuf, ibuf) === 0,
        `index=${rangeIndex} result=${jaxe.fmod_sys_last_result()}`);
    const rangeBack = jaxe.fmod_dsp_get_param_typed(pan, rangeIndex, 3, fbuf, ibuf);
    check('dsp_get_param_typed_attenuation_range_refused', rangeBack !== 0 && fbuf[0] === 0, `result=${rangeBack}`);
    // the glue does not type the loudness weighting, the setter still writes it
    fbuf.fill(0);
    fbuf[0] = 0.5;
    check('dsp_set_param_typed_loudness_weighting', jaxe.fmod_dsp_set_param_typed(loud, 1, 5, fbuf, ibuf) === 0,
        `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_get_param_typed_loudness_weighting_unsupported', jaxe.fmod_dsp_get_param_typed(loud, 1, 5, fbuf, ibuf) === 68, '');
    // a finite length struct is the same four byte FMOD_BOOL block, it lands on the sidechain
    // switch and reads back through either kind (the glue types the object as a sidechain)
    fbuf[0] = 1;
    check('dsp_set_param_typed_finite_length', jaxe.fmod_dsp_set_param_typed(compressor, sidechainIndex, 2, fbuf, ibuf) === 0
        && jaxe.fmod_dsp_get_param_typed(compressor, sidechainIndex, 1, fbuf, ibuf) === 0 && fbuf[0] === 1, `enable=${fbuf[0]}`);
    fbuf[0] = 0;
    check('dsp_get_param_typed_finite_length_round_trip', jaxe.fmod_dsp_get_param_typed(compressor, sidechainIndex, 2, fbuf, ibuf) === 0
        && fbuf[0] === 1, `finite=${fbuf[0]} result=${jaxe.fmod_sys_last_result()}`);
    fbuf[0] = 0;
    check('dsp_set_param_typed_finite_length_off', jaxe.fmod_dsp_set_param_typed(compressor, sidechainIndex, 2, fbuf, ibuf) === 0
        && jaxe.fmod_dsp_get_param_typed(compressor, sidechainIndex, 2, fbuf, ibuf) === 0 && fbuf[0] === 0, `finite=${fbuf[0]}`);
    // the overall gain block is too short for a dynamic response
    check('dsp_get_param_typed_dynamic_response_wrong_block', jaxe.fmod_dsp_get_param_typed(fader, gainIndex, 4, fbuf, ibuf) === 31
        && ibuf[0] === 0, `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_set_param_typed_unknown_kind', jaxe.fmod_dsp_set_param_typed(compressor, sidechainIndex, 99, fbuf, ibuf) === 31, '');
    check('dsp_get_param_typed_unknown_kind', jaxe.fmod_dsp_get_param_typed(compressor, sidechainIndex, 99, fbuf, ibuf) === 31, '');
    check('dsp_set_param_typed_stale', jaxe.fmod_dsp_set_param_typed(999999, 0, 1, fbuf, ibuf) === 30, '');
    check('dsp_get_param_typed_stale', jaxe.fmod_dsp_get_param_typed(999999, 0, 1, fbuf, ibuf) === 30, '');

    // the descriptor never comes back on the web
    ibuf.fill(7);
    check('dsp_get_parameter_text_unsupported', jaxe.fmod_dsp_get_parameter_text(fft, 0, 0) === ''
        && jaxe.fmod_sys_last_result() === 68, `result=${jaxe.fmod_sys_last_result()}`);
    check('dsp_get_parameter_info_unsupported', jaxe.fmod_dsp_get_parameter_info(fft, 0, fbuf, ibuf) === ''
        && jaxe.fmod_sys_last_result() === 68 && ibuf[4] === 0, `result=${jaxe.fmod_sys_last_result()}`);

    jaxe.fmod_chan_stop(channel);
    check('cg_remove_dsp_fft', jaxe.fmod_cg_remove_dsp(master, fft) === 0, '');
    check('cg_remove_dsp_loudness', jaxe.fmod_cg_remove_dsp(master, loud) === 0, '');
    jaxe.fmod_dsp_release(fft);
    jaxe.fmod_dsp_release(loud);
    jaxe.fmod_dsp_release(fader);
    jaxe.fmod_dsp_release(pan);
    jaxe.fmod_dsp_release(osc);
    jaxe.fmod_dsp_release(compressor);
    pump(5);

    check('no_handle_leaks_dspdata', jaxe.fmod_debug_live_handle_count() === baseline,
        `baseline=${baseline} now=${jaxe.fmod_debug_live_handle_count()}`);

    console.log(`DSPDATA_TEST: failures = ${failures}`);
    console.log('DSPDATA_TEST: COMPLETE' + (failures ? ' (WITH FAILURES)' : ''));
    process.exit(failures ? 1 : 0);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
