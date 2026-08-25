/*
 * Unit tests for native/shared/faxe_dsptype.h against a real FMOD SDK's
 * headers. Compiled twice in CI: against the 2.03.12 headers in
 * package-check and against the 2.02.33 headers in linux-hl-compat,
 * because FMOD renumbers FMOD_DSP_TYPE between releases and the whole
 * point of the translation is surviving that.
 *
 *   gcc -std=c99 -Wall -Wextra -Werror -I<sdk>/api/core/inc \
 *       -o t tests/native/test_faxe_dsptype.c && ./t
 */
#include <stdio.h>
#include <assert.h>
#include "../../native/shared/faxe_dsptype.h"

int main(void) {
    /* The named effects resolve symbolically on every SDK version */
    assert(faxe_dsp_type_from_binding(16) == FMOD_DSP_TYPE_COMPRESSOR);
    assert(faxe_dsp_type_from_binding(18) == FMOD_DSP_TYPE_LOWPASS_SIMPLE);
    assert(faxe_dsp_type_from_binding(25) == FMOD_DSP_TYPE_THREE_EQ);
    assert(faxe_dsp_type_from_binding(26) == FMOD_DSP_TYPE_FFT);
    assert(faxe_dsp_type_from_binding(28) == FMOD_DSP_TYPE_CONVOLUTIONREVERB);
    assert(faxe_dsp_type_from_binding(0) == FMOD_DSP_TYPE_UNKNOWN);
    assert(faxe_dsp_type_from_binding(2) == FMOD_DSP_TYPE_OSCILLATOR);

    /* Round trip for every binding value this SDK supports */
    for (int i = 0; i <= 33; i++) {
        FMOD_DSP_TYPE mapped = faxe_dsp_type_from_binding(i);
        if (mapped == FAXE_DSP_TYPE_UNSUPPORTED) continue;
        assert(faxe_dsp_type_to_binding(mapped) == i);
    }

    /* Out-of-range binding values are refused, not cast */
    assert(faxe_dsp_type_from_binding(-1) == FAXE_DSP_TYPE_UNSUPPORTED);
    assert(faxe_dsp_type_from_binding(999) == FAXE_DSP_TYPE_UNSUPPORTED);

#if FMOD_VERSION >= 0x00020300
    /* 2.03: the full surface maps, and the numbering happens to be the
     * identity (the binding contract IS the 2.03 shape) */
    assert(faxe_dsp_type_from_binding(33) == FMOD_DSP_TYPE_MULTIBAND_DYNAMICS);
    for (int i = 0; i <= 33; i++) {
        assert((int)faxe_dsp_type_from_binding(i) == i);
    }
#else
    /* 2.02: the raw cast the shims used before this header is provably
     * wrong (16 lands on WINAMPPLUGIN, not COMPRESSOR), the translation
     * is not the identity, and 2.03-only types are refused */
    assert((int)FMOD_DSP_TYPE_COMPRESSOR != 16);
    assert((int)FMOD_DSP_TYPE_COMPRESSOR == 18);
    assert((int)FMOD_DSP_TYPE_FFT == 29);
    assert(faxe_dsp_type_from_binding(33) == FAXE_DSP_TYPE_UNSUPPORTED);
    /* SDK-specific entries the binding cannot name report UNKNOWN */
    assert(faxe_dsp_type_to_binding(FMOD_DSP_TYPE_VSTPLUGIN) == 0);
    assert(faxe_dsp_type_to_binding(FMOD_DSP_TYPE_ENVELOPEFOLLOWER) == 0);
#endif

    printf("faxe_dsptype: all assertions passed (FMOD_VERSION=%#010x)\n",
        (unsigned int)FMOD_VERSION);
    return 0;
}
