/**
 * Shared PCM ring buffer for user-generated audio (OPENUSER sounds).
 *
 * Used by both linc_faxe.cpp (C++) and hlaxe_fmod.c (C99) via #include.
 * jaxe.js re-implements the same contract with a typed array (JS is
 * single-threaded, so it needs no locking).
 *
 * The game thread writes PCM bytes from Haxe; FMOD's mixer thread drains
 * them inside the pcmread callback, which is plain C and never touches
 * Haxe/HL/hxcpp values. Both sides take a per-ring mutex for a short
 * memcpy, the same discipline the callback queue uses.
 *
 * Underrun policy: the pcmread contract requires the full buffer every
 * call, so a short read is padded with silence and counted. The count is
 * readable and cleared from the Haxe thread for diagnostics.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_PCMRING_H
#define FAXE_PCMRING_H

#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <pthread.h>
#endif

typedef struct FaxePcmRing {
    unsigned char* buf;
    int capacity;   /* bytes */
    int readPos;
    int writePos;
    int fill;       /* readable bytes */
    int underruns;  /* short reads since last take */
#ifdef _WIN32
    CRITICAL_SECTION lock;
#else
    pthread_mutex_t lock;
#endif
} FaxePcmRing;

static void faxe_pcmring_lock(FaxePcmRing* r) {
#ifdef _WIN32
    EnterCriticalSection(&r->lock);
#else
    pthread_mutex_lock(&r->lock);
#endif
}

static void faxe_pcmring_unlock(FaxePcmRing* r) {
#ifdef _WIN32
    LeaveCriticalSection(&r->lock);
#else
    pthread_mutex_unlock(&r->lock);
#endif
}

/* Game thread. Returns NULL when the allocation fails. */
static FaxePcmRing* faxe_pcmring_create(int capacityBytes) {
    FaxePcmRing* r;
    if (capacityBytes <= 0) return NULL;
    r = (FaxePcmRing*)malloc(sizeof(FaxePcmRing));
    if (!r) return NULL;
    r->buf = (unsigned char*)malloc((size_t)capacityBytes);
    if (!r->buf) {
        free(r);
        return NULL;
    }
    r->capacity = capacityBytes;
    r->readPos = 0;
    r->writePos = 0;
    r->fill = 0;
    r->underruns = 0;
#ifdef _WIN32
    InitializeCriticalSection(&r->lock);
#else
    pthread_mutex_init(&r->lock, NULL);
#endif
    return r;
}

/* Game thread. The mixer must no longer reference the ring (release the
 * sound and let FMOD process it first). */
static void faxe_pcmring_destroy(FaxePcmRing* r) {
    if (!r) return;
#ifdef _WIN32
    DeleteCriticalSection(&r->lock);
#else
    pthread_mutex_destroy(&r->lock);
#endif
    free(r->buf);
    free(r);
}

/* Game thread: appends up to len bytes, returns how many fit. */
static int faxe_pcmring_write(FaxePcmRing* r, const void* data, int len) {
    const unsigned char* src = (const unsigned char*)data;
    int space, first;
    if (!r || !src || len <= 0) return 0;
    faxe_pcmring_lock(r);
    space = r->capacity - r->fill;
    if (len > space) len = space;
    first = r->capacity - r->writePos;
    if (first > len) first = len;
    memcpy(r->buf + r->writePos, src, (size_t)first);
    if (len > first) memcpy(r->buf, src + first, (size_t)(len - first));
    r->writePos = (r->writePos + len) % r->capacity;
    r->fill += len;
    faxe_pcmring_unlock(r);
    return len;
}

/* Mixer thread: fills out with exactly len bytes, padding a shortfall with
 * silence and counting it as an underrun. Returns the bytes that carried
 * real data. */
static int faxe_pcmring_read(FaxePcmRing* r, void* out, int len) {
    unsigned char* dst = (unsigned char*)out;
    int have, first;
    if (!r || !dst || len <= 0) return 0;
    faxe_pcmring_lock(r);
    have = r->fill < len ? r->fill : len;
    first = r->capacity - r->readPos;
    if (first > have) first = have;
    memcpy(dst, r->buf + r->readPos, (size_t)first);
    if (have > first) memcpy(dst + first, r->buf, (size_t)(have - first));
    r->readPos = (r->readPos + have) % r->capacity;
    r->fill -= have;
    if (have < len) {
        memset(dst + have, 0, (size_t)(len - have));
        r->underruns++;
    }
    faxe_pcmring_unlock(r);
    return have;
}

/* Game thread: bytes that can be written right now. */
static int faxe_pcmring_space(FaxePcmRing* r) {
    int space;
    if (!r) return 0;
    faxe_pcmring_lock(r);
    space = r->capacity - r->fill;
    faxe_pcmring_unlock(r);
    return space;
}

/* Game thread: bytes queued for the mixer. */
static int faxe_pcmring_fill(FaxePcmRing* r) {
    int fill;
    if (!r) return 0;
    faxe_pcmring_lock(r);
    fill = r->fill;
    faxe_pcmring_unlock(r);
    return fill;
}

/* Game thread: underruns since the last call, clearing the count. */
static int faxe_pcmring_take_underruns(FaxePcmRing* r) {
    int n;
    if (!r) return 0;
    faxe_pcmring_lock(r);
    n = r->underruns;
    r->underruns = 0;
    faxe_pcmring_unlock(r);
    return n;
}

#endif /* FAXE_PCMRING_H */
