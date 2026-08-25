/**
 * DSP type translation shared by the haxefmod native shims.
 *
 * The binding's DspType values are a fixed contract (they match FMOD
 * 2.03.12's enum). FMOD renumbers FMOD_DSP_TYPE between releases: 2.02
 * still carries the removed plugin-loader entries and EnvelopeFollower,
 * shifting every value from COMPRESSOR onward. A raw integer cast into
 * an SDK with a different numbering therefore creates the WRONG EFFECT,
 * so the shims translate through the symbolic names, which the compiler
 * resolves to whatever the SDK at hand numbers them.
 *
 * Used by linc_faxe.cpp (C++) and hlaxe_fmod.c (C99). jaxe.js mirrors
 * the same translation against the JS glue's symbolic constants.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_DSPTYPE_H
#define FAXE_DSPTYPE_H

/* Both shims include the FMOD headers before this one. The conditionals
 * allow the unit test to point at a specific SDK's headers itself.
 * fmod_common.h supplies FMOD_VERSION, which the version guards below
 * depend on: an undefined FMOD_VERSION would silently compile the wrong
 * branch. */
#ifndef _FMOD_COMMON_H
#include "fmod_common.h"
#endif
#ifndef _FMOD_DSP_EFFECTS_H
#include "fmod_dsp_effects.h"
#endif
#ifndef FMOD_VERSION
#error "FMOD_VERSION is not defined - fmod_common.h did not load"
#endif

/* Sentinel for a binding value the compiled-against SDK has no effect
 * for (for example MULTIBAND_DYNAMICS on a 2.02 SDK). Callers must
 * check for it and report FMOD_ERR_INVALID_PARAM. */
#define FAXE_DSP_TYPE_UNSUPPORTED FMOD_DSP_TYPE_FORCEINT

/* Binding value (the 2.03-shaped contract) to this SDK's enum. */
static FMOD_DSP_TYPE faxe_dsp_type_from_binding(int type) {
    switch (type) {
        case 0:  return FMOD_DSP_TYPE_UNKNOWN;
        case 1:  return FMOD_DSP_TYPE_MIXER;
        case 2:  return FMOD_DSP_TYPE_OSCILLATOR;
        case 3:  return FMOD_DSP_TYPE_LOWPASS;
        case 4:  return FMOD_DSP_TYPE_ITLOWPASS;
        case 5:  return FMOD_DSP_TYPE_HIGHPASS;
        case 6:  return FMOD_DSP_TYPE_ECHO;
        case 7:  return FMOD_DSP_TYPE_FADER;
        case 8:  return FMOD_DSP_TYPE_FLANGE;
        case 9:  return FMOD_DSP_TYPE_DISTORTION;
        case 10: return FMOD_DSP_TYPE_NORMALIZE;
        case 11: return FMOD_DSP_TYPE_LIMITER;
        case 12: return FMOD_DSP_TYPE_PARAMEQ;
        case 13: return FMOD_DSP_TYPE_PITCHSHIFT;
        case 14: return FMOD_DSP_TYPE_CHORUS;
        case 15: return FMOD_DSP_TYPE_ITECHO;
        case 16: return FMOD_DSP_TYPE_COMPRESSOR;
        case 17: return FMOD_DSP_TYPE_SFXREVERB;
        case 18: return FMOD_DSP_TYPE_LOWPASS_SIMPLE;
        case 19: return FMOD_DSP_TYPE_DELAY;
        case 20: return FMOD_DSP_TYPE_TREMOLO;
        case 21: return FMOD_DSP_TYPE_SEND;
        case 22: return FMOD_DSP_TYPE_RETURN;
        case 23: return FMOD_DSP_TYPE_HIGHPASS_SIMPLE;
        case 24: return FMOD_DSP_TYPE_PAN;
        case 25: return FMOD_DSP_TYPE_THREE_EQ;
        case 26: return FMOD_DSP_TYPE_FFT;
        case 27: return FMOD_DSP_TYPE_LOUDNESS_METER;
        case 28: return FMOD_DSP_TYPE_CONVOLUTIONREVERB;
        case 29: return FMOD_DSP_TYPE_CHANNELMIX;
        case 30: return FMOD_DSP_TYPE_TRANSCEIVER;
        case 31: return FMOD_DSP_TYPE_OBJECTPAN;
        case 32: return FMOD_DSP_TYPE_MULTIBAND_EQ;
#if FMOD_VERSION >= 0x00020300
        case 33: return FMOD_DSP_TYPE_MULTIBAND_DYNAMICS;
#endif
        default: return FAXE_DSP_TYPE_UNSUPPORTED;
    }
}

/* This SDK's enum back to the binding value. SDK-specific entries the
 * binding has no name for (the 2.02 plugin loaders, EnvelopeFollower)
 * report 0 (UNKNOWN). */
static int faxe_dsp_type_to_binding(FMOD_DSP_TYPE type) {
    switch (type) {
        case FMOD_DSP_TYPE_UNKNOWN:          return 0;
        case FMOD_DSP_TYPE_MIXER:            return 1;
        case FMOD_DSP_TYPE_OSCILLATOR:       return 2;
        case FMOD_DSP_TYPE_LOWPASS:          return 3;
        case FMOD_DSP_TYPE_ITLOWPASS:        return 4;
        case FMOD_DSP_TYPE_HIGHPASS:         return 5;
        case FMOD_DSP_TYPE_ECHO:             return 6;
        case FMOD_DSP_TYPE_FADER:            return 7;
        case FMOD_DSP_TYPE_FLANGE:           return 8;
        case FMOD_DSP_TYPE_DISTORTION:       return 9;
        case FMOD_DSP_TYPE_NORMALIZE:        return 10;
        case FMOD_DSP_TYPE_LIMITER:          return 11;
        case FMOD_DSP_TYPE_PARAMEQ:          return 12;
        case FMOD_DSP_TYPE_PITCHSHIFT:       return 13;
        case FMOD_DSP_TYPE_CHORUS:           return 14;
        case FMOD_DSP_TYPE_ITECHO:           return 15;
        case FMOD_DSP_TYPE_COMPRESSOR:       return 16;
        case FMOD_DSP_TYPE_SFXREVERB:        return 17;
        case FMOD_DSP_TYPE_LOWPASS_SIMPLE:   return 18;
        case FMOD_DSP_TYPE_DELAY:            return 19;
        case FMOD_DSP_TYPE_TREMOLO:          return 20;
        case FMOD_DSP_TYPE_SEND:             return 21;
        case FMOD_DSP_TYPE_RETURN:           return 22;
        case FMOD_DSP_TYPE_HIGHPASS_SIMPLE:  return 23;
        case FMOD_DSP_TYPE_PAN:              return 24;
        case FMOD_DSP_TYPE_THREE_EQ:         return 25;
        case FMOD_DSP_TYPE_FFT:              return 26;
        case FMOD_DSP_TYPE_LOUDNESS_METER:   return 27;
        case FMOD_DSP_TYPE_CONVOLUTIONREVERB: return 28;
        case FMOD_DSP_TYPE_CHANNELMIX:       return 29;
        case FMOD_DSP_TYPE_TRANSCEIVER:      return 30;
        case FMOD_DSP_TYPE_OBJECTPAN:        return 31;
        case FMOD_DSP_TYPE_MULTIBAND_EQ:     return 32;
#if FMOD_VERSION >= 0x00020300
        case FMOD_DSP_TYPE_MULTIBAND_DYNAMICS: return 33;
#endif
        default: return 0;
    }
}

#endif /* FAXE_DSPTYPE_H */
