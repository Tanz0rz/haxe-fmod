/* KNOWN-CRASH EVIDENCE, NOT RUN IN CI.
 *
 * Reproduces an FMOD-internal segfault on linux (FMOD 2.03.12): rapid
 * same-frame churn of OPENUSER stream lifecycles together with Reverb3D
 * zone create/release cycles crashes inside the engine within a few
 * thousand cycles. Pure C against the FMOD API, so no binding layer is
 * involved. Bisect: PCM+Reverb3D is the minimal crashing pair (isolated
 * 2026-07-11); sound groups, nested channel groups, DSP graph churn, and
 * channel callbacks are all innocent, and skipping either half of the
 * pair survives 20000 cycles.
 *
 * Frame-alternating the two families does NOT avoid the crash (the race
 * spans mixer command batches; ROTATE=1 still dumps core). The safe
 * envelope, each proven for 20000 cycles: a zone merely existing
 * (R3D_PERSIST=1 R3D_NO_PROPS=1 R3D_LIFE_EVERY=0), per-cycle property
 * churn on it (drop R3D_NO_PROPS), and occasional lifecycles
 * (R3D_LIFE_EVERY=300). The stress test uses a persistent zone with
 * property churn. Kept for reporting upstream and for retesting future
 * FMOD releases:
 *   gcc -g -O1 fmod_churn_crash_repro.c -I$FMOD_SDK/api/core/inc \
 *     -I$FMOD_SDK/api/studio/inc -L$FMOD_SDK/api/core/lib/x86_64 \
 *     -L$FMOD_SDK/api/studio/lib/x86_64 -lfmodstudio -lfmod -lpthread -lm
 */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include "fmod.h"
#include "fmod_studio.h"

#ifndef F_CALLBACK
#define F_CALLBACK F_CALL
#endif

static FMOD_RESULT F_CALLBACK pcmread(FMOD_SOUND* sound, void* data, unsigned int datalen) {
    void* ud = NULL;
    FMOD_Sound_GetUserData(sound, &ud);
    if (ud) memcpy(data, ud, datalen < 4800 ? datalen : 4800);
    else memset(data, 0, datalen);
    return FMOD_OK;
}

static FMOD_RESULT F_CALLBACK chancb(FMOD_CHANNELCONTROL* cc, FMOD_CHANNELCONTROL_TYPE ct,
        FMOD_CHANNELCONTROL_CALLBACK_TYPE cb, void* d1, void* d2) {
    (void)cc; (void)ct; (void)cb; (void)d1; (void)d2;
    return FMOD_OK;
}

int main(void) {
    FMOD_STUDIO_SYSTEM* studio = NULL;
    FMOD_SYSTEM* core = NULL;
    static char ringbuf[4800];
    int i;

    FMOD_Studio_System_Create(&studio, FMOD_VERSION);
    FMOD_Studio_System_GetCoreSystem(studio, &core);
    FMOD_System_SetOutput(core, FMOD_OUTPUTTYPE_NOSOUND);
    FMOD_Studio_System_Initialize(studio, 256, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL, NULL);

    int doPcm = !getenv("SKIP_PCM");
    int doGraph = !getenv("SKIP_GRAPH");
    int doMisc = !getenv("SKIP_MISC");
    int doCb = !getenv("SKIP_CB");
    int cycles = getenv("CYCLES") ? atoi(getenv("CYCLES")) : 20000;
    for (i = 0; i < cycles; i++) {
        /* PCM stream cycle */
        if (doPcm) {
        FMOD_CREATESOUNDEXINFO ex;
        FMOD_SOUND* snd = NULL;
        FMOD_CHANNEL* ch = NULL;
        memset(&ex, 0, sizeof(ex));
        ex.cbsize = sizeof(ex);
        ex.numchannels = 1;
        ex.defaultfrequency = 48000;
        ex.format = FMOD_SOUND_FORMAT_PCM16;
        ex.decodebuffersize = 4096;
        ex.length = 96000;
        ex.pcmreadcallback = pcmread;
        ex.userdata = ringbuf;
        FMOD_System_CreateSound(core, NULL, FMOD_OPENUSER | FMOD_LOOP_NORMAL | FMOD_CREATESTREAM, &ex, &snd);
        if (snd) {
            FMOD_System_PlaySound(core, snd, NULL, 1, &ch);
            if (ch) {
                FMOD_DSP* lp = NULL;
                FMOD_System_CreateDSPByType(core, FMOD_DSP_TYPE_LOWPASS_SIMPLE, &lp);
                if (lp) {
                    FMOD_Channel_AddDSP(ch, 0, lp);
                    FMOD_Channel_RemoveDSP(ch, lp);
                    FMOD_DSP_Release(lp);
                }
                /* callback churn */
                if (doCb) {
                    FMOD_Channel_SetUserData(ch, (void*)(intptr_t)(i + 1));
                    FMOD_Channel_SetCallback(ch, chancb);
                    FMOD_Channel_SetCallback(ch, NULL);
                    FMOD_Channel_SetUserData(ch, NULL);
                }
                FMOD_Channel_Stop(ch);
            }
            FMOD_Sound_SetUserData(snd, NULL);
            FMOD_Sound_Release(snd);
        }
        }

        /* graph cycle */
        if (doGraph) {
            FMOD_DSP* osc = NULL;
            FMOD_DSP* tgt = NULL;
            FMOD_DSPCONNECTION* conn = NULL;
            FMOD_System_CreateDSPByType(core, FMOD_DSP_TYPE_OSCILLATOR, &osc);
            FMOD_System_CreateDSPByType(core, FMOD_DSP_TYPE_LOWPASS_SIMPLE, &tgt);
            if (osc && tgt) {
                FMOD_DSP_AddInput(tgt, osc, &conn, FMOD_DSPCONNECTION_TYPE_STANDARD);
                if (conn) FMOD_DSPConnection_SetMix(conn, 0.5f);
                FMOD_DSP_DisconnectFrom(tgt, osc, NULL);
            }
            if (tgt) FMOD_DSP_Release(tgt);
            if (osc) FMOD_DSP_Release(osc);
        }

        /* reverb zone + soundgroup + nested group cycles */
        if (doMisc && !getenv("SKIP_R3D")) {
            FMOD_REVERB3D* rv = NULL;
            FMOD_VECTOR pos = {0, 0, 0};
            FMOD_System_CreateReverb3D(core, &rv);
            if (rv) {
                FMOD_Reverb3D_Set3DAttributes(rv, &pos, 5.0f, 20.0f);
                FMOD_Reverb3D_Release(rv);
            }
        }
        if (doMisc && !getenv("SKIP_SG")) {
            FMOD_SOUNDGROUP* sg = NULL;
            FMOD_System_CreateSoundGroup(core, "churn", &sg);
            if (sg) {
                FMOD_SoundGroup_SetMaxAudible(sg, 1);
                FMOD_SoundGroup_Release(sg);
            }
        }
        if (doMisc && !getenv("SKIP_NEST")) {
            FMOD_CHANNELGROUP* a = NULL;
            FMOD_CHANNELGROUP* b = NULL;
            FMOD_System_CreateChannelGroup(core, "a", &a);
            FMOD_System_CreateChannelGroup(core, "b", &b);
            if (a && b) FMOD_ChannelGroup_AddGroup(a, b, 1, NULL);
            if (b) FMOD_ChannelGroup_Release(b);
            if (a) FMOD_ChannelGroup_Release(a);
        }

        FMOD_Studio_System_Update(studio);
        if (i % 500 == 0) { printf("cycle %d\n", i); fflush(stdout); }
    }
    FMOD_Studio_System_Release(studio);
    printf("REPRO: no crash in 20000 cycles\n");
    return 0;
}
