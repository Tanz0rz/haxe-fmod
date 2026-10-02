/**
 * Channel groups whose FMOD release waits for the geometry thread.
 *
 * FMOD queues a 3D channel group's occlusion request for its geometry
 * thread. The request lives inside the group. ChannelGroup::release frees
 * the group without taking the request off the queue, and the geometry
 * thread then reads freed memory. The geometry thread takes a queued
 * request within its 10 ms poll. FMOD queues requests only while a
 * geometry exists, and a request queued before the last geometry went can
 * still wait in the queue.
 *
 * So a shim parks a group the game releases while a geometry lives, or
 * within FAXE_PARK_DELAY_MS of the last geometry release. The game's
 * handle dies at once. The FMOD release runs from a later drop point on
 * the game thread, once FAXE_PARK_DELAY_MS have passed since the park.
 *
 * Game thread only. FMOD threads never read or write this state. Times
 * are milliseconds on a monotonic clock that the shim reads and passes in.
 *
 * Used by both linc_faxe.cpp (C++) and hlaxe_fmod.c (C99) via #include.
 * The web build has no geometry, so jaxe.js has no counterpart.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_PARKING_H
#define FAXE_PARKING_H

/* Most groups parked at once. A release that finds the list full waits
 * for the oldest entry instead. */
#define FAXE_PARK_MAX 32
/* Wait between the park and the FMOD release. It covers several polls of
 * the geometry thread. */
#define FAXE_PARK_DELAY_MS 60.0

typedef struct {
    /* The FMOD channel group, alive until its release runs */
    void* ptr;
    /* Memory FMOD reads while the group lives, such as the custom rolloff
     * points. The shim frees it after the release. NULL for none. */
    void* aux;
    /* Clock reading at the park */
    double at;
} FaxeParked;

static FaxeParked gFaxeParked[FAXE_PARK_MAX];
static int gFaxeParkedCount = 0;
/* Geometry objects the game holds */
static int gFaxeParkGeometryLive = 0;
/* 1 once the last geometry went at least once, with the time it went */
static int gFaxeParkGeometryGone = 0;
static double gFaxeParkGeometryGoneAt = 0.0;

/* Counts a geometry the game created or loaded */
static void faxe_park_geometry_made(void) {
    gFaxeParkGeometryLive++;
}

/* Counts a geometry the game released. The last one going starts the
 * window in which a queued request can still name a group. */
static void faxe_park_geometry_gone(double now) {
    if (gFaxeParkGeometryLive > 0) gFaxeParkGeometryLive--;
    if (gFaxeParkGeometryLive == 0) {
        gFaxeParkGeometryGone = 1;
        gFaxeParkGeometryGoneAt = now;
    }
}

/* True when a group released at the time passed in can still have a
 * queued request */
static int faxe_park_needed(double now) {
    if (gFaxeParkGeometryLive > 0) return 1;
    return gFaxeParkGeometryGone && now - gFaxeParkGeometryGoneAt < FAXE_PARK_DELAY_MS;
}

static int faxe_park_count(void) {
    return gFaxeParkedCount;
}

/* True when ptr is a parked group */
static int faxe_park_contains(const void* ptr) {
    int i;
    if (!ptr) return 0;
    for (i = 0; i < gFaxeParkedCount; i++) {
        if (gFaxeParked[i].ptr == ptr) return 1;
    }
    return 0;
}

/* Parks a group with the time of its park. Returns 0 when the list is
 * full or ptr is NULL. A group already parked is not added twice. */
static int faxe_park_add(void* ptr, void* aux, double at) {
    if (!ptr || gFaxeParkedCount >= FAXE_PARK_MAX) return 0;
    if (faxe_park_contains(ptr)) return 1;
    gFaxeParked[gFaxeParkedCount].ptr = ptr;
    gFaxeParked[gFaxeParkedCount].aux = aux;
    gFaxeParked[gFaxeParkedCount].at = at;
    gFaxeParkedCount++;
    return 1;
}

/* Moves every entry whose wait is over at the time passed in into out,
 * in list order. Returns how many moved. Entries that do not fit in max
 * stay parked. */
static int faxe_park_take_due(double now, FaxeParked* out, int max) {
    int i;
    int kept = 0;
    int taken = 0;
    for (i = 0; i < gFaxeParkedCount; i++) {
        FaxeParked e = gFaxeParked[i];
        if (taken < max && now - e.at >= FAXE_PARK_DELAY_MS) {
            out[taken++] = e;
        } else {
            gFaxeParked[kept++] = e;
        }
    }
    gFaxeParkedCount = kept;
    return taken;
}

/* Milliseconds until the oldest entry is due. 0 when one is due already
 * or nothing is parked. */
static double faxe_park_wait_ms(double now) {
    int i;
    double oldest;
    double left;
    if (gFaxeParkedCount == 0) return 0.0;
    oldest = gFaxeParked[0].at;
    for (i = 1; i < gFaxeParkedCount; i++) {
        if (gFaxeParked[i].at < oldest) oldest = gFaxeParked[i].at;
    }
    left = FAXE_PARK_DELAY_MS - (now - oldest);
    return left > 0.0 ? left : 0.0;
}

#endif /* FAXE_PARKING_H */
