/**
 * Shared thread-safe callback event queue for the haxefmod native shims.
 *
 * Used by both linc_faxe.cpp (C++) and hlaxe_fmod.c (C99) via #include.
 * jaxe.js re-implements the same record layout with a plain array (JS is
 * single-threaded, so it needs no locking).
 *
 * FMOD invokes event callbacks on its own threads. Those threads must never
 * touch Haxe/HL/hxcpp values or the handle table, so the callback handlers
 * write plain C records into this mutex-guarded ring. The Haxe thread drains
 * the queue during update() and dispatches typed callbacks.
 *
 * Overflow policy: when the ring is full the oldest event is dropped and an
 * overflow flag is set (readable and cleared from the Haxe thread). Events
 * are rare (a few per frame), so 256 entries is generous.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_CBQUEUE_H
#define FAXE_CBQUEUE_H

#include <stdint.h>
#include <string.h>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <pthread.h>
#endif

#define FAXE_CBQ_CAPACITY 256
#define FAXE_CBQ_STR_MAX 64

/* One callback event. Which fields are meaningful depends on type:
 *   TIMELINE_MARKER: str = marker name, i1 = position (ms)
 *   TIMELINE_BEAT:   i1 = bar, i2 = beat, i3 = position (ms), f1 = tempo,
 *                    i4 = time signature upper, i5 = time signature lower
 *   others:          only handle + type
 *
 * opaque carries a native payload across the thread boundary (the DESTROYED
 * event uses it for the per-instance context). Ownership transfers to the
 * drain: whoever pops the event must dispose of the payload. A payload
 * MUST begin with a void* qnext field, which the queue uses to park
 * payloads whose events get dropped on overflow (see faxe_cbq_take_orphans).
 */
typedef struct {
    int32_t handle;             /* event instance handle (from FMOD userdata) */
    uint32_t type;              /* FMOD_STUDIO_EVENT_CALLBACK_* bit */
    int32_t i1;
    int32_t i2;
    int32_t i3;
    int32_t i4;
    int32_t i5;
    float f1;
    void* opaque;               /* payload owned by the drain, or NULL */
    char str[FAXE_CBQ_STR_MAX]; /* UTF-8, truncated, always NUL-terminated */
} FaxeCbEvent;

static FaxeCbEvent gCbqRing[FAXE_CBQ_CAPACITY];
static int gCbqHead = 0;         /* next write position */
static int gCbqCount = 0;        /* number of queued events */
static int gCbqOverflow = 0;     /* set when an event was dropped */
static int gCbqInitialized = 0;
static void* gCbqOrphans = NULL; /* payloads of dropped events, linked by qnext */

#ifdef _WIN32
static CRITICAL_SECTION gCbqLock;
#else
static pthread_mutex_t gCbqLock = PTHREAD_MUTEX_INITIALIZER;
#endif

/* Must be called once from the Haxe thread (during init) before any
 * FMOD callback can fire. */
static void faxe_cbq_init(void) {
    if (gCbqInitialized) return;
#ifdef _WIN32
    InitializeCriticalSection(&gCbqLock);
#endif
    gCbqHead = 0;
    gCbqCount = 0;
    gCbqOverflow = 0;
    gCbqOrphans = NULL;
    gCbqInitialized = 1;
}

static void faxe_cbq_lock(void) {
#ifdef _WIN32
    EnterCriticalSection(&gCbqLock);
#else
    pthread_mutex_lock(&gCbqLock);
#endif
}

static void faxe_cbq_unlock(void) {
#ifdef _WIN32
    LeaveCriticalSection(&gCbqLock);
#else
    pthread_mutex_unlock(&gCbqLock);
#endif
}

/* Called from FMOD callback threads. Copies the event into the ring;
 * drops the oldest event when full. A dropped event's payload is parked on
 * the orphan list (freeing it here would race the game thread, which may
 * still hold a pointer to it). */
static void faxe_cbq_push(const FaxeCbEvent* event) {
    if (!gCbqInitialized) return;
    faxe_cbq_lock();
    if (gCbqCount == FAXE_CBQ_CAPACITY && gCbqRing[gCbqHead].opaque) {
        void* dropped = gCbqRing[gCbqHead].opaque;
        *(void**)dropped = gCbqOrphans;
        gCbqOrphans = dropped;
    }
    gCbqRing[gCbqHead] = *event;
    gCbqRing[gCbqHead].str[FAXE_CBQ_STR_MAX - 1] = '\0';
    gCbqHead = (gCbqHead + 1) % FAXE_CBQ_CAPACITY;
    if (gCbqCount < FAXE_CBQ_CAPACITY) {
        gCbqCount++;
    } else {
        gCbqOverflow = 1; /* head advanced onto the oldest entry - it is lost */
    }
    faxe_cbq_unlock();
}

/* Called from the Haxe thread. Returns 1 and fills out when an event was
 * popped (oldest first), 0 when the queue is empty. */
static int faxe_cbq_pop(FaxeCbEvent* out) {
    int tail;
    if (!gCbqInitialized) return 0;
    faxe_cbq_lock();
    if (gCbqCount == 0) {
        faxe_cbq_unlock();
        return 0;
    }
    tail = (gCbqHead - gCbqCount + FAXE_CBQ_CAPACITY) % FAXE_CBQ_CAPACITY;
    *out = gCbqRing[tail];
    gCbqCount--;
    faxe_cbq_unlock();
    return 1;
}

/* Returns the orphan list head (payloads of dropped events, linked through
 * their leading qnext field) and clears the list. The caller owns every
 * node and must dispose of each one. Haxe thread only. */
static void* faxe_cbq_take_orphans(void) {
    void* head;
    if (!gCbqInitialized) return NULL;
    faxe_cbq_lock();
    head = gCbqOrphans;
    gCbqOrphans = NULL;
    faxe_cbq_unlock();
    return head;
}

/* Returns and clears the overflow flag. Haxe thread only. */
static int faxe_cbq_take_overflow(void) {
    int overflowed;
    if (!gCbqInitialized) return 0;
    faxe_cbq_lock();
    overflowed = gCbqOverflow;
    gCbqOverflow = 0;
    faxe_cbq_unlock();
    return overflowed;
}

#endif /* FAXE_CBQUEUE_H */
