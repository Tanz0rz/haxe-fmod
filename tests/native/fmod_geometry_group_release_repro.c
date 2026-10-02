/* KNOWN-CRASH EVIDENCE. CI never runs this.
 *
 * Reproduces an FMOD-internal use after free (FMOD 2.03.12 and 2.02.33).
 * FMOD computes a 3D channel group's geometry occlusion on its geometry
 * thread. An update that sees the group move, or the listener or the
 * geometry change, links a request node that lives inside the group onto
 * the geometry thread's queue. The thread takes one node at a time and
 * sleeps 10 ms when the queue is empty. ChannelGroup::release frees the
 * group without unlinking that node, so a release inside that window
 * leaves a freed node on the queue and the geometry thread unlinks it.
 * A release just after the last geometry release crashes the same way,
 * since a node queued before it still waits. The native shims park such
 * a group and release it later (native/shared/faxe_parking.h).
 *
 * The allocator below zeroes a block on free and never reuses it, as the
 * macOS allocator zeroes freed blocks. The geometry
 * thread then reads a null link and the process segfaults, as on the
 * macOS runner. With the plain allocator on Linux the same pop writes
 * into freed memory silently. Pure C against the FMOD API, so no binding
 * layer is involved.
 *
 *   gcc -g -O1 fmod_geometry_group_release_repro.c -I$FMOD_SDK/api/core/inc \
 *     -I$FMOD_SDK/api/studio/inc -L$FMOD_SDK/api/core/lib/x86_64 \
 *     -L$FMOD_SDK/api/studio/lib/x86_64 -lfmodstudio -lfmod -lpthread
 *   ./a.out [cycles] [workaround]
 *
 * workaround 1 sets FMOD_3D_IGNOREGEOMETRY on the group and releases it
 * 50 ms later, which survives every cycle.
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "fmod.h"
#include "fmod_studio.h"

#define HDR 16

static void* F_CALL zalloc(unsigned int size, FMOD_MEMORY_TYPE type, const char* src) {
    char* p = (char*)calloc(1, size + HDR);
    if (!p) return NULL;
    *(unsigned int*)p = size;
    return p + HDR;
}

static void F_CALL zfree(void* ptr, FMOD_MEMORY_TYPE type, const char* src) {
    if (!ptr) return;
    char* p = (char*)ptr - HDR;
    /* Zeroed and never reused, so a later read through it sees nulls */
    memset(ptr, 0, *(unsigned int*)p);
}

static void* F_CALL zrealloc(void* ptr, unsigned int size, FMOD_MEMORY_TYPE type, const char* src) {
    void* n = zalloc(size, type, src);
    if (ptr && n) {
        unsigned int old = *(unsigned int*)((char*)ptr - HDR);
        memcpy(n, ptr, old < size ? old : size);
        zfree(ptr, type, src);
    }
    return n;
}

static FMOD_RESULT F_CALL pcmread(FMOD_SOUND* s, void* data, unsigned int len) {
    memset(data, 0, len);
    return FMOD_OK;
}

static void msleep(double ms) {
    struct timespec ts = { (time_t)(ms / 1000), (long)((ms - 1000 * (long)(ms / 1000)) * 1e6) };
    nanosleep(&ts, NULL);
}

int main(int argc, char** argv) {
    int cycles = argc > 1 ? atoi(argv[1]) : 2000;
    int workaround = argc > 2 ? atoi(argv[2]) : 0;
    FMOD_STUDIO_SYSTEM* studio;
    FMOD_SYSTEM* core;
    FMOD_Memory_Initialize(NULL, 0, zalloc, zrealloc, zfree, FMOD_MEMORY_ALL);
    FMOD_Studio_System_Create(&studio, FMOD_VERSION);
    FMOD_Studio_System_GetCoreSystem(studio, &core);
    FMOD_System_SetOutput(core, FMOD_OUTPUTTYPE_NOSOUND);
    /* Asynchronous Studio updates, so FMOD's own thread runs System::update */
    if (FMOD_Studio_System_Initialize(studio, 64, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL, NULL) != FMOD_OK) return 2;
    FMOD_3D_ATTRIBUTES listener;
    memset(&listener, 0, sizeof(listener));
    listener.position.x = -5;
    listener.forward.z = 1;
    listener.up.y = 1;
    FMOD_Studio_System_SetListenerAttributes(studio, 0, &listener, NULL);
    FMOD_GEOMETRY* geometry;
    FMOD_VECTOR quad[4] = { {0, -10, -10}, {0, 10, -10}, {0, 10, 10}, {0, -10, 10} };
    int polygon;
    FMOD_System_CreateGeometry(core, 4, 16, &geometry);
    FMOD_Geometry_AddPolygon(geometry, 1.0f, 0.5f, 1, 4, quad, &polygon);
    FMOD_CREATESOUNDEXINFO ex;
    memset(&ex, 0, sizeof(ex));
    ex.cbsize = sizeof(ex);
    ex.numchannels = 1;
    ex.defaultfrequency = 48000;
    ex.format = FMOD_SOUND_FORMAT_PCM16;
    ex.length = 48000 * 2;
    ex.decodebuffersize = 1024;
    ex.pcmreadcallback = pcmread;
    FMOD_SOUND* sound;
    FMOD_System_CreateSound(core, NULL, FMOD_OPENUSER | FMOD_CREATESTREAM | FMOD_3D | FMOD_LOOP_NORMAL, &ex, &sound);
    srand((unsigned int)time(NULL));
    for (int i = 0; i < cycles; i++) {
        FMOD_CHANNELGROUP* group;
        FMOD_CHANNEL* channel;
        FMOD_VECTOR at = { 5, 0, 0 };
        FMOD_VECTOR moved = { 5.02f, 0, 0 };
        FMOD_VECTOR still = { 0, 0, 0 };
        FMOD_System_CreateChannelGroup(core, "occluded", &group);
        FMOD_ChannelGroup_SetMode(group, FMOD_3D);
        FMOD_ChannelGroup_Set3DAttributes(group, &at, &still);
        FMOD_System_PlaySound(core, sound, group, 0, &channel);
        FMOD_Channel_Set3DAttributes(channel, &at, &still);
        msleep(40);
        /* The group moves, so the next update queues its request */
        FMOD_ChannelGroup_Set3DAttributes(group, &moved, &still);
        msleep((rand() % 2500) / 100.0);
        FMOD_Channel_Stop(channel);
        if (workaround) {
            FMOD_ChannelGroup_SetMode(group, FMOD_3D | FMOD_3D_IGNOREGEOMETRY);
            msleep(50);
        }
        FMOD_ChannelGroup_Release(group);
        if (i % 100 == 0) printf("cycle %d\n", i);
        fflush(stdout);
    }
    FMOD_Sound_Release(sound);
    FMOD_Geometry_Release(geometry);
    FMOD_Studio_System_Release(studio);
    printf("survived %d cycles\n", cycles);
    return 0;
}
