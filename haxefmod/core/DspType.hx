package haxefmod.core;

/**
 * The built-in FMOD DSP effect types, every one available on every
 * supported platform. Values match FMOD_DSP_TYPE in the FMOD headers.
 */
enum abstract DspType(Int) from Int to Int {
    var UNKNOWN = 0;
    var MIXER = 1;
    var OSCILLATOR = 2;
    var LOWPASS = 3;
    var ITLOWPASS = 4;
    var HIGHPASS = 5;
    var ECHO = 6;
    var FADER = 7;
    var FLANGE = 8;
    var DISTORTION = 9;
    var NORMALIZE = 10;
    var LIMITER = 11;
    var PARAMEQ = 12;
    var PITCHSHIFT = 13;
    var CHORUS = 14;
    var ITECHO = 15;
    var COMPRESSOR = 16;
    var SFXREVERB = 17;
    var LOWPASS_SIMPLE = 18;
    var DELAY = 19;
    var TREMOLO = 20;
    var SEND = 21;
    var RETURN = 22;
    var HIGHPASS_SIMPLE = 23;
    var PAN = 24;
    var THREE_EQ = 25;
    var FFT = 26;
    var LOUDNESS_METER = 27;
    var CONVOLUTIONREVERB = 28;
    var CHANNELMIX = 29;
    var TRANSCEIVER = 30;
    var OBJECTPAN = 31;
    var MULTIBAND_EQ = 32;
    var MULTIBAND_DYNAMICS = 33;
}
