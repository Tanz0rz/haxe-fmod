/*
 * Unit tests for native/shared/faxe_dspdata.h against a real FMOD SDK's
 * headers: the flat double layouts land in the right struct fields, the
 * listener count is range checked, the metering unpack mirrors the
 * struct, the descriptor unpack and texts cover every parameter type, and
 * the typed data parameter pack and unpack agree with the structs.
 *
 *   gcc -std=c99 -Wall -Wextra -Werror -I<sdk>/api/core/inc \
 *       -o t tests/native/test_faxe_dspdata.c && ./t
 */
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "fmod.h"
#include "../../native/shared/faxe_dspdata.h"

static void fill_attrs(double* f, double base) {
    int i;
    for (i = 0; i < 12; i++) f[i] = base + i;
}

static void check_attrs(const FMOD_3D_ATTRIBUTES* a, double base) {
    assert(a->position.x == (float)(base + 0) && a->position.y == (float)(base + 1) && a->position.z == (float)(base + 2));
    assert(a->velocity.x == (float)(base + 3) && a->velocity.y == (float)(base + 4) && a->velocity.z == (float)(base + 5));
    assert(a->forward.x == (float)(base + 6) && a->forward.y == (float)(base + 7) && a->forward.z == (float)(base + 8));
    assert(a->up.x == (float)(base + 9) && a->up.y == (float)(base + 10) && a->up.z == (float)(base + 11));
}

static void test_single(void) {
    double f[FAXE_DSPDATA_SINGLE_DOUBLES];
    FMOD_DSP_PARAMETER_3DATTRIBUTES out;
    fill_attrs(f, 100);
    fill_attrs(f + 12, 200);
    memset(&out, 0x7f, sizeof(out));
    faxe_dspdata_pack_3d(&out, f);
    check_attrs(&out.relative, 100);
    check_attrs(&out.absolute, 200);
    assert(sizeof(out) == 2 * sizeof(FMOD_3D_ATTRIBUTES));
}

static void test_multi(void) {
    double f[FAXE_DSPDATA_MULTI_DOUBLES];
    FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI out;
    int i;
    for (i = 0; i < FMOD_MAX_LISTENERS; i++) {
        fill_attrs(f + i * 12, 1000 * (i + 1));
        f[FAXE_DSPDATA_MULTI_WEIGHT_OFFSET + i] = 0.5 + i;
    }
    fill_attrs(f + FAXE_DSPDATA_MULTI_ABSOLUTE_OFFSET, 50);
    assert(FAXE_DSPDATA_MULTI_DOUBLES == 116);
    assert(FAXE_DSPDATA_MULTI_WEIGHT_OFFSET == 96);
    assert(FAXE_DSPDATA_MULTI_ABSOLUTE_OFFSET == 104);

    assert(faxe_dspdata_pack_3d_multi(&out, 3, f) == 1);
    assert(out.numlisteners == 3);
    for (i = 0; i < 3; i++) {
        check_attrs(&out.relative[i], 1000 * (i + 1));
        assert(out.weight[i] == (float)(0.5 + i));
    }
    /* listeners past the count stay zero */
    assert(out.relative[3].position.x == 0.0f && out.weight[7] == 0.0f);
    check_attrs(&out.absolute, 50);

    assert(faxe_dspdata_pack_3d_multi(&out, FMOD_MAX_LISTENERS, f) == 1);
    assert(out.numlisteners == FMOD_MAX_LISTENERS);
    check_attrs(&out.relative[FMOD_MAX_LISTENERS - 1], 1000 * FMOD_MAX_LISTENERS);

    memset(&out, 0x7f, sizeof(out));
    assert(faxe_dspdata_pack_3d_multi(&out, 0, f) == 0);
    assert(out.numlisteners == 0 && out.weight[0] == 0.0f);
    assert(faxe_dspdata_pack_3d_multi(&out, FMOD_MAX_LISTENERS + 1, f) == 0);
    assert(faxe_dspdata_pack_3d_multi(&out, -1, f) == 0);
}

static void test_metering(void) {
    FMOD_DSP_METERING_INFO info;
    double f[64];
    int ints[2];
    int i;
    memset(&info, 0, sizeof(info));
    info.numsamples = 1024;
    info.numchannels = 2;
    info.peaklevel[0] = 0.5f; info.peaklevel[1] = 0.25f;
    info.rmslevel[0] = 0.4f; info.rmslevel[1] = 0.2f;
    assert(faxe_dspdata_unpack_metering(&info, f, ints) == 2);
    assert(f[0] == 0.5 && f[1] == 0.25 && f[2] == (double)0.4f && f[3] == (double)0.2f);
    assert(ints[0] == 1024 && ints[1] == 2);

    info.numchannels = 40; /* clamps to the 32 slots the struct holds */
    for (i = 0; i < 32; i++) info.peaklevel[i] = (float)i;
    assert(faxe_dspdata_unpack_metering(&info, f, ints) == 32);
    assert(ints[1] == 32 && f[31] == 31.0);
    info.numchannels = -1;
    assert(faxe_dspdata_unpack_metering(&info, f, ints) == 0);
}

static void test_desc(void) {
    FMOD_DSP_PARAMETER_DESC desc;
    double f[FAXE_DSPDATA_DESC_FLOATS + 2 * FAXE_DSPDATA_MAX_MAPPING_POINTS];
    int ints[FAXE_DSPDATA_DESC_INTS];
    float values[3] = { 0.0f, 50.0f, 100.0f };
    float positions[3] = { 0.0f, 0.2f, 1.0f };
    static const char* const boolNames[2] = { "Off", "On" };
    static const char* const intNames[3] = { "Low", "Mid", "High" };
    char buf[64];
    int i;

    memset(&desc, 0, sizeof(desc));
    desc.type = FMOD_DSP_PARAMETER_TYPE_FLOAT;
    strcpy(desc.name, "Cutoff");
    strcpy(desc.label, "Hz");
    desc.description = "Lowpass cutoff";
    desc.floatdesc.min = 10.0f;
    desc.floatdesc.max = 22000.0f;
    desc.floatdesc.defaultval = 5000.0f;
    desc.floatdesc.mapping.type = FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE_PIECEWISE_LINEAR;
    desc.floatdesc.mapping.piecewiselinearmapping.numpoints = 3;
    desc.floatdesc.mapping.piecewiselinearmapping.pointparamvalues = values;
    desc.floatdesc.mapping.piecewiselinearmapping.pointpositions = positions;
    faxe_dspdata_unpack_desc(&desc, f, ints);
    assert(ints[0] == (int)FMOD_DSP_PARAMETER_TYPE_FLOAT);
    assert(ints[1] == (int)FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE_PIECEWISE_LINEAR);
    assert(ints[2] == 0 && ints[3] == 0 && ints[4] == 3);
    assert(f[0] == 10.0 && f[1] == 22000.0 && f[2] == 5000.0);
    assert(f[3] == 0.0 && f[4] == 50.0 && f[5] == 100.0);
    assert(f[6] == 0.0 && f[7] == (double)0.2f && f[8] == 1.0);
    assert(faxe_dspdata_desc_text(&desc, 0, buf, sizeof(buf)) == 1 && strcmp(buf, "Hz") == 0);
    assert(faxe_dspdata_desc_text(&desc, 1, buf, sizeof(buf)) == 1 && strcmp(buf, "Lowpass cutoff") == 0);
    assert(faxe_dspdata_desc_text(&desc, 2, buf, sizeof(buf)) == 0 && buf[0] == '\0');

    /* a mapping without point arrays reports no points */
    desc.floatdesc.mapping.piecewiselinearmapping.pointparamvalues = 0;
    faxe_dspdata_unpack_desc(&desc, f, ints);
    assert(ints[4] == 0);
    /* an oversized point list is capped */
    desc.floatdesc.mapping.piecewiselinearmapping.pointparamvalues = values;
    desc.floatdesc.mapping.piecewiselinearmapping.numpoints = 1000;
    faxe_dspdata_unpack_desc(&desc, f, ints);
    assert(ints[4] == FAXE_DSPDATA_MAX_MAPPING_POINTS);

    memset(&desc, 0, sizeof(desc));
    desc.type = FMOD_DSP_PARAMETER_TYPE_INT;
    desc.intdesc.min = 1;
    desc.intdesc.max = 3;
    desc.intdesc.defaultval = 2;
    desc.intdesc.goestoinf = 1;
    desc.intdesc.valuenames = intNames;
    faxe_dspdata_unpack_desc(&desc, f, ints);
    assert(ints[0] == (int)FMOD_DSP_PARAMETER_TYPE_INT && ints[2] == 1 && ints[4] == 0);
    assert(f[0] == 1.0 && f[1] == 3.0 && f[2] == 2.0);
    for (i = 0; i < 3; i++) {
        assert(faxe_dspdata_desc_text(&desc, 2 + i, buf, sizeof(buf)) == 1);
        assert(strcmp(buf, intNames[i]) == 0);
    }
    assert(faxe_dspdata_desc_text(&desc, 5, buf, sizeof(buf)) == 0);
    assert(faxe_dspdata_desc_text(&desc, 1, buf, sizeof(buf)) == 0 && buf[0] == '\0');
    desc.intdesc.valuenames = 0;
    assert(faxe_dspdata_desc_text(&desc, 2, buf, sizeof(buf)) == 0);

    memset(&desc, 0, sizeof(desc));
    desc.type = FMOD_DSP_PARAMETER_TYPE_BOOL;
    desc.booldesc.defaultval = 1;
    desc.booldesc.valuenames = boolNames;
    faxe_dspdata_unpack_desc(&desc, f, ints);
    assert(ints[0] == (int)FMOD_DSP_PARAMETER_TYPE_BOOL && f[2] == 1.0 && f[0] == 0.0);
    assert(faxe_dspdata_desc_text(&desc, 2, buf, sizeof(buf)) == 1 && strcmp(buf, "Off") == 0);
    assert(faxe_dspdata_desc_text(&desc, 3, buf, sizeof(buf)) == 1 && strcmp(buf, "On") == 0);
    assert(faxe_dspdata_desc_text(&desc, 4, buf, sizeof(buf)) == 0);

    memset(&desc, 0, sizeof(desc));
    desc.type = FMOD_DSP_PARAMETER_TYPE_DATA;
    desc.datadesc.datatype = FMOD_DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES_MULTI;
    faxe_dspdata_unpack_desc(&desc, f, ints);
    assert(ints[0] == (int)FMOD_DSP_PARAMETER_TYPE_DATA);
    assert(ints[3] == (int)FMOD_DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES_MULTI);
    assert(ints[4] == 0 && f[0] == 0.0 && f[2] == 0.0);

    /* texts are cut to the buffer, an unterminated label included */
    memset(&desc, 0, sizeof(desc));
    memset(desc.label, 'x', sizeof(desc.label));
    assert(faxe_dspdata_desc_text(&desc, 0, buf, 5) == 1 && strlen(buf) == 4);
    assert(faxe_dspdata_desc_text(&desc, 0, buf, sizeof(buf)) == 1 && strlen(buf) == sizeof(desc.label));
    desc.description = "a long description";
    assert(faxe_dspdata_desc_text(&desc, 1, buf, 3) == 1 && strcmp(buf, "a ") == 0);
    assert(faxe_dspdata_desc_text(&desc, 1, buf, 0) == 0);
}

static void test_typed(void) {
    faxe_dspdata_typed out;
    double f[FAXE_DSPDATA_TYPED_DOUBLES];
    int ints[FAXE_DSPDATA_TYPED_INTS];
    double back[FAXE_DSPDATA_TYPED_DOUBLES];
    int backInts[FAXE_DSPDATA_TYPED_INTS];
    int n;
    for (n = 0; n < FAXE_DSPDATA_TYPED_DOUBLES; n++) f[n] = 0.0;
    ints[0] = 0;

    /* sidechain and finite length are one FMOD_BOOL each */
    f[0] = 1.0;
    assert(faxe_dspdata_pack_typed(FAXE_DSPDATA_KIND_SIDECHAIN, &out, f, ints) == sizeof(FMOD_DSP_PARAMETER_SIDECHAIN));
    assert(out.sidechain.sidechainenable == 1);
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_SIDECHAIN, &out, sizeof(out.sidechain), back, backInts) == 1);
    assert(back[0] == 1.0);
    f[0] = 0.0;
    assert(faxe_dspdata_pack_typed(FAXE_DSPDATA_KIND_FINITE_LENGTH, &out, f, ints) == sizeof(out.finiteLength));
    assert(sizeof(out.finiteLength) == sizeof(FMOD_BOOL));
    assert(out.finiteLength.finite == 0);
    out.finiteLength.finite = 1;
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_FINITE_LENGTH, &out, sizeof(out.finiteLength), back, backInts) == 1);
    assert(back[0] == 1.0);

    /* attenuation range is two floats */
    f[0] = 1.5; f[1] = 250.0;
    assert(faxe_dspdata_pack_typed(FAXE_DSPDATA_KIND_ATTENUATION_RANGE, &out, f, ints) == sizeof(FMOD_DSP_PARAMETER_ATTENUATION_RANGE));
    assert(out.attenuationRange.min == 1.5f && out.attenuationRange.max == 250.0f);
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_ATTENUATION_RANGE, &out, sizeof(out.attenuationRange), back, backInts) == 1);
    assert(back[0] == 1.5 && back[1] == 250.0);

    /* dynamic response carries a channel count and 32 rms slots */
    ints[0] = 3;
    f[0] = 0.1; f[1] = 0.2; f[2] = 0.3; f[3] = 9.0;
    assert(faxe_dspdata_pack_typed(FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE, &out, f, ints) == sizeof(out.dynamicResponse));
    assert(sizeof(out.dynamicResponse) == sizeof(int) + 32 * sizeof(float));
    assert(out.dynamicResponse.numchannels == 3);
    assert(out.dynamicResponse.rms[2] == 0.3f && out.dynamicResponse.rms[3] == 0.0f);
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE, &out, sizeof(out.dynamicResponse), back, backInts) == 1);
    assert(backInts[0] == 3 && back[0] == (double)0.1f && back[2] == (double)0.3f && back[3] == 0.0);
    ints[0] = 40; /* clamps to the 32 slots */
    assert(faxe_dspdata_pack_typed(FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE, &out, f, ints) > 0);
    assert(out.dynamicResponse.numchannels == 32);
    out.dynamicResponse.numchannels = -4;
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_DYNAMIC_RESPONSE, &out, sizeof(out.dynamicResponse), back, backInts) == 1);
    assert(backInts[0] == 0);

    /* loudness weighting is 32 floats */
    for (n = 0; n < 32; n++) f[n] = n * 0.5;
    ints[0] = 0;
    assert(faxe_dspdata_pack_typed(FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING, &out, f, ints) == sizeof(FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE));
    assert(out.loudnessWeighting.channelweight[0] == 0.0f && out.loudnessWeighting.channelweight[31] == 15.5f);
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING, &out, sizeof(out.loudnessWeighting), back, backInts) == 1);
    assert(back[31] == 15.5 && back[1] == 0.5);

    /* an unknown kind packs nothing, a short block unpacks nothing and clears the image */
    assert(faxe_dspdata_pack_typed(0, &out, f, ints) == 0);
    assert(faxe_dspdata_pack_typed(99, &out, f, ints) == 0);
    assert(faxe_dspdata_unpack_typed(99, &out, sizeof(out), back, backInts) == 0);
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_LOUDNESS_WEIGHTING, &out, sizeof(out.loudnessWeighting) - 1, back, backInts) == 0);
    assert(back[31] == 0.0);
    assert(faxe_dspdata_unpack_typed(FAXE_DSPDATA_KIND_SIDECHAIN, 0, sizeof(out.sidechain), back, backInts) == 0);
}

int main(void) {
    test_single();
    test_multi();
    test_metering();
    test_desc();
    test_typed();
    printf("test_faxe_dspdata: all assertions passed\n");
    return 0;
}
