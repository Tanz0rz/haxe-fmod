/**
 * Shared generational handle table for the haxefmod native shims.
 *
 * Used by both linc_faxe.cpp (C++) and hlaxe_fmod.c (C99) via #include.
 * jaxe.js re-implements the same logic in JavaScript.
 *
 * Handle encoding: (generation << 16) | index
 * - index:      bits 0-15  (up to 65536 slots)
 * - generation: bits 16-30, range 1..0x7FFF, never 0
 * - bit 31 unused, so handles are always positive ints
 * - handle value 0 is always invalid (generation can never be 0)
 *
 * Generations catch use-after-release. Freeing a slot bumps its generation,
 * so any retained stale handle fails to resolve. Callers then return
 * FMOD_ERR_INVALID_HANDLE instead of touching freed memory.
 *
 * Threading: the table must only be mutated from the Haxe thread. FMOD
 * callback threads must never call these functions. They receive handles
 * through FMOD userdata instead.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_HANDLES_H
#define FAXE_HANDLES_H

#include <stdlib.h>
#include <string.h>

/* Handle type tags - prevent cross-type handle misuse */
#define FAXE_TYPE_NONE  0
#define FAXE_TYPE_EVI   1  /* Studio EventInstance */
#define FAXE_TYPE_EVD   2  /* Studio EventDescription */
#define FAXE_TYPE_BANK  3  /* Studio Bank */
#define FAXE_TYPE_BUS   4  /* Studio Bus */
#define FAXE_TYPE_VCA   5  /* Studio VCA */
#define FAXE_TYPE_SOUND 6  /* Core Sound (programmer sounds only) */
#define FAXE_TYPE_PCM   7  /* Core PCM stream (OPENUSER sound + ring) */
#define FAXE_TYPE_CHAN  8  /* Core Channel */
#define FAXE_TYPE_DSP   9  /* Core DSP effect */
#define FAXE_TYPE_CHANGROUP 10  /* Core ChannelGroup */
#define FAXE_TYPE_DSPCONN 11  /* Core DSPConnection */
#define FAXE_TYPE_REVERB3D 12  /* Core Reverb3D zone */
#define FAXE_TYPE_SOUNDGROUP 13  /* Core SoundGroup */
#define FAXE_TYPE_REPLAY 14  /* Studio CommandReplay */
#define FAXE_TYPE_GEOMETRY 15  /* Core Geometry */

#define FAXE_MAX_SLOTS 0x10000
/* Max entries any list getter returns in one call. The Haxe-side scratch
 * buffer (Scratch.CAPACITY) must match. Far beyond realistic FMOD projects,
 * and the abstracts warn when a list is larger and gets truncated. */
#define FAXE_LIST_MAX 1024
#define FAXE_GEN_MAX   0x7FFF

typedef struct {
    void* ptr;
    /* malloc'd memory the shim hands FMOD for the object's lifetime (the
     * custom rolloff point array). Freed with the slot. */
    void* aux;
    /* malloc'd record of the open Sound::lock range (both pointers and
     * lengths). The shim closes the lock on a live sound before the slot
     * dies, and a sound FMOD freed takes the lock with it. The slot only
     * frees the record. */
    void* lock;
    unsigned short gen;   /* 1..FAXE_GEN_MAX once used, 0 = never used yet */
    unsigned char type;
    unsigned char alive;
    /* 1 when the game does not own the object. That is a programmer sound
     * the library created and releases, or a plugin instrument's DSP that
     * FMOD destroys with its event. The public release entry points
     * refuse such a handle. */
    unsigned char owned;
    /* The handle of the owned sound this subsound was taken from, or 0.
     * Such a child dies with its parent (see faxe_handles_free_children). */
    int parent;
    int next_free;        /* free-list link, -1 = end of list */
} FaxeSlot;

static FaxeSlot* gFaxeSlots = NULL;
static int gFaxeSlotCap = 0;
static int gFaxeFreeHead = -1;
static int gFaxeLiveCount = 0;

/* Doubling growth. Links new slots into the free list (lowest index first). */
static int faxe_handles_grow(void) {
    int newCap;
    int i;
    FaxeSlot* ns;

    newCap = (gFaxeSlotCap == 0) ? 64 : gFaxeSlotCap * 2;
    if (newCap > FAXE_MAX_SLOTS) newCap = FAXE_MAX_SLOTS;
    if (newCap <= gFaxeSlotCap) return 0; /* table is at maximum capacity */

    ns = (FaxeSlot*)realloc(gFaxeSlots, (size_t)newCap * sizeof(FaxeSlot));
    if (!ns) return 0;
    memset(ns + gFaxeSlotCap, 0, (size_t)(newCap - gFaxeSlotCap) * sizeof(FaxeSlot));

    for (i = newCap - 1; i >= gFaxeSlotCap; i--) {
        ns[i].next_free = gFaxeFreeHead;
        gFaxeFreeHead = i;
    }

    gFaxeSlots = ns;
    gFaxeSlotCap = newCap;
    return 1;
}

/* Returns a positive handle, or 0 on failure (null ptr / out of slots). */
static int faxe_handle_alloc(void* ptr, unsigned char type) {
    int idx;
    FaxeSlot* s;

    if (!ptr) return 0;
    if (gFaxeFreeHead < 0 && !faxe_handles_grow()) return 0;

    idx = gFaxeFreeHead;
    gFaxeFreeHead = gFaxeSlots[idx].next_free;

    s = &gFaxeSlots[idx];
    s->ptr = ptr;
    s->aux = NULL;
    s->lock = NULL;
    s->type = type;
    s->alive = 1;
    s->owned = 0;
    s->parent = 0;
    if (s->gen == 0) s->gen = 1; /* first use of this slot */

    gFaxeLiveCount++;
    return ((int)s->gen << 16) | idx;
}

/* Returns the existing handle for a pointer already in the table (same type),
 * 0 when the table has never seen it. Linear scan is fine: called only from
 * the Haxe thread on lookup paths. find_or_alloc allocates when the scan
 * misses. That prevents duplicate handles when FMOD returns the same object
 * from multiple lookups (e.g. getBus by path then by ID). */
static int faxe_handle_find(void* ptr, unsigned char type) {
    int i;
    if (!ptr) return 0;
    for (i = 0; i < gFaxeSlotCap; i++) {
        if (gFaxeSlots[i].alive && gFaxeSlots[i].ptr == ptr && gFaxeSlots[i].type == type) {
            return ((int)gFaxeSlots[i].gen << 16) | i;
        }
    }
    return 0;
}

static int faxe_handle_find_or_alloc(void* ptr, unsigned char type) {
    int found = faxe_handle_find(ptr, type);
    if (found) return found;
    return faxe_handle_alloc(ptr, type);
}

/* Lookup handles (buses, VCAs, event descriptions, channel groups) are
 * cached for dedup and normally live for the whole session. A bank
 * unload kills their FMOD objects while the slots stay alive. FMOD can
 * later hand a recycled address to a new object, and the pointer dedup
 * would wrongly match it. Sweeping right after an unload frees every
 * lookup slot whose object the validator reports dead. FMOD IsValid is
 * documented safe on destroyed objects, and address reuse cannot have
 * happened yet inside the same call. Bank slots are swept the same
 * way: a single unload frees its own slot, and unloadAll kills every
 * bank at once. Instances and sounds reclaim their slots through their
 * own release paths. */
typedef int (*FaxeLookupValidator)(void* ptr, unsigned char type);
static void faxe_handle_free(int handle);
static void faxe_handles_sweep_lookups(FaxeLookupValidator is_valid) {
    int i;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        if (!s->alive) continue;
        if (s->type != FAXE_TYPE_BUS && s->type != FAXE_TYPE_VCA && s->type != FAXE_TYPE_EVD
            && s->type != FAXE_TYPE_CHANGROUP && s->type != FAXE_TYPE_BANK) continue;
        if (!is_valid(s->ptr, s->type)) {
            faxe_handle_free(((int)s->gen << 16) | i);
        }
    }
}

/* Frees every live slot of one type whose object the validator rejects.
 * Core channels use this: a channel that ended on its own keeps its slot
 * until the next channel play or lookup sweeps it. The hook, when given,
 * runs on each rejected slot before the free. A shim detaches there what
 * the slot's aux block still lends to FMOD. */
typedef void (*FaxeSlotHook)(void* ptr, int handle);
static void faxe_handles_sweep_type(unsigned char type, FaxeLookupValidator is_valid, FaxeSlotHook before_free) {
    int i;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        int handle;
        if (!s->alive || s->type != type) continue;
        if (is_valid(s->ptr, s->type)) continue;
        handle = ((int)s->gen << 16) | i;
        if (before_free) before_free(s->ptr, handle);
        faxe_handle_free(handle);
    }
}

/* Frees every live slot of one type. DSP connections use this: FMOD defers
 * graph mutations to the mixer, so pointer validation after a disconnect is
 * timing-dependent. Graph-changing calls instead invalidate every connection
 * handle, which is also FMOD's own documented contract for them. */
static void faxe_handles_free_type(unsigned char type) {
    int i;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        if (s->alive && s->type == type) {
            faxe_handle_free(((int)s->gen << 16) | i);
        }
    }
}

/* Returns the stored pointer, or NULL if the handle is stale/invalid/mistyped. */
static void* faxe_handle_resolve(int handle, unsigned char type) {
    int idx;
    unsigned short gen;
    FaxeSlot* s;

    if (handle <= 0) return NULL;
    idx = handle & 0xFFFF;
    gen = (unsigned short)((handle >> 16) & FAXE_GEN_MAX);
    if (idx >= gFaxeSlotCap) return NULL;

    s = &gFaxeSlots[idx];
    if (!s->alive || s->gen != gen || s->type != type) return NULL;
    return s->ptr;
}

/* Frees the slot and bumps its generation so stale handles stop resolving. */
static void faxe_handle_free(int handle) {
    int idx;
    unsigned short gen;
    FaxeSlot* s;

    if (handle <= 0) return;
    idx = handle & 0xFFFF;
    gen = (unsigned short)((handle >> 16) & FAXE_GEN_MAX);
    if (idx >= gFaxeSlotCap) return;

    s = &gFaxeSlots[idx];
    if (!s->alive || s->gen != gen) return;

    s->alive = 0;
    s->owned = 0;
    s->parent = 0;
    s->ptr = NULL;
    if (s->aux) { free(s->aux); s->aux = NULL; }
    if (s->lock) { free(s->lock); s->lock = NULL; }
    s->type = FAXE_TYPE_NONE;
    s->gen = (unsigned short)((s->gen % FAXE_GEN_MAX) + 1); /* wraps 1..FAXE_GEN_MAX, never 0 */
    s->next_free = gFaxeFreeHead;
    gFaxeFreeHead = idx;
    gFaxeLiveCount--;
}

/* Marks the object behind a live handle as owned by the library, or
 * clears the mark. The handle must resolve (callers check first). */
static void faxe_handle_set_owned(int handle, int owned) {
    gFaxeSlots[handle & 0xFFFF].owned = (unsigned char)(owned ? 1 : 0);
}

/* True for a live handle whose object the library owns. */
static int faxe_handle_is_owned(int handle) {
    int idx = handle & 0xFFFF;
    unsigned short gen = (unsigned short)((handle >> 16) & FAXE_GEN_MAX);
    if (handle <= 0 || idx >= gFaxeSlotCap) return 0;
    return gFaxeSlots[idx].alive && gFaxeSlots[idx].gen == gen && gFaxeSlots[idx].owned;
}

/* Links a live subsound handle to its owned parent. The handle must
 * resolve (callers check first). */
static void faxe_handle_set_parent(int handle, int parent) {
    gFaxeSlots[handle & 0xFFFF].parent = parent;
}

/* Frees every live slot linked to the parent handle, and the slots
 * linked to those in turn. The parent's own slot is left to the caller.
 * before_free, when given, runs on each child while it still resolves,
 * so a caller whose objects are alive can close a lock first. */
static void faxe_handles_free_children(int parent, FaxeSlotHook before_free) {
    int i;
    if (parent <= 0) return;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        if (s->alive && s->parent == parent) {
            int child = ((int)s->gen << 16) | i;
            if (child == parent) continue; /* a slot never parents itself */
            faxe_handles_free_children(child, before_free);
            if (before_free) before_free(s->ptr, child);
            faxe_handle_free(child);
        }
    }
}

/* Replaces the slot's owned memory, freeing the previous block. The handle
 * must resolve (callers check first). Passing NULL just frees. */
static void faxe_handle_set_aux(int handle, void* aux) {
    int idx = handle & 0xFFFF;
    FaxeSlot* s = &gFaxeSlots[idx];
    if (s->aux) free(s->aux);
    s->aux = aux;
}

/* The slot's owned memory, NULL when none is parked. The handle must
 * resolve (callers check first). */
static void* faxe_handle_get_aux(int handle) {
    return gFaxeSlots[handle & 0xFFFF].aux;
}

/* The lock record parked on a handle, NULL when no lock is open. The
 * handle must resolve (callers check first). */
static void* faxe_handle_get_lock(int handle) {
    return gFaxeSlots[handle & 0xFFFF].lock;
}

/* Parks a lock record on the handle, freeing the previous one. NULL just
 * frees. Same contract as faxe_handle_set_aux. */
static void faxe_handle_set_lock(int handle, void* lock) {
    FaxeSlot* s = &gFaxeSlots[handle & 0xFFFF];
    if (s->lock) free(s->lock);
    s->lock = lock;
}

static int faxe_live_handle_count(void) {
    return gFaxeLiveCount;
}

#endif /* FAXE_HANDLES_H */
