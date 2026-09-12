/*
 * Asserts every parameter index declared in haxefmod/core/DspParameters.hx
 * against the FMOD_DSP_<EFFECT> enums of the current SDK's fmod_dsp_effects.h.
 * Only the SDK the Haxe file was generated from can pass, FMOD adds and
 * reorders parameters between releases.
 * The value list comes from tests/native/faxe_dsp_parameters.h, which
 * ci/gen-dsp-parameters.py writes from the same header as the Haxe file.
 * Compile and run with:
 *
 *   gcc -std=c99 -Wall -Wextra -Werror -I<sdk>/api/core/inc \
 *       -o t tests/native/test_faxe_dspparams.c && ./t
 */
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "fmod_dsp_effects.h"
#include "faxe_dsp_parameters.h"

/* The Haxe enum of the group in progress, and the FMOD constant head that
 * the group shares. The generated list keeps one enum per contiguous run. */
static char gEnumName[128];
static char gHead[128];
static int gEnums;

/* Asserts one row of FAXE_DSP_PARAMETERS: the SDK index, and the Haxe side
 * identity of the member that carries it. */
static void check_one(const char* haxeEnum, const char* haxeName,
        const char* fmodName, int fmodValue, int haxeValue) {
    const char* bare = haxeName;
    size_t nameLen, fmodLen, headLen;

    /* the index the Haxe member declares is the index the SDK declares */
    assert(fmodValue == haxeValue);

    /* A Haxe identifier cannot start with a digit, so the generator keeps a
     * leading underscore for names such as _3D_POSITION. The FMOD constant
     * carries the plain name after its effect prefix. */
    if (bare[0] == '_') bare++;
    nameLen = strlen(bare);
    fmodLen = strlen(fmodName);
    assert(strncmp(fmodName, "FMOD_DSP_", 9) == 0);
    assert(fmodLen > nameLen + 1);
    headLen = fmodLen - nameLen - 1;
    assert(fmodName[headLen] == '_');
    assert(strcmp(fmodName + headLen + 1, bare) == 0);
    assert(headLen < sizeof(gHead));

    if (strcmp(gEnumName, haxeEnum) != 0) {
        /* the first member of the next Haxe enum fixes the effect prefix */
        assert(strlen(haxeEnum) < sizeof(gEnumName));
        strcpy(gEnumName, haxeEnum);
        memcpy(gHead, fmodName, headLen);
        gHead[headLen] = '\0';
        gEnums++;
    } else {
        /* every member of one Haxe enum comes from one FMOD effect enum */
        assert(strlen(gHead) == headLen);
        assert(strncmp(gHead, fmodName, headLen) == 0);
    }
}

int main(void) {
    int checked = 0;

    /* A few by hand, so a broken generator cannot pass its own output */
    assert(FMOD_DSP_LOWPASS_CUTOFF == 0);
    assert(FMOD_DSP_CHANNELMIX_GAIN_CH0 == 1);
    assert(FMOD_DSP_CHANNELMIX_OUTPUT_CH31 == 64);
    assert(FMOD_DSP_PAN_2D_STEREO_MODE == 6);
    assert(FMOD_DSP_FFT_WINDOW == 1);
    assert(FMOD_DSP_OBJECTPAN_OVERRIDE_RANGE == 10);

#define CHECK(haxe_enum, haxe_name, fmod_name, value) \
    check_one(#haxe_enum, #haxe_name, #fmod_name, (int)(fmod_name), (value)); \
    checked++;
    FAXE_DSP_PARAMETERS(CHECK)
#undef CHECK

    assert(checked == FAXE_DSP_PARAMETER_VALUES);
    assert(gEnums == FAXE_DSP_PARAMETER_ENUMS);
    printf("OK: %d DSP parameter indices in %d enums match fmod_dsp_effects.h\n",
        checked, gEnums);
    return 0;
}
