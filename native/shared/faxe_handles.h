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
 * so any retained stale handle fails to resolve. A slot at the last
 * generation retires, and the table grows past it. Callers then return
 * FMOD_ERR_INVALID_HANDLE and never touch freed memory.
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
#define FAXE_TYPE_SOUND 6  /* Core Sound */
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
     * lengths). A sound FMOD freed takes the lock with it, so the slot
     * only frees the record. */
    void* lock;
    /* malloc'd copy of an encoded file image a stream or an OPENONLY
     * sound reads from for its whole life. FMOD keeps reading it after
     * createSound returns. Freed with the slot, which a sound loses only
     * once FMOD released it. */
    void* image;
    unsigned short gen;   /* 1..FAXE_GEN_MAX once used, 0 = never used yet */
    unsigned char type;
    unsigned char alive;
    /* 1 when the game does not own the object. That is a programmer sound
     * the library created and releases, or a plugin instrument's DSP that
     * FMOD destroys with its event. A channel group or sound group the game
     * did not create carries the mark too. So does a sound or DSP first
     * reached through a walk. The public release entry points refuse such
     * a handle. */
    unsigned char owned;
    /* The handle this slot was reached from, or 0. That is the owned
     * sound a subsound was taken from, or the owner of a borrowed handle.
     * Freeing a handle frees every slot that names it here. */
    int parent;
    /* 1 once another slot named this one as its parent. A slot without
     * kids skips the table scan when it is freed. */
    unsigned char kids;
    /* How a handle the game did not create lives. FAXE_BORROWED_LINKED
     * dies with its parent. FAXE_BORROWED_VOLATILE also goes in
     * faxe_handles_free_volatile, since its object can die with no handle
     * of the table noticing. It is short-lived: it dies at the next update
     * or at the next call that stops, releases, or unloads anything. Only
     * the helpers below write this field, since they keep
     * gFaxeVolatileCount. */
    unsigned char borrowed;
    int next_free;        /* free-list link, -1 = end of list */
} FaxeSlot;

#define FAXE_BORROWED_NONE 0
#define FAXE_BORROWED_LINKED 1
#define FAXE_BORROWED_VOLATILE 2

static FaxeSlot* gFaxeSlots = NULL;
static int gFaxeSlotCap = 0;
static int gFaxeFreeHead = -1;
static int gFaxeLiveCount = 0;
/* Live slots whose borrowed kind is FAXE_BORROWED_VOLATILE. The per-update
 * drop returns at once while it is 0. */
static int gFaxeVolatileCount = 0;

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
    s->image = NULL;
    s->type = type;
    s->alive = 1;
    s->owned = 0;
    s->parent = 0;
    s->kids = 0;
    s->borrowed = FAXE_BORROWED_NONE;
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

/* Lookup handles (buses, VCAs, event descriptions) are cached for dedup
 * and normally live for the whole session. A bank unload kills their
 * FMOD objects while the slots stay alive. FMOD can later hand a
 * recycled address to a new object, and the pointer dedup would wrongly
 * match it. Sweeping right after an unload frees every lookup slot whose
 * object the validator reports dead. FMOD IsValid is documented safe on
 * destroyed objects, and address reuse cannot have happened yet inside
 * the same call. Bank slots are swept the same way: a single unload
 * frees its own slot, and unloadAll kills every bank at once. Channel
 * groups have no such check in FMOD, so they die with their owner
 * handle instead. The shims sweep instance slots after the same calls.
 * Sounds reclaim their slots through their own release paths. */
typedef int (*FaxeLookupValidator)(void* ptr, unsigned char type);
static void faxe_handle_free(int handle);
static void faxe_handles_sweep_lookups(FaxeLookupValidator is_valid) {
    int i;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        if (!s->alive) continue;
        if (s->type != FAXE_TYPE_BUS && s->type != FAXE_TYPE_VCA && s->type != FAXE_TYPE_EVD
            && s->type != FAXE_TYPE_BANK) continue;
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

/* Frees the slot and bumps its generation, or retires it, so stale handles
 * stop resolving. keepAux leaves the aux block allocated: a borrowed
 * handle can die while its object lives on, and FMOD keeps reading the
 * rolloff points it was lent. The few bytes leak instead. */
static void faxe_handle_free_slot(int handle, int keepAux) {
    int idx;
    int i;
    unsigned short gen;
    unsigned char kids;
    FaxeSlot* s;

    if (handle <= 0) return;
    idx = handle & 0xFFFF;
    gen = (unsigned short)((handle >> 16) & FAXE_GEN_MAX);
    if (idx >= gFaxeSlotCap) return;

    s = &gFaxeSlots[idx];
    if (!s->alive || s->gen != gen) return;

    kids = s->kids;
    if (s->borrowed == FAXE_BORROWED_VOLATILE) gFaxeVolatileCount--;
    s->alive = 0;
    s->owned = 0;
    s->parent = 0;
    s->kids = 0;
    s->borrowed = FAXE_BORROWED_NONE;
    s->ptr = NULL;
    if (s->aux && !keepAux) free(s->aux);
    s->aux = NULL;
    if (s->lock) { free(s->lock); s->lock = NULL; }
    if (s->image) { free(s->image); s->image = NULL; }
    s->type = FAXE_TYPE_NONE;
    gFaxeLiveCount--;
    /* A generation that wraps would let a retained stale handle resolve
     * again. A slot at the last generation retires and stays off the
     * free list. The table then grows past it. */
    if (s->gen < FAXE_GEN_MAX) {
        s->gen = (unsigned short)(s->gen + 1);
        s->next_free = gFaxeFreeHead;
        gFaxeFreeHead = idx;
    }
    if (!kids) return;
    /* Every handle reached from this one goes too, and theirs in turn.
     * Their objects can outlive them, so their aux blocks stay. */
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* c = &gFaxeSlots[i];
        if (c->alive && c->parent == handle) faxe_handle_free_slot(((int)c->gen << 16) | i, 1);
    }
}

static void faxe_handle_free(int handle) {
    faxe_handle_free_slot(handle, 0);
}

/* Whether a handle of any type still resolves: alive, with its generation. */
static int faxe_handle_is_live(int handle) {
    int idx;
    unsigned short gen;
    FaxeSlot* s;
    if (handle <= 0) return 0;
    idx = handle & 0xFFFF;
    gen = (unsigned short)((handle >> 16) & FAXE_GEN_MAX);
    if (idx >= gFaxeSlotCap) return 0;
    s = &gFaxeSlots[idx];
    return s->alive && s->gen == gen;
}

/* Marks the object behind a live handle as one the game does not own,
 * or clears the mark. The handle must resolve (callers check first). */
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

/* Links a live handle to the handle it was reached from. The handle must
 * resolve (callers check first). */
static void faxe_handle_set_parent(int handle, int parent) {
    gFaxeSlots[handle & 0xFFFF].parent = parent;
    if (parent > 0 && (parent & 0xFFFF) < gFaxeSlotCap) gFaxeSlots[parent & 0xFFFF].kids = 1;
}

/* Makes a live handle a borrowed one that dies with owner. An owner that
 * no longer resolves leaves the handle volatile instead. The handle must
 * resolve (callers check first). */
static void faxe_handle_set_owner(int handle, int owner) {
    FaxeSlot* s = &gFaxeSlots[handle & 0xFFFF];
    if (owner > 0 && owner != handle && faxe_handle_is_live(owner)) {
        faxe_handle_set_parent(handle, owner);
        if (s->borrowed == FAXE_BORROWED_NONE) s->borrowed = FAXE_BORROWED_LINKED;
    } else {
        s->parent = 0;
        if (s->borrowed != FAXE_BORROWED_VOLATILE) gFaxeVolatileCount++;
        s->borrowed = FAXE_BORROWED_VOLATILE;
    }
}

/* Marks a live borrowed handle volatile. The handle must resolve. */
static void faxe_handle_set_volatile(int handle) {
    FaxeSlot* s = &gFaxeSlots[handle & 0xFFFF];
    if (s->borrowed != FAXE_BORROWED_VOLATILE) gFaxeVolatileCount++;
    s->borrowed = FAXE_BORROWED_VOLATILE;
}

/* Gives a live handle a fixed lifetime again: no owner, not volatile.
 * The master groups take this, since they live as long as the system. */
static void faxe_handle_clear_owner(int handle) {
    FaxeSlot* s = &gFaxeSlots[handle & 0xFFFF];
    if (s->borrowed == FAXE_BORROWED_VOLATILE) gFaxeVolatileCount--;
    s->parent = 0;
    s->borrowed = FAXE_BORROWED_NONE;
}

/* The handle a live handle was reached from, 0 for none or a dead handle. */
static int faxe_handle_get_parent(int handle) {
    if (!faxe_handle_is_live(handle)) return 0;
    return gFaxeSlots[handle & 0xFFFF].parent;
}

/* The type tag of a live handle, FAXE_TYPE_NONE for a dead one. */
static unsigned char faxe_handle_get_type(int handle) {
    if (!faxe_handle_is_live(handle)) return FAXE_TYPE_NONE;
    return gFaxeSlots[handle & 0xFFFF].type;
}

/* How a live handle lives (FAXE_BORROWED_*), NONE for a dead one. */
static unsigned char faxe_handle_get_borrowed(int handle) {
    if (!faxe_handle_is_live(handle)) return FAXE_BORROWED_NONE;
    return gFaxeSlots[handle & 0xFFFF].borrowed;
}

/* The end of the owner chain above a live handle: the handle itself when
 * nothing owns it. A chain longer than the table is cut there. */
static int faxe_handle_root(int handle) {
    int steps = 0;
    while (steps++ < gFaxeSlotCap) {
        int parent = faxe_handle_get_parent(handle);
        if (parent == 0 || !faxe_handle_is_live(parent)) return handle;
        handle = parent;
    }
    return handle;
}

/* True for the types that hold a channel group for their whole life */
static int faxe_handle_is_group_owner_type(unsigned char type) {
    return type == FAXE_TYPE_EVI || type == FAXE_TYPE_BUS;
}

/* True when a live borrowed group handle came from a walk in the tree of
 * an instance or a bus other than root. Root is where the new request
 * starts, and both ends must be an instance or a bus. A handle anchored
 * straight under its instance or bus does not count. A walk from root
 * that reaches this address finds either a group that died there or one
 * the other tree walked out to. Both get a fresh handle. */
static int faxe_handle_walked_elsewhere(int handle, int root) {
    FaxeSlot* s;
    int end;
    if (!faxe_handle_is_live(handle)) return 0;
    s = &gFaxeSlots[handle & 0xFFFF];
    if (!s->owned || s->borrowed == FAXE_BORROWED_NONE) return 0;
    if (faxe_handle_is_group_owner_type(faxe_handle_get_type(s->parent))) return 0;
    end = faxe_handle_root(handle);
    if (end == root) return 0;
    return faxe_handle_is_group_owner_type(faxe_handle_get_type(end))
        && faxe_handle_is_group_owner_type(faxe_handle_get_type(root));
}

/* True when handle is from itself or a handle from was reached through,
 * at any depth. Linking handle below from would then close a loop. */
static int faxe_handle_on_chain(int handle, int from) {
    int steps = 0;
    while (from > 0 && steps++ < gFaxeSlotCap) {
        if (from == handle) return 1;
        from = faxe_handle_get_parent(from);
    }
    return 0;
}

/* Moves a volatile borrowed handle under owner and makes it linked. A
 * call that reaches the object through a longer-lived handle gives it
 * that handle's lifetime, whichever call came first. A linked handle
 * keeps the owner it has, so of two live owners the first one wins. An
 * owner hanging below the handle would close a loop and is refused.
 * Returns 1 when the handle moved. */
static int faxe_handle_adopt(int handle, int owner) {
    if (!faxe_handle_is_live(handle) || !faxe_handle_is_live(owner)) return 0;
    if (!gFaxeSlots[handle & 0xFFFF].owned || gFaxeSlots[handle & 0xFFFF].borrowed != FAXE_BORROWED_VOLATILE) return 0;
    if (faxe_handle_on_chain(handle, owner)) return 0;
    faxe_handle_clear_owner(handle);
    faxe_handle_set_owner(handle, owner);
    return 1;
}

/* Frees every volatile handle and what hangs off each. The shims call
 * this at the start of each update drain, after every accepted call
 * that stops, releases, or unloads anything, after an accepted bus
 * unlock, and after every bulk destroy sweep, refused or not. Calls
 * that run FMOD's command queue end them too. Those are the two flushes,
 * the bus lock, and a blocking bank load, which counts even when it
 * fails. Nothing tells them which of these objects died. With no
 * volatile slot alive it returns at once. */
static void faxe_handles_free_volatile(void) {
    int i;
    for (i = 0; i < gFaxeSlotCap && gFaxeVolatileCount > 0; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        if (s->alive && s->borrowed == FAXE_BORROWED_VOLATILE) faxe_handle_free_slot(((int)s->gen << 16) | i, 1);
    }
}

/* Frees every slot of one type that holds ptr. A new object at that
 * address proves each of them stale. */
static void faxe_handles_free_ptr(void* ptr, unsigned char type) {
    int i;
    if (!ptr) return;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FaxeSlot* s = &gFaxeSlots[i];
        if (s->alive && s->type == type && s->ptr == ptr) faxe_handle_free_slot(((int)s->gen << 16) | i, 0);
    }
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

/* Parks the image copy FMOD reads a memory sound from. The handle must
 * resolve (callers check first). */
static void faxe_handle_set_image(int handle, void* image) {
    FaxeSlot* s = &gFaxeSlots[handle & 0xFFFF];
    if (s->image) free(s->image);
    s->image = image;
}

static int faxe_live_handle_count(void) {
    return gFaxeLiveCount;
}

#endif /* FAXE_HANDLES_H */
