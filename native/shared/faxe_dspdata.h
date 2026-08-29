/**
 * DSP data parameter packing shared by the haxefmod native shims.
 *
 * The Haxe side never lays out an FMOD struct byte by byte. It hands the
 * shims flat double arrays (the same Scratch float buffer the 3D
 * attribute setters use) and the helpers here build the FMOD structs,
 * so linc_faxe.cpp (C++) and hlaxe_fmod.c (C99) agree on every layout.
 * jaxe.js writes the same byte images with a DataView, because the web
 * glue takes data parameters as raw bytes.
 *
 * Flat layouts, one FMOD_3D_ATTRIBUTES per 12 doubles in the order
 * position xyz, velocity xyz, forward xyz, up xyz:
 *   FMOD_DSP_PARAMETER_3DATTRIBUTES        f[0..11] relative, f[12..23] absolute
 *   FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI  f[0..95] relative[8], f[96..103]
 *                                          weight[8], f[104..115] absolute
 *   FMOD_DSP_METERING_INFO                 f[0..ch-1] peak, f[ch..2ch-1] rms,
 *                                          i[0] numsamples, i[1] numchannels
 *   FMOD_DSP_PARAMETER_DESC                f[0] min, f[1] max, f[2] default,
 *                                          i[0] type, i[1] float mapping type,
 *                                          i[2] int goes to infinity,
 *                                          i[3] data type, i[4] mapping point
 *                                          count n, f[3..3+n) point values,
 *                                          f[3+n..3+2n) point positions
 *
 * Typed data parameters go through faxe_dspdata_pack_typed and
 * faxe_dspdata_unpack_typed under a FAXE_DSPDATA_KIND_* number:
 *   FMOD_DSP_PARAMETER_SIDECHAIN           f[0] sidechainenable (nonzero true)
 *   FMOD_DSP_PARAMETER_FINITE_LENGTH       f[0] finite
 *   FMOD_DSP_PARAMETER_ATTENUATION_RANGE   f[0] min, f[1] max
 *   FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE    i[0] numchannels, f[0..31] rms
 *   FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE f[0..31] channelweight
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_DSPDATA_H
#define FAXE_DSPDATA_H

#include <string.h>
/* Both shims include the FMOD headers before this one. The guards let
 * the unit test point at an SDK's headers itself. */
#ifndef _FMOD_COMMON_H
#include "fmod_common.h"
/* Builds the struct of kind from the flat image (f holds
 * FAXE_DSPDATA_TYPED_DOUBLES values, i FAXE_DSPDATA_TYPED_INTS). Returns
 * the byte size to hand FMOD, 0 for a kind it does not know. */
static unsigned int faxe_dspdata_pack_typed(int kind, faxe_dspdata_typed* out, const double* f, const int* i) {
    int n;
    memset(out, 0, sizeof(*out));
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        out->sidechain.sidechainenable = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->sidechain);
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        out->finiteLength.finite = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->finiteLength);
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        out->attenuationRange.min = (float)f[0];
        out->attenuationRange.max = (float)f[1];
        return (unsigned int)sizeof(out->attenuationRange);
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = i[0];
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        out->dynamicResponse.numchannels = n;
        for (n = 0; n < out->dynamicResponse.numchannels; n++) out->dynamicResponse.rms[n] = (float)f[n];
        return (unsigned int)sizeof(out->dynamicResponse);
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) out->loudnessWeighting.channelweight[n] = (float)f[n];
        return (unsigned int)sizeof(out->loudnessWeighting);
    default:
        return 0;
    }
}

/* Reads a block FMOD returned as kind into the flat image. Returns 0
 * when the kind is unknown or the block is shorter than the struct, the
 * image is then zeroed. */
static int faxe_dspdata_unpack_typed(int kind, const void* data, unsigned int len, double* f, int* i) {
    faxe_dspdata_typed in;
    unsigned int need = 0;
    int n;
    for (n = 0; n < FAXE_DSPDATA_TYPED_DOUBLES; n++) f[n] = 0.0;
    for (n = 0; n < FAXE_DSPDATA_TYPED_INTS; n++) i[n] = 0;
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN: need = (unsigned int)sizeof(in.sidechain); break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH: need = (unsigned int)sizeof(in.finiteLength); break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE: need = (unsigned int)sizeof(in.attenuationRange); break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE: need = (unsigned int)sizeof(in.dynamicResponse); break;
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING: need = (unsigned int)sizeof(in.loudnessWeighting); break;
    default: return 0;
    }
    if (!data || len < need) return 0;
    memcpy(&in, data, need);
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        f[0] = in.sidechain.sidechainenable ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        f[0] = in.finiteLength.finite ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        f[0] = (double)in.attenuationRange.min;
        f[1] = (double)in.attenuationRange.max;
        break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = in.dynamicResponse.numchannels;
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        i[0] = n;
        for (n = 0; n < i[0]; n++) f[n] = (double)in.dynamicResponse.rms[n];
        break;
    default:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) f[n] = (double)in.loudnessWeighting.channelweight[n];
        break;
    }
    return 1;
}

#endif
#ifndef _FMOD_DSP_H
#include "fmod_dsp.h"
/* Builds the struct of kind from the flat image (f holds
 * FAXE_DSPDATA_TYPED_DOUBLES values, i FAXE_DSPDATA_TYPED_INTS). Returns
 * the byte size to hand FMOD, 0 for a kind it does not know. */
static unsigned int faxe_dspdata_pack_typed(int kind, faxe_dspdata_typed* out, const double* f, const int* i) {
    int n;
    memset(out, 0, sizeof(*out));
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        out->sidechain.sidechainenable = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->sidechain);
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        out->finiteLength.finite = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->finiteLength);
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        out->attenuationRange.min = (float)f[0];
        out->attenuationRange.max = (float)f[1];
        return (unsigned int)sizeof(out->attenuationRange);
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = i[0];
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        out->dynamicResponse.numchannels = n;
        for (n = 0; n < out->dynamicResponse.numchannels; n++) out->dynamicResponse.rms[n] = (float)f[n];
        return (unsigned int)sizeof(out->dynamicResponse);
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) out->loudnessWeighting.channelweight[n] = (float)f[n];
        return (unsigned int)sizeof(out->loudnessWeighting);
    default:
        return 0;
    }
}

/* Reads a block FMOD returned as kind into the flat image. Returns 0
 * when the kind is unknown or the block is shorter than the struct, the
 * image is then zeroed. */
static int faxe_dspdata_unpack_typed(int kind, const void* data, unsigned int len, double* f, int* i) {
    faxe_dspdata_typed in;
    unsigned int need = 0;
    int n;
    for (n = 0; n < FAXE_DSPDATA_TYPED_DOUBLES; n++) f[n] = 0.0;
    for (n = 0; n < FAXE_DSPDATA_TYPED_INTS; n++) i[n] = 0;
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN: need = (unsigned int)sizeof(in.sidechain); break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH: need = (unsigned int)sizeof(in.finiteLength); break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE: need = (unsigned int)sizeof(in.attenuationRange); break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE: need = (unsigned int)sizeof(in.dynamicResponse); break;
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING: need = (unsigned int)sizeof(in.loudnessWeighting); break;
    default: return 0;
    }
    if (!data || len < need) return 0;
    memcpy(&in, data, need);
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        f[0] = in.sidechain.sidechainenable ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        f[0] = in.finiteLength.finite ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        f[0] = (double)in.attenuationRange.min;
        f[1] = (double)in.attenuationRange.max;
        break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = in.dynamicResponse.numchannels;
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        i[0] = n;
        for (n = 0; n < i[0]; n++) f[n] = (double)in.dynamicResponse.rms[n];
        break;
    default:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) f[n] = (double)in.loudnessWeighting.channelweight[n];
        break;
    }
    return 1;
}

#endif
#ifndef _FMOD_DSP_EFFECTS_H
#include "fmod_dsp_effects.h"
/* Builds the struct of kind from the flat image (f holds
 * FAXE_DSPDATA_TYPED_DOUBLES values, i FAXE_DSPDATA_TYPED_INTS). Returns
 * the byte size to hand FMOD, 0 for a kind it does not know. */
static unsigned int faxe_dspdata_pack_typed(int kind, faxe_dspdata_typed* out, const double* f, const int* i) {
    int n;
    memset(out, 0, sizeof(*out));
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        out->sidechain.sidechainenable = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->sidechain);
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        out->finiteLength.finite = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->finiteLength);
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        out->attenuationRange.min = (float)f[0];
        out->attenuationRange.max = (float)f[1];
        return (unsigned int)sizeof(out->attenuationRange);
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = i[0];
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        out->dynamicResponse.numchannels = n;
        for (n = 0; n < out->dynamicResponse.numchannels; n++) out->dynamicResponse.rms[n] = (float)f[n];
        return (unsigned int)sizeof(out->dynamicResponse);
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) out->loudnessWeighting.channelweight[n] = (float)f[n];
        return (unsigned int)sizeof(out->loudnessWeighting);
    default:
        return 0;
    }
}

/* Reads a block FMOD returned as kind into the flat image. Returns 0
 * when the kind is unknown or the block is shorter than the struct, the
 * image is then zeroed. */
static int faxe_dspdata_unpack_typed(int kind, const void* data, unsigned int len, double* f, int* i) {
    faxe_dspdata_typed in;
    unsigned int need = 0;
    int n;
    for (n = 0; n < FAXE_DSPDATA_TYPED_DOUBLES; n++) f[n] = 0.0;
    for (n = 0; n < FAXE_DSPDATA_TYPED_INTS; n++) i[n] = 0;
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN: need = (unsigned int)sizeof(in.sidechain); break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH: need = (unsigned int)sizeof(in.finiteLength); break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE: need = (unsigned int)sizeof(in.attenuationRange); break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE: need = (unsigned int)sizeof(in.dynamicResponse); break;
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING: need = (unsigned int)sizeof(in.loudnessWeighting); break;
    default: return 0;
    }
    if (!data || len < need) return 0;
    memcpy(&in, data, need);
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        f[0] = in.sidechain.sidechainenable ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        f[0] = in.finiteLength.finite ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        f[0] = (double)in.attenuationRange.min;
        f[1] = (double)in.attenuationRange.max;
        break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = in.dynamicResponse.numchannels;
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        i[0] = n;
        for (n = 0; n < i[0]; n++) f[n] = (double)in.dynamicResponse.rms[n];
        break;
    default:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) f[n] = (double)in.loudnessWeighting.channelweight[n];
        break;
    }
    return 1;
}

#endif

#define FAXE_DSPDATA_ATTR_DOUBLES 12
#define FAXE_DSPDATA_SINGLE_DOUBLES (2 * FAXE_DSPDATA_ATTR_DOUBLES)
#define FAXE_DSPDATA_MULTI_DOUBLES (FMOD_MAX_LISTENERS * FAXE_DSPDATA_ATTR_DOUBLES + FMOD_MAX_LISTENERS + FAXE_DSPDATA_ATTR_DOUBLES)
#define FAXE_DSPDATA_MULTI_WEIGHT_OFFSET (FMOD_MAX_LISTENERS * FAXE_DSPDATA_ATTR_DOUBLES)
#define FAXE_DSPDATA_MULTI_ABSOLUTE_OFFSET (FAXE_DSPDATA_MULTI_WEIGHT_OFFSET + FMOD_MAX_LISTENERS)
#define FAXE_DSPDATA_DESC_FLOATS 3
#define FAXE_DSPDATA_DESC_INTS 5
#define FAXE_DSPDATA_MAX_MAPPING_POINTS 64
#define FAXE_DSPDATA_KIND_SIDECHAIN 1
#define FAXE_DSPDATA_KIND_FINITE_LENGTH 2
#define FAXE_DSPDATA_KIND_ATTENUATION_RANGE 3
#define FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE 4
#define FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING 5
#define FAXE_DSPDATA_CHANNEL_SLOTS 32
#define FAXE_DSPDATA_TYPED_DOUBLES FAXE_DSPDATA_CHANNEL_SLOTS
#define FAXE_DSPDATA_TYPED_INTS 1

#if FMOD_VERSION >= 0x00020300
typedef FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE faxe_dspdata_dynamic_response;
typedef FMOD_DSP_PARAMETER_FINITE_LENGTH faxe_dspdata_finite_length;
#else
/* FMOD 2.02 has neither data parameter, the 2.03 layouts stand in so the
 * kinds still pack and a 2.03 plugin loaded into 2.02 reads them. */
typedef struct faxe_dspdata_dynamic_response { int numchannels; float rms[FAXE_DSPDATA_CHANNEL_SLOTS]; } faxe_dspdata_dynamic_response;
typedef struct faxe_dspdata_finite_length { FMOD_BOOL finite; } faxe_dspdata_finite_length;
#endif

typedef union faxe_dspdata_typed {
    FMOD_DSP_PARAMETER_SIDECHAIN sidechain;
    faxe_dspdata_finite_length finiteLength;
    FMOD_DSP_PARAMETER_ATTENUATION_RANGE attenuationRange;
    faxe_dspdata_dynamic_response dynamicResponse;
    FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE loudnessWeighting;
} faxe_dspdata_typed;

static void faxe_dspdata_read_attributes(FMOD_3D_ATTRIBUTES* out, const double* f) {
    out->position.x = (float)f[0]; out->position.y = (float)f[1]; out->position.z = (float)f[2];
    out->velocity.x = (float)f[3]; out->velocity.y = (float)f[4]; out->velocity.z = (float)f[5];
    out->forward.x  = (float)f[6]; out->forward.y  = (float)f[7]; out->forward.z  = (float)f[8];
    out->up.x       = (float)f[9]; out->up.y       = (float)f[10]; out->up.z      = (float)f[11];
}

/* f holds FAXE_DSPDATA_SINGLE_DOUBLES values. */
static void faxe_dspdata_pack_3d(FMOD_DSP_PARAMETER_3DATTRIBUTES* out, const double* f) {
    memset(out, 0, sizeof(*out));
    faxe_dspdata_read_attributes(&out->relative, f);
    faxe_dspdata_read_attributes(&out->absolute, f + FAXE_DSPDATA_ATTR_DOUBLES);
}

/* f holds FAXE_DSPDATA_MULTI_DOUBLES values. Returns 0 when numlisteners
 * is out of 1..FMOD_MAX_LISTENERS, the struct is then zeroed. */
static int faxe_dspdata_pack_3d_multi(FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI* out, int numlisteners, const double* f) {
    int i;
    memset(out, 0, sizeof(*out));
    if (numlisteners < 1 || numlisteners > FMOD_MAX_LISTENERS) return 0;
    out->numlisteners = numlisteners;
    for (i = 0; i < numlisteners; i++) {
        faxe_dspdata_read_attributes(&out->relative[i], f + i * FAXE_DSPDATA_ATTR_DOUBLES);
        out->weight[i] = (float)f[FAXE_DSPDATA_MULTI_WEIGHT_OFFSET + i];
    }
    faxe_dspdata_read_attributes(&out->absolute, f + FAXE_DSPDATA_MULTI_ABSOLUTE_OFFSET);
    return 1;
}

/* Returns the channel count written. */
static int faxe_dspdata_unpack_metering(const FMOD_DSP_METERING_INFO* info, double* f, int* i) {
    int ch = (int)info->numchannels;
    int n;
    if (ch < 0) ch = 0;
    if (ch > 32) ch = 32;
    for (n = 0; n < ch; n++) {
        f[n] = (double)info->peaklevel[n];
        f[ch + n] = (double)info->rmslevel[n];
    }
    i[0] = info->numsamples;
    i[1] = ch;
    return ch;
}

static void faxe_dspdata_clear_desc(double* f, int* i) {
    int n;
    for (n = 0; n < FAXE_DSPDATA_DESC_FLOATS; n++) f[n] = 0.0;
    for (n = 0; n < FAXE_DSPDATA_DESC_INTS; n++) i[n] = 0;
}

static void faxe_dspdata_unpack_desc(const FMOD_DSP_PARAMETER_DESC* desc, double* f, int* i) {
    faxe_dspdata_clear_desc(f, i);
    i[0] = (int)desc->type;
    if (desc->type == FMOD_DSP_PARAMETER_TYPE_FLOAT) {
        const FMOD_DSP_PARAMETER_FLOAT_MAPPING* mapping = &desc->floatdesc.mapping;
        int n = mapping->piecewiselinearmapping.numpoints;
        int k;
        f[0] = (double)desc->floatdesc.min;
        f[1] = (double)desc->floatdesc.max;
        f[2] = (double)desc->floatdesc.defaultval;
        i[1] = (int)mapping->type;
        if (n < 0 || !mapping->piecewiselinearmapping.pointparamvalues || !mapping->piecewiselinearmapping.pointpositions) n = 0;
        if (n > FAXE_DSPDATA_MAX_MAPPING_POINTS) n = FAXE_DSPDATA_MAX_MAPPING_POINTS;
        i[4] = n;
        for (k = 0; k < n; k++) {
            f[FAXE_DSPDATA_DESC_FLOATS + k] = (double)mapping->piecewiselinearmapping.pointparamvalues[k];
            f[FAXE_DSPDATA_DESC_FLOATS + n + k] = (double)mapping->piecewiselinearmapping.pointpositions[k];
        }
    } else if (desc->type == FMOD_DSP_PARAMETER_TYPE_INT) {
        f[0] = (double)desc->intdesc.min;
        f[1] = (double)desc->intdesc.max;
        f[2] = (double)desc->intdesc.defaultval;
        i[2] = desc->intdesc.goestoinf ? 1 : 0;
    } else if (desc->type == FMOD_DSP_PARAMETER_TYPE_BOOL) {
        f[2] = desc->booldesc.defaultval ? 1.0 : 0.0;
    } else if (desc->type == FMOD_DSP_PARAMETER_TYPE_DATA) {
        i[3] = desc->datadesc.datatype;
    }
}

/* Copies one text of the descriptor into buf: kind 0 is the label, 1 the
 * description, 2 and up the value name of (kind - 2) for int and bool
 * parameters. buf always ends up terminated, empty when the descriptor
 * has no such text. Returns 1 when a text was found. */
static int faxe_dspdata_desc_text(const FMOD_DSP_PARAMETER_DESC* desc, int kind, char* buf, size_t size) {
    const char* text = 0;
    size_t len;
    if (size == 0) return 0;
    buf[0] = '\0';
    if (kind == 0) {
        len = strlen(desc->label) < sizeof(desc->label) ? strlen(desc->label) : sizeof(desc->label);
        if (len >= size) len = size - 1;
        memcpy(buf, desc->label, len);
        buf[len] = '\0';
        return 1;
    }
    if (kind == 1) {
        text = desc->description;
    } else if (kind >= 2) {
        int which = kind - 2;
        if (desc->type == FMOD_DSP_PARAMETER_TYPE_INT) {
            int count = desc->intdesc.max - desc->intdesc.min + 1;
            if (desc->intdesc.valuenames && which >= 0 && which < count) text = desc->intdesc.valuenames[which];
        } else if (desc->type == FMOD_DSP_PARAMETER_TYPE_BOOL) {
            if (desc->booldesc.valuenames && which >= 0 && which < 2) text = desc->booldesc.valuenames[which];
        }
    }
    if (!text) return 0;
    len = strlen(text);
    if (len >= size) len = size - 1;
    memcpy(buf, text, len);
    buf[len] = '\0';
    return 1;
}

/* Builds the struct of kind from the flat image (f holds
 * FAXE_DSPDATA_TYPED_DOUBLES values, i FAXE_DSPDATA_TYPED_INTS). Returns
 * the byte size to hand FMOD, 0 for a kind it does not know. */
static unsigned int faxe_dspdata_pack_typed(int kind, faxe_dspdata_typed* out, const double* f, const int* i) {
    int n;
    memset(out, 0, sizeof(*out));
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        out->sidechain.sidechainenable = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->sidechain);
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        out->finiteLength.finite = f[0] != 0.0 ? 1 : 0;
        return (unsigned int)sizeof(out->finiteLength);
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        out->attenuationRange.min = (float)f[0];
        out->attenuationRange.max = (float)f[1];
        return (unsigned int)sizeof(out->attenuationRange);
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = i[0];
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        out->dynamicResponse.numchannels = n;
        for (n = 0; n < out->dynamicResponse.numchannels; n++) out->dynamicResponse.rms[n] = (float)f[n];
        return (unsigned int)sizeof(out->dynamicResponse);
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) out->loudnessWeighting.channelweight[n] = (float)f[n];
        return (unsigned int)sizeof(out->loudnessWeighting);
    default:
        return 0;
    }
}

/* Reads a block FMOD returned as kind into the flat image. Returns 0
 * when the kind is unknown or the block is shorter than the struct, the
 * image is then zeroed. */
static int faxe_dspdata_unpack_typed(int kind, const void* data, unsigned int len, double* f, int* i) {
    faxe_dspdata_typed in;
    unsigned int need = 0;
    int n;
    for (n = 0; n < FAXE_DSPDATA_TYPED_DOUBLES; n++) f[n] = 0.0;
    for (n = 0; n < FAXE_DSPDATA_TYPED_INTS; n++) i[n] = 0;
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN: need = (unsigned int)sizeof(in.sidechain); break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH: need = (unsigned int)sizeof(in.finiteLength); break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE: need = (unsigned int)sizeof(in.attenuationRange); break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE: need = (unsigned int)sizeof(in.dynamicResponse); break;
    case FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING: need = (unsigned int)sizeof(in.loudnessWeighting); break;
    default: return 0;
    }
    if (!data || len < need) return 0;
    memcpy(&in, data, need);
    switch (kind) {
    case FAXE_DSPDATA_KIND_SIDECHAIN:
        f[0] = in.sidechain.sidechainenable ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_FINITE_LENGTH:
        f[0] = in.finiteLength.finite ? 1.0 : 0.0;
        break;
    case FAXE_DSPDATA_KIND_ATTENUATION_RANGE:
        f[0] = (double)in.attenuationRange.min;
        f[1] = (double)in.attenuationRange.max;
        break;
    case FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE:
        n = in.dynamicResponse.numchannels;
        if (n < 0) n = 0;
        if (n > FAXE_DSPDATA_CHANNEL_SLOTS) n = FAXE_DSPDATA_CHANNEL_SLOTS;
        i[0] = n;
        for (n = 0; n < i[0]; n++) f[n] = (double)in.dynamicResponse.rms[n];
        break;
    default:
        for (n = 0; n < FAXE_DSPDATA_CHANNEL_SLOTS; n++) f[n] = (double)in.loudnessWeighting.channelweight[n];
        break;
    }
    return 1;
}

#endif
