/*
 * A minimal FMOD DSP plugin for the CI plugin-loading checks: one float
 * parameter, "Gain", applied to every sample. Built as a shared library
 * next to the example game (see the linux-cpp job) so the api-probe can
 * load it with StudioSystem.loadPlugin, create a unit from it, and run
 * audio through it.
 *
 * Build: gcc -shared -fPIC -o libtest_plugin_gain.so -I$FMOD_SDK/api/core/inc tests/native/test_plugin_gain.c
 */
#include "fmod.h"
#include "fmod_dsp.h"
#include <string.h>

#define GAIN_PARAM_INDEX 0

static FMOD_DSP_PARAMETER_DESC gainParam;
static FMOD_DSP_PARAMETER_DESC* params[1] = { &gainParam };

typedef struct {
    float gain;
} GainState;

static GainState gState = { 1.0f };

static FMOD_RESULT F_CALL gainRead(FMOD_DSP_STATE* dsp, float* inbuffer, float* outbuffer,
        unsigned int length, int inchannels, int* outchannels) {
    unsigned int samples = length * (unsigned int)inchannels;
    unsigned int i;
    (void)dsp;
    for (i = 0; i < samples; i++) outbuffer[i] = inbuffer[i] * gState.gain;
    *outchannels = inchannels;
    return FMOD_OK;
}

static FMOD_RESULT F_CALL gainSetFloat(FMOD_DSP_STATE* dsp, int index, float value) {
    (void)dsp;
    if (index != GAIN_PARAM_INDEX) return FMOD_ERR_INVALID_PARAM;
    gState.gain = value;
    return FMOD_OK;
}

static FMOD_RESULT F_CALL gainGetFloat(FMOD_DSP_STATE* dsp, int index, float* value, char* valuestr) {
    (void)dsp;
    if (index != GAIN_PARAM_INDEX) return FMOD_ERR_INVALID_PARAM;
    *value = gState.gain;
    if (valuestr) valuestr[0] = '\0';
    return FMOD_OK;
}

static FMOD_DSP_DESCRIPTION gainDescription;

F_EXPORT FMOD_DSP_DESCRIPTION* F_CALL FMODGetDSPDescription(void) {
    memset(&gainDescription, 0, sizeof(gainDescription));
    memset(&gainParam, 0, sizeof(gainParam));

    gainParam.type = FMOD_DSP_PARAMETER_TYPE_FLOAT;
    strncpy(gainParam.name, "Gain", sizeof(gainParam.name) - 1);
    strncpy(gainParam.label, "x", sizeof(gainParam.label) - 1);
    gainParam.description = "Linear gain applied to every sample";
    gainParam.floatdesc.min = 0.0f;
    gainParam.floatdesc.max = 4.0f;
    gainParam.floatdesc.defaultval = 1.0f;

    gainDescription.pluginsdkversion = FMOD_PLUGIN_SDK_VERSION;
    strncpy(gainDescription.name, "haxefmod test gain", sizeof(gainDescription.name) - 1);
    gainDescription.version = 0x00010000;
    gainDescription.numinputbuffers = 1;
    gainDescription.numoutputbuffers = 1;
    gainDescription.read = gainRead;
    gainDescription.numparameters = 1;
    gainDescription.paramdesc = params;
    gainDescription.setparameterfloat = gainSetFloat;
    gainDescription.getparameterfloat = gainGetFloat;
    return &gainDescription;
}
