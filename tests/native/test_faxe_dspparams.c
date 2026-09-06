/*
 * Asserts every parameter index declared in haxefmod/core/DspParameters.hx
 * against the FMOD_DSP_<EFFECT> enums of the current SDK's fmod_dsp_effects.h.
 * Only the SDK the Haxe file was generated from can pass, FMOD adds and
 * reorders parameters between releases.
 * The value list comes from tests/native/faxe_dsp_parameters.h, which
 * ci/gen-dsp-parameters.py writes from the same header as the Haxe file.
 *
 *   gcc -std=c99 -Wall -Wextra -Werror -I<sdk>/api/core/inc \
 *       -o t tests/native/test_faxe_dspparams.c && ./t
 */
#include <stdio.h>
#include <assert.h>
#include "fmod_dsp_effects.h"
#include "faxe_dsp_parameters.h"

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
    assert((int)(fmod_name) == (value)); \
    checked++;
    FAXE_DSP_PARAMETERS(CHECK)
#undef CHECK

    assert(checked == FAXE_DSP_PARAMETER_VALUES);
    printf("OK: %d DSP parameter indices in %d enums match fmod_dsp_effects.h\n",
        checked, FAXE_DSP_PARAMETER_ENUMS);
    return 0;
}
