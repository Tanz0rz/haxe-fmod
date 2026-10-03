package haxefmod.core;

/*
 * The value enums of the built-in DSP effects. Each one is the set of
 * ints a particular effect parameter accepts through Dsp.setParameterInt
 * and reports through Dsp.getParameterInt. Values match the FMOD
 * headers (fmod_dsp_effects.h).
 */

/** FMOD_DSP_CHANNELMIX_OUTPUT, the CHANNELMIX unit's OUTPUTGROUPING parameter. */
enum abstract DspChannelMixOutput(Int) from Int to Int {
    var DEFAULT = 0;
    var ALLMONO = 1;
    var ALLSTEREO = 2;
    var ALLQUAD = 3;
    var ALL5POINT1 = 4;
    var ALL7POINT1 = 5;
    var ALLLFE = 6;
    var ALL7POINT1POINT4 = 7;
}

/** FMOD_DSP_ECHO_DELAYCHANGEMODE_TYPE, the ECHO unit's DELAYCHANGEMODE parameter. */
enum abstract DspEchoDelayChangeMode(Int) from Int to Int {
    var FADE = 0;
    var LERP = 1;
    var NONE = 2;
}

/** FMOD_DSP_FFT_DOWNMIX_TYPE, the FFT unit's DOWNMIX parameter. */
enum abstract DspFftDownmix(Int) from Int to Int {
    var NONE = 0;
    var MONO = 1;
}

/** FMOD_DSP_FFT_WINDOW_TYPE, the FFT unit's WINDOW parameter. */
enum abstract DspFftWindow(Int) from Int to Int {
    var RECT = 0;
    var TRIANGLE = 1;
    var HAMMING = 2;
    var HANNING = 3;
    var BLACKMAN = 4;
    var BLACKMANHARRIS = 5;
}

/** FMOD_DSP_LOUDNESS_METER_STATE_TYPE, the LOUDNESS_METER unit's STATE parameter. Negative values reset the meter. */
enum abstract DspLoudnessMeterState(Int) from Int to Int {
    var RESET_INTEGRATED = -3;
    var RESET_MAXPEAK = -2;
    var RESET_ALL = -1;
    var PAUSED = 0;
    var ANALYZING = 1;
}

/** FMOD_DSP_MULTIBAND_DYNAMICS_MODE_TYPE, the MODE parameter of each MULTIBAND_DYNAMICS band. */
enum abstract DspMultibandDynamicsMode(Int) from Int to Int {
    var DISABLED = 0;
    var COMPRESS_UP = 1;
    var COMPRESS_DOWN = 2;
    var EXPAND_UP = 3;
    var EXPAND_DOWN = 4;
}

/** FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE, the FILTER parameter of each MULTIBAND_EQ band. */
enum abstract DspMultibandEqFilter(Int) from Int to Int {
    var DISABLED = 0;
    var LOWPASS_12DB = 1;
    var LOWPASS_24DB = 2;
    var LOWPASS_48DB = 3;
    var HIGHPASS_12DB = 4;
    var HIGHPASS_24DB = 5;
    var HIGHPASS_48DB = 6;
    var LOWSHELF = 7;
    var HIGHSHELF = 8;
    var PEAKING = 9;
    var BANDPASS = 10;
    var NOTCH = 11;
    var ALLPASS = 12;
    var LOWPASS_6DB = 13;
    var HIGHPASS_6DB = 14;
}

/** FMOD_DSP_PAN_MODE_TYPE, the PAN unit's MODE parameter. */
enum abstract DspPanModeType(Int) from Int to Int {
    var MONO = 0;
    var STEREO = 1;
    var SURROUND = 2;
}

/** FMOD_DSP_PAN_2D_STEREO_MODE_TYPE, the PAN unit's 2D_STEREO_MODE parameter. */
enum abstract DspPan2DStereoModeType(Int) from Int to Int {
    var DISTRIBUTED = 0;
    var DISCRETE = 1;
}

/** FMOD_DSP_PAN_3D_ROLLOFF_TYPE, the PAN unit's 3D_ROLLOFF parameter. */
enum abstract DspPan3DRolloffType(Int) from Int to Int {
    var LINEARSQUARED = 0;
    var LINEAR = 1;
    var INVERSE = 2;
    var INVERSETAPERED = 3;
    var CUSTOM = 4;
}

/** FMOD_DSP_PAN_3D_EXTENT_MODE_TYPE, the PAN unit's 3D_EXTENT_MODE parameter. */
enum abstract DspPan3DExtentModeType(Int) from Int to Int {
    var AUTO = 0;
    var USER = 1;
    var OFF = 2;
}

/** FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_TYPE, the THREE_EQ unit's CROSSOVERSLOPE parameter. */
enum abstract DspThreeEqCrossoverSlope(Int) from Int to Int {
    var _12DB = 0;
    var _24DB = 1;
    var _48DB = 2;
}

/** FMOD_DSP_TRANSCEIVER_SPEAKERMODE, the TRANSCEIVER unit's TRANSMITSPEAKERMODE parameter. */
enum abstract DspTransceiverSpeakerMode(Int) from Int to Int {
    var AUTO = -1;
    var MONO = 0;
    var STEREO = 1;
    var SURROUND = 2;
}
