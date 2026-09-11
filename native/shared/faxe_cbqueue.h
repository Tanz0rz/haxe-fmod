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

/* Copies at most cap - 1 bytes of src into dst and terminates it. The
 * cut lands on a codepoint boundary, so a multi-byte character is
 * dropped whole and every shim hands Haxe the same text. */
static inline void faxe_str_copy(char* dst, const char* src, size_t cap) {
    size_t n = strlen(src);
    if (n < cap) { memcpy(dst, src, n + 1); return; }
    n = cap - 1;
    while (n > 0 && (((unsigned char)src[n]) & 0xC0) == 0x80) n--;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

#define FAXE_CBQ_CAPACITY 256
#define FAXE_CBQ_STR_MAX 64
#define FAXE_CBQ_STR2_MAX 128

/* One callback event. Which fields are meaningful depends on type:
 *   TIMELINE_MARKER: str = marker name, i1 = position (ms)
 *   TIMELINE_BEAT:   i1 = bar, i2 = beat, i3 = position (ms), f1 = tempo,
 *                    i4 = time signature upper, i5 = time signature lower
 *   NESTED_TIMELINE_BEAT: the beat fields above, str = GUID of the nested
 *                    event in FMOD's text form
 *   PLUGIN_CREATED:  str = plugin name, ptr = the FMOD_DSP, i3 = 1 when
 *                    the callback recorded it on the instance. The drain
 *                    mints the handle into i1 and records it too.
 *   PLUGIN_DESTROYED: str = plugin name, ptr = the dead FMOD_DSP, i1 = the
 *                    recorded handle the callback took (0 when none), i3 =
 *                    1 when the callback found the record. The drain frees i1.
 *   CREATE_PROGRAMMER_SOUND: str = instrument name, ptr = the FMOD_SOUND
 *                    the instrument plays, i2 = subsound index, i3 = 1 when
 *                    the shim created the sound. The drain mints i1 for a
 *                    shim sound and finds it for a game sound.
 *   DESTROY_PROGRAMMER_SOUND: the same fields, i1 = the recorded handle
 *                    the callback took for a shim sound, which the drain
 *                    frees. A game sound stays live and is found by address.
 *   core ERROR (system namespace): i1 = FMOD_RESULT, i2 = instance type,
 *                    ptr = the failing object, str = function name,
 *                    str2 = function parameters
 *   others:          only handle + type
 *
 * opaque carries a native payload across the thread boundary (the DESTROYED
 * event uses it for the per-instance context). Ownership transfers to the
 * drain: whoever pops the event must dispose of the payload. A payload
 * MUST begin with a void* qnext field, which the queue uses to park
 * payloads whose events get dropped on overflow (see faxe_cbq_take_orphans).
 *
 * ptr is a borrowed FMOD object address with no ownership. The queue never
 * reads it, and a dropped event just loses it. The drain resolves it on the
 * Haxe thread, where the handle table is safe to touch.
 *
 * freesI1 marks a record whose i1 handle the drain frees. A dropped record
 * of that kind parks the handle in a small list the drain frees later
 * (see faxe_cbq_take_dropped_handles), so an overflow leaks no slot.
 * jaxe.js frees such handles in the callback itself and needs no mark.
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
    int32_t freesI1;            /* 1 when the drain frees the handle in i1, see above */
    void* opaque;               /* payload owned by the drain, or NULL */
    void* ptr;                  /* borrowed FMOD object for the drain, or NULL */
    char str[FAXE_CBQ_STR_MAX]; /* UTF-8, truncated, always NUL-terminated */
    char str2[FAXE_CBQ_STR2_MAX]; /* second string, same rules, empty for most types */
} FaxeCbEvent;

static FaxeCbEvent gCbqRing[FAXE_CBQ_CAPACITY];
static int gCbqHead = 0;         /* next write position */
static int gCbqCount = 0;        /* number of queued events */
static int gCbqOverflow = 0;     /* set when an event was dropped */
static int gCbqInitialized = 0;
static void* gCbqOrphans = NULL; /* payloads of dropped events, linked by qnext */
#define FAXE_CBQ_DROPPED_MAX 64
static int gCbqDroppedHandles[FAXE_CBQ_DROPPED_MAX]; /* handles of dropped freesI1 records */
static int gCbqDroppedCount = 0;

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
    gCbqDroppedCount = 0;
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

/* Called from FMOD callback threads. Copies the event into the ring, and
 * drops the oldest event when full. A dropped event's payload is parked
 * on the orphan list. Freeing it here would race the game thread, which
 * can still hold a pointer to it. */
static void faxe_cbq_push(const FaxeCbEvent* event) {
    if (!gCbqInitialized) return;
    faxe_cbq_lock();
    if (gCbqCount == FAXE_CBQ_CAPACITY && gCbqRing[gCbqHead].opaque) {
        void* dropped = gCbqRing[gCbqHead].opaque;
        *(void**)dropped = gCbqOrphans;
        gCbqOrphans = dropped;
    }
    /* The handle of a dropped destroy record waits for the drain. The
     * list holds far more than one frame drops, and a full list leaks
     * the slot rather than blocking the FMOD thread. */
    if (gCbqCount == FAXE_CBQ_CAPACITY && gCbqRing[gCbqHead].freesI1 && gCbqRing[gCbqHead].i1
            && gCbqDroppedCount < FAXE_CBQ_DROPPED_MAX) {
        gCbqDroppedHandles[gCbqDroppedCount++] = gCbqRing[gCbqHead].i1;
    }
    gCbqRing[gCbqHead] = *event;
    gCbqRing[gCbqHead].str[FAXE_CBQ_STR_MAX - 1] = '\0';
    gCbqRing[gCbqHead].str2[FAXE_CBQ_STR2_MAX - 1] = '\0';
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

/* Copies the handles of dropped freesI1 records into out (at most cap)
 * and clears the list. The caller frees each one. Haxe thread only. */
static int faxe_cbq_take_dropped_handles(int* out, int cap) {
    int n = 0;
    if (!gCbqInitialized) return 0;
    faxe_cbq_lock();
    while (n < gCbqDroppedCount && n < cap) { out[n] = gCbqDroppedHandles[n]; n++; }
    gCbqDroppedCount = 0;
    faxe_cbq_unlock();
    return n;
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

/* Bank paths for the Studio BANK_UNLOAD callback. FMOD refuses reads on
 * the bank inside that callback (NOTREADY). The unload paths stash the
 * path here first, keyed by the bank pointer, and the callback takes it.
 * Guarded by the queue lock: written on the Haxe thread, read on the
 * Studio thread. A full table overwrites the oldest entry.
 * Entries hold the whole path at the 512-byte native string size, so a
 * long bank path reaches the stash instead of failing the read. The event
 * record is narrower, so the take truncates. */
#define FAXE_BANKPATH_CAPACITY 256
#define FAXE_BANKPATH_STR_MAX 512

typedef struct {
    const void* bank;
    char path[FAXE_BANKPATH_STR_MAX];
} FaxeBankPathEntry;

static FaxeBankPathEntry gBankPaths[FAXE_BANKPATH_CAPACITY];
static int gBankPathHead = 0;

static void faxe_bankpath_put(const void* bank, const char* path) {
    int i;
    if (!gCbqInitialized || !bank || !path || !path[0]) return;
    faxe_cbq_lock();
    for (i = 0; i < FAXE_BANKPATH_CAPACITY; i++) {
        if (gBankPaths[i].bank == bank) break;
    }
    if (i == FAXE_BANKPATH_CAPACITY) {
        /* An empty slot first. Only a full table evicts the oldest. */
        for (i = 0; i < FAXE_BANKPATH_CAPACITY; i++) {
            if (gBankPaths[i].bank == NULL) break;
        }
    }
    if (i == FAXE_BANKPATH_CAPACITY) {
        i = gBankPathHead;
        gBankPathHead = (gBankPathHead + 1) % FAXE_BANKPATH_CAPACITY;
    }
    gBankPaths[i].bank = bank;
    faxe_str_copy(gBankPaths[i].path, path, FAXE_BANKPATH_STR_MAX);
    faxe_cbq_unlock();
}

/* Copies the stashed path into out (FAXE_CBQ_STR_MAX bytes, the event
 * record's string size, so a longer path arrives cut) and frees the
 * entry. Returns 1 when found, 0 otherwise (out is then empty). */
static int faxe_bankpath_take(const void* bank, char* out) {
    int i;
    int found = 0;
    out[0] = '\0';
    if (!gCbqInitialized || !bank) return 0;
    faxe_cbq_lock();
    for (i = 0; i < FAXE_BANKPATH_CAPACITY; i++) {
        if (gBankPaths[i].bank == bank) {
            faxe_str_copy(out, gBankPaths[i].path, FAXE_CBQ_STR_MAX);
            gBankPaths[i].bank = NULL;
            gBankPaths[i].path[0] = '\0';
            found = 1;
            break;
        }
    }
    faxe_cbq_unlock();
    return found;
}

static void faxe_bankpath_clear(void) {
    int i;
    if (!gCbqInitialized) return;
    faxe_cbq_lock();
    for (i = 0; i < FAXE_BANKPATH_CAPACITY; i++) {
        gBankPaths[i].bank = NULL;
        gBankPaths[i].path[0] = '\0';
    }
    faxe_cbq_unlock();
}

#endif /* FAXE_CBQUEUE_H */
