/*
 * Unit tests for native/shared/faxe_handles.h (the generational handle table
 * shared by the C++ and HashLink shims. jaxe.js mirrors the same logic).
 *
 * CI compiles and runs the file in both C99 and C++ modes. Both
 * invocations:
 *   gcc -std=c99 -Wall -Wextra -Werror -o test_c   tests/native/test_faxe_handles.c && ./test_c
 *   g++ -x c++   -Wall -Wextra -Werror -o test_cpp tests/native/test_faxe_handles.c && ./test_cpp
 */
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "../../native/shared/faxe_handles.h"

static int sweep_all_valid(void* ptr, unsigned char type) {
    (void)ptr; (void)type;
    return 1;
}

static void* gRejected = NULL;
static int sweep_reject_one(void* ptr, unsigned char type) {
    (void)type;
    return ptr != gRejected;
}

static void* gHookPtr = NULL;
static int gHookHandle = 0;
static int gHookCalls = 0;
static unsigned char gHookExpectType = FAXE_TYPE_NONE;
static void sweep_note_free(void* ptr, int handle) {
    /* the hook runs while the slot still resolves to that object, as the
     * type the caller expects */
    assert(faxe_handle_resolve(handle, gHookExpectType) == ptr);
    gHookPtr = ptr;
    gHookHandle = handle;
    gHookCalls++;
}

static int sweep_all_dead(void* ptr, unsigned char type) {
    (void)ptr; (void)type;
    return 0;
}

/* The volatile kind as the table holds it, counted the slow way */
static int count_volatile_slots(void) {
    int i;
    int n = 0;
    for (i = 0; i < gFaxeSlotCap; i++) {
        if (gFaxeSlots[i].alive && gFaxeSlots[i].borrowed == FAXE_BORROWED_VOLATILE) n++;
    }
    return n;
}


/* Seeded pseudo-random fuzz with a shadow model. Arbitrary integers into
 * resolve and free must behave exactly like the model predicts. A random
 * int resolves to a live slot's pointer only when it IS that slot's
 * current handle with the right type. It frees only that exact handle,
 * and it never corrupts unrelated live entries. Deterministic (fixed
 * seed), and run under ASan/UBSan in CI so a wild read or overflow fails
 * loudly. */
#define FUZZ_OPS 200000
#define FUZZ_LIVE_MAX 512
#define FUZZ_TYPES 4

static unsigned int gFuzzState = 0x243F6A88u;

static unsigned int fuzz_next(void) {
    gFuzzState ^= gFuzzState << 13;
    gFuzzState ^= gFuzzState >> 17;
    gFuzzState ^= gFuzzState << 5;
    return gFuzzState;
}

typedef struct {
    int handle;
    void* ptr;
    unsigned char type;
} FuzzLive;

static FuzzLive gFuzzLive[FUZZ_LIVE_MAX];
static int gFuzzLiveCount = 0;
static int gFuzzArena[FUZZ_LIVE_MAX];

static FuzzLive* fuzz_model_find(int handle) {
    int i;
    for (i = 0; i < gFuzzLiveCount; i++) {
        if (gFuzzLive[i].handle == handle) return &gFuzzLive[i];
    }
    return NULL;
}

static void fuzz_model_remove(int handle) {
    FuzzLive* entry = fuzz_model_find(handle);
    if (entry) *entry = gFuzzLive[--gFuzzLiveCount];
}

static void test_fuzz_against_model(void) {
    int op;
    for (op = 0; op < FUZZ_OPS; op++) {
        unsigned int roll = fuzz_next() % 100;
        if (roll < 35 && gFuzzLiveCount < FUZZ_LIVE_MAX) {
            /* alloc a handle for an arena pointer */
            int slot = (int)(fuzz_next() % FUZZ_LIVE_MAX);
            unsigned char type = (unsigned char)(1 + fuzz_next() % FUZZ_TYPES);
            int handle = faxe_handle_alloc(&gFuzzArena[slot], type);
            assert(handle > 0);
            assert(fuzz_model_find(handle) == NULL); /* never a duplicate */
            gFuzzLive[gFuzzLiveCount].handle = handle;
            gFuzzLive[gFuzzLiveCount].ptr = &gFuzzArena[slot];
            gFuzzLive[gFuzzLiveCount].type = type;
            gFuzzLiveCount++;
        } else if (roll < 55 && gFuzzLiveCount > 0) {
            /* free a known-live handle */
            int at = (int)(fuzz_next() % (unsigned int)gFuzzLiveCount);
            int handle = gFuzzLive[at].handle;
            unsigned char type = gFuzzLive[at].type;
            faxe_handle_free(handle);
            fuzz_model_remove(handle);
            assert(faxe_handle_resolve(handle, type) == NULL); /* stale now */
        } else if (roll < 75) {
            /* free an arbitrary integer: only an exact live handle dies */
            int garbage = (int)fuzz_next();
            FuzzLive* hit = fuzz_model_find(garbage);
            faxe_handle_free(garbage);
            if (hit) fuzz_model_remove(garbage);
        } else {
            /* resolve an arbitrary integer against a random type: the
             * model predicts the exact outcome */
            int garbage = (int)fuzz_next();
            unsigned char type = (unsigned char)(1 + fuzz_next() % FUZZ_TYPES);
            FuzzLive* hit = fuzz_model_find(garbage);
            void* expected = (hit && hit->type == type) ? hit->ptr : NULL;
            assert(faxe_handle_resolve(garbage, type) == expected);
        }
        /* every 4096 ops, audit the whole live set */
        if ((op & 0xFFF) == 0) {
            int i;
            for (i = 0; i < gFuzzLiveCount; i++) {
                assert(faxe_handle_resolve(gFuzzLive[i].handle, gFuzzLive[i].type)
                    == gFuzzLive[i].ptr);
            }
        }
    }
    while (gFuzzLiveCount > 0) {
        faxe_handle_free(gFuzzLive[0].handle);
        fuzz_model_remove(gFuzzLive[0].handle);
    }
}

int main(void) {
    int dummy1 = 1, dummy2 = 2, dummy3 = 3;

    /* invalid resolves */
    assert(faxe_handle_resolve(0, FAXE_TYPE_EVI) == NULL);
    assert(faxe_handle_resolve(-1, FAXE_TYPE_EVI) == NULL);
    assert(faxe_handle_resolve(12345, FAXE_TYPE_EVI) == NULL);
    assert(faxe_handle_alloc(NULL, FAXE_TYPE_EVI) == 0);

    /* alloc + resolve */
    int h1 = faxe_handle_alloc(&dummy1, FAXE_TYPE_EVI);
    assert(h1 > 0);
    assert((h1 & 0xFFFF) == 0);           /* first slot */
    assert(((h1 >> 16) & 0x7FFF) == 1);   /* generation starts at 1 */
    assert(faxe_handle_resolve(h1, FAXE_TYPE_EVI) == &dummy1);
    assert(faxe_handle_resolve(h1, FAXE_TYPE_BUS) == NULL); /* type tag mismatch */
    assert(faxe_live_handle_count() == 1);

    /* find reports the live handle for a known pointer and type, 0 for
     * anything else, and never allocates */
    assert(faxe_handle_find(&dummy1, FAXE_TYPE_EVI) == h1);
    assert(faxe_handle_find(&dummy1, FAXE_TYPE_BUS) == 0);
    assert(faxe_handle_find(&dummy2, FAXE_TYPE_EVI) == 0);
    assert(faxe_handle_find(NULL, FAXE_TYPE_EVI) == 0);
    assert(faxe_live_handle_count() == 1);
    assert(faxe_handle_find_or_alloc(&dummy1, FAXE_TYPE_EVI) == h1);
    assert(faxe_live_handle_count() == 1);

    /* free -> stale handle stops resolving */
    faxe_handle_free(h1);
    assert(faxe_handle_resolve(h1, FAXE_TYPE_EVI) == NULL);
    assert(faxe_handle_find(&dummy1, FAXE_TYPE_EVI) == 0);
    assert(faxe_live_handle_count() == 0);
    faxe_handle_free(h1); /* double free is a safe no-op */
    assert(faxe_live_handle_count() == 0);

    /* aux memory dies with the handle and is replaced on a second set */
    {
        int ha = faxe_handle_alloc(&dummy3, FAXE_TYPE_CHAN);
        int idx = ha & 0xFFFF;
        void* first = malloc(16);
        void* second = malloc(16);
        assert(faxe_handle_get_aux(ha) == NULL);  /* nothing parked on a fresh slot */
        faxe_handle_set_aux(ha, first);
        assert(gFaxeSlots[idx].aux == first);
        assert(faxe_handle_get_aux(ha) == first);
        faxe_handle_set_aux(ha, second);          /* frees first */
        assert(gFaxeSlots[idx].aux == second);
        assert(faxe_handle_get_aux(ha) == second);
        faxe_handle_set_aux(ha, NULL);            /* frees second, leaves nothing */
        assert(gFaxeSlots[idx].aux == NULL);
        assert(faxe_handle_get_aux(ha) == NULL);
        faxe_handle_set_aux(ha, malloc(16));
        faxe_handle_free(ha);                     /* free releases the block */
        assert(gFaxeSlots[idx].aux == NULL);
        assert(faxe_live_handle_count() == 0);
    }

    /* a taken aux block leaves the slot and survives its free */
    {
        int ha = faxe_handle_alloc(&dummy3, FAXE_TYPE_CHANGROUP);
        int idx = ha & 0xFFFF;
        unsigned char* block = (unsigned char*)malloc(16);
        assert(faxe_handle_take_aux(ha) == NULL);  /* nothing to take on a fresh slot */
        memset(block, 0x5A, 16);
        faxe_handle_set_aux(ha, block);
        assert(faxe_handle_take_aux(ha) == block);
        assert(gFaxeSlots[idx].aux == NULL);
        assert(faxe_handle_get_aux(ha) == NULL);
        faxe_handle_free(ha);
        /* the caller owns the block, which the free left alone */
        assert(block[0] == 0x5A && block[15] == 0x5A);
        free(block);
        assert(faxe_live_handle_count() == 0);
    }

    /* the owned mark lives with the slot: clear on alloc, gone on free */
    {
        int ho = faxe_handle_alloc(&dummy3, FAXE_TYPE_SOUND);
        int again;
        assert(!faxe_handle_is_owned(ho));
        faxe_handle_set_owned(ho, 1);
        assert(faxe_handle_is_owned(ho));
        assert(!faxe_handle_is_owned(0) && !faxe_handle_is_owned(-1));
        assert(!faxe_handle_is_owned(ho + 0x10000)); /* another generation */
        faxe_handle_free(ho);
        assert(!faxe_handle_is_owned(ho)); /* a stale handle is never owned */
        again = faxe_handle_alloc(&dummy3, FAXE_TYPE_SOUND);
        assert((again & 0xFFFF) == (ho & 0xFFFF) && !faxe_handle_is_owned(again));
        faxe_handle_set_owned(again, 1);
        faxe_handle_set_owned(again, 0);
        assert(!faxe_handle_is_owned(again));
        faxe_handle_free(again);
        assert(faxe_live_handle_count() == 0);
    }

    /* children linked to an owned parent go with it, other slots stay */
    {
        int parent = faxe_handle_alloc(&dummy1, FAXE_TYPE_SOUND);
        int childA = faxe_handle_alloc(&dummy2, FAXE_TYPE_SOUND);
        int childB = faxe_handle_alloc(&dummy3, FAXE_TYPE_SOUND);
        int other = faxe_handle_alloc(&dummy1, FAXE_TYPE_DSP);
        int idx = childA & 0xFFFF;
        assert(gFaxeSlots[idx].parent == 0); /* a fresh slot has no parent */
        faxe_handle_set_parent(childA, parent);
        faxe_handle_set_parent(childB, parent);
        int grandchild = faxe_handle_alloc(&dummy2, FAXE_TYPE_SOUND);
        faxe_handle_set_parent(grandchild, childA);
        faxe_handles_free_children(0, NULL); /* no parent frees nothing */
        assert(faxe_live_handle_count() == 5);
        gHookCalls = 0;
        gHookPtr = NULL;
        gHookExpectType = FAXE_TYPE_SOUND;
        faxe_handles_free_children(parent, sweep_note_free); /* the walk reaches the grandchild */
        assert(faxe_handle_resolve(childA, FAXE_TYPE_SOUND) == NULL);
        assert(faxe_handle_resolve(childB, FAXE_TYPE_SOUND) == NULL);
        assert(faxe_handle_resolve(grandchild, FAXE_TYPE_SOUND) == NULL);
        /* the hook ran three times, each on a slot that still resolved
         * (the hook asserts that itself) */
        assert(gHookCalls == 3 && gHookPtr != NULL);
        /* a slot that names itself as parent is skipped rather than looped */
        {
            int loop = faxe_handle_alloc(&dummy2, FAXE_TYPE_SOUND);
            faxe_handle_set_parent(loop, loop);
            faxe_handles_free_children(loop, NULL);
            assert(faxe_handle_resolve(loop, FAXE_TYPE_SOUND) == &dummy2);
            faxe_handle_free(loop);
        }
        assert(faxe_handle_resolve(parent, FAXE_TYPE_SOUND) == &dummy1);
        assert(faxe_handle_resolve(other, FAXE_TYPE_DSP) == &dummy1);
        assert(gFaxeSlots[idx].parent == 0); /* the link goes with the slot */
        faxe_handle_free(other);
        faxe_handle_free(parent); /* last, so the free list head is where it was */
        assert(faxe_live_handle_count() == 0);
    }

    /* the lock record is a second owned block with the same lifetime */
    {
        int hl = faxe_handle_alloc(&dummy3, FAXE_TYPE_SOUND);
        int idx = hl & 0xFFFF;
        void* rec = malloc(32);
        assert(faxe_handle_get_lock(hl) == NULL);
        faxe_handle_set_lock(hl, rec);
        assert(faxe_handle_get_lock(hl) == rec);
        assert(gFaxeSlots[idx].aux == NULL);      /* aux is untouched */
        faxe_handle_set_lock(hl, NULL);           /* frees rec */
        assert(faxe_handle_get_lock(hl) == NULL);
        faxe_handle_set_lock(hl, malloc(32));
        faxe_handle_free(hl);                     /* free releases the record */
        assert(gFaxeSlots[idx].lock == NULL);
        assert(faxe_live_handle_count() == 0);
    }

    /* the memory image a stream reads lives exactly as long as its slot.
     * ASan reports a leak or a double free if either end is wrong. */
    {
        int hi = faxe_handle_alloc(&dummy3, FAXE_TYPE_SOUND);
        int idx = hi & 0xFFFF;
        assert(gFaxeSlots[idx].image == NULL);    /* nothing parked on a fresh slot */
        faxe_handle_set_image(hi, malloc(64));
        assert(gFaxeSlots[idx].image != NULL);
        assert(gFaxeSlots[idx].aux == NULL && gFaxeSlots[idx].lock == NULL);
        faxe_handle_set_image(hi, malloc(64));    /* frees the first copy */
        faxe_handle_free(hi);                     /* free releases the copy */
        assert(gFaxeSlots[idx].image == NULL);
        hi = faxe_handle_alloc(&dummy3, FAXE_TYPE_SOUND);
        assert((hi & 0xFFFF) == idx);
        assert(gFaxeSlots[idx].image == NULL);    /* a recycled slot starts clean */
        faxe_handle_free(hi);
        assert(faxe_live_handle_count() == 0);
    }

    /* slot reuse bumps generation */
    int h2 = faxe_handle_alloc(&dummy2, FAXE_TYPE_EVI);
    assert((h2 & 0xFFFF) == (h1 & 0xFFFF));  /* same slot recycled */
    assert(h2 != h1);                          /* different generation */
    assert(faxe_handle_resolve(h1, FAXE_TYPE_EVI) == NULL);
    assert(faxe_handle_resolve(h2, FAXE_TYPE_EVI) == &dummy2);
    /* The liveness check reads the generation, so a stale handle on a
     * recycled slot is dead while the slot's current handle is live */
    assert(!faxe_handle_is_live(h1) && faxe_handle_is_live(h2));
    assert(!faxe_handle_is_live(0) && !faxe_handle_is_live(-1));

    /* growth beyond the initial 64 slots */
    int handles[500];
    for (int i = 0; i < 500; i++) {
        handles[i] = faxe_handle_alloc(&dummy3, FAXE_TYPE_BANK);
        assert(handles[i] > 0);
    }
    assert(faxe_live_handle_count() == 501);
    for (int i = 0; i < 500; i++) {
        assert(faxe_handle_resolve(handles[i], FAXE_TYPE_BANK) == &dummy3);
        faxe_handle_free(handles[i]);
    }
    assert(faxe_live_handle_count() == 1);

    /* find_or_alloc: same pointer+type returns the same handle. A different
     * type or pointer allocates fresh */
    int f1 = faxe_handle_find_or_alloc(&dummy3, FAXE_TYPE_BUS);
    assert(f1 > 0);
    assert(faxe_handle_find_or_alloc(&dummy3, FAXE_TYPE_BUS) == f1);
    int f2 = faxe_handle_find_or_alloc(&dummy3, FAXE_TYPE_VCA);
    assert(f2 != f1);
    int f3 = faxe_handle_find_or_alloc(&dummy1, FAXE_TYPE_BUS);
    assert(f3 != f1);
    assert(faxe_handle_find_or_alloc(NULL, FAXE_TYPE_BUS) == 0);
    faxe_handle_free(f1);
    faxe_handle_free(f2);
    faxe_handle_free(f3);

    /* generation exhaustion: a slot recycled to its last generation retires,
     * so a stale handle from any earlier generation never resolves again */
    int h = h2;
    int firstIdx = h2 & 0xFFFF;
    int stale = h2;
    for (int i = 0; i < 40000; i++) {
        faxe_handle_free(h);
        h = faxe_handle_alloc(&dummy2, FAXE_TYPE_EVI);
        assert(h > 0);
        int gen = (h >> 16) & 0x7FFF;
        assert(gen >= 1 && gen <= 0x7FFF);
    }
    assert(faxe_handle_resolve(h, FAXE_TYPE_EVI) == &dummy2);
    assert((h & 0xFFFF) != firstIdx);
    assert(stale != 0 && faxe_handle_resolve(stale, FAXE_TYPE_EVI) == NULL);
    assert(!faxe_handle_is_live(stale) && faxe_handle_is_live(h));

    /* sweep of dead lookup slots: the BUS/VCA/EVD/BANK slots the
     * validator rejects are freed, other types are untouched even when
     * "dead" */
    {
        static int busObj, vcaObj, evdObj, eviObj, bankObj;
        int hb = faxe_handle_find_or_alloc(&busObj, FAXE_TYPE_BUS);
        int hv = faxe_handle_find_or_alloc(&vcaObj, FAXE_TYPE_VCA);
        int he = faxe_handle_find_or_alloc(&evdObj, FAXE_TYPE_EVD);
        int hi = faxe_handle_alloc(&eviObj, FAXE_TYPE_EVI);
        int hk = faxe_handle_alloc(&bankObj, FAXE_TYPE_BANK);
        int liveBefore = gFaxeLiveCount;

        /* everything valid: sweep frees nothing */
        faxe_handles_sweep_lookups(sweep_all_valid);
        assert(gFaxeLiveCount == liveBefore);
        assert(faxe_handle_resolve(hb, FAXE_TYPE_BUS) == &busObj);

        /* everything dead: sweep frees the three lookup slots and the
         * bank slot. A stale bank handle cannot resurrect onto a
         * reloaded bank at the same address. */
        faxe_handles_sweep_lookups(sweep_all_dead);
        assert(gFaxeLiveCount == liveBefore - 4);
        assert(faxe_handle_resolve(hb, FAXE_TYPE_BUS) == NULL);
        assert(faxe_handle_resolve(hv, FAXE_TYPE_VCA) == NULL);
        assert(faxe_handle_resolve(he, FAXE_TYPE_EVD) == NULL);
        assert(faxe_handle_resolve(hi, FAXE_TYPE_EVI) == &eviObj);
        assert(faxe_handle_resolve(hk, FAXE_TYPE_BANK) == NULL);
        assert(faxe_handle_find_or_alloc(&bankObj, FAXE_TYPE_BANK) != hk);

        /* the freed slot recycles under a new generation. A fresh lookup
         * for a reused address gets a NEW handle, and the stale one stays
         * dead */
        int hb2 = faxe_handle_find_or_alloc(&busObj, FAXE_TYPE_BUS);
        assert(hb2 > 0 && hb2 != hb);
        assert(faxe_handle_resolve(hb, FAXE_TYPE_BUS) == NULL);
        assert(faxe_handle_resolve(hb2, FAXE_TYPE_BUS) == &busObj);

        faxe_handle_free(hb2);
        faxe_handle_free(hi);
        faxe_handle_free(hk);
    }

    /* free_type drops every slot of one type and only that type */
    {
        int obj1 = 1, obj2 = 2, obj3 = 3;
        int hc1 = faxe_handle_alloc(&obj1, FAXE_TYPE_DSPCONN);
        int hc2 = faxe_handle_alloc(&obj2, FAXE_TYPE_DSPCONN);
        int hd = faxe_handle_alloc(&obj3, FAXE_TYPE_DSP);
        assert(hc1 > 0 && hc2 > 0 && hd > 0);

        faxe_handles_free_type(FAXE_TYPE_DSPCONN);
        assert(faxe_handle_resolve(hc1, FAXE_TYPE_DSPCONN) == NULL);
        assert(faxe_handle_resolve(hc2, FAXE_TYPE_DSPCONN) == NULL);
        assert(faxe_handle_resolve(hd, FAXE_TYPE_DSP) == &obj3);

        /* a recycled slot must not resolve through the freed handles */
        int hc3 = faxe_handle_alloc(&obj1, FAXE_TYPE_DSPCONN);
        assert(hc3 > 0);
        assert(faxe_handle_resolve(hc1, FAXE_TYPE_DSPCONN) == NULL);
        faxe_handle_free(hc3);
        faxe_handle_free(hd);
    }

    test_fuzz_against_model();

    /* a typed sweep frees the rejected slots of that type only */
    {
        int objA = 1, objB = 2, objC = 3;
        int c1 = faxe_handle_alloc(&objA, FAXE_TYPE_CHAN);
        int c2 = faxe_handle_alloc(&objB, FAXE_TYPE_CHAN);
        int other = faxe_handle_alloc(&objC, FAXE_TYPE_SOUND);
        gRejected = &objA;
        gHookExpectType = FAXE_TYPE_CHAN;
        faxe_handles_sweep_type(FAXE_TYPE_CHAN, sweep_reject_one, sweep_note_free);
        assert(faxe_handle_resolve(c1, FAXE_TYPE_CHAN) == NULL);
        assert(faxe_handle_resolve(c2, FAXE_TYPE_CHAN) == &objB);
        /* the hook saw the rejected slot while it still resolved */
        assert(gHookPtr == &objA && gHookHandle == c1);
        gRejected = &objC;
        gHookPtr = NULL;
        gHookHandle = 0;
        faxe_handles_sweep_type(FAXE_TYPE_CHAN, sweep_reject_one, sweep_note_free);
        /* a sweep of another type touches nothing */
        assert(faxe_handle_resolve(other, FAXE_TYPE_SOUND) == &objC);
        assert(faxe_handle_resolve(c2, FAXE_TYPE_CHAN) == &objB);
        assert(gHookPtr == NULL && gHookHandle == 0);
        /* a NULL hook frees the slot without a call */
        gRejected = &objB;
        faxe_handles_sweep_type(FAXE_TYPE_CHAN, sweep_reject_one, NULL);
        assert(faxe_handle_resolve(c2, FAXE_TYPE_CHAN) == NULL);
        assert(faxe_handle_resolve(other, FAXE_TYPE_SOUND) == &objC);
        assert(gHookPtr == NULL && gHookHandle == 0);
        faxe_handle_free(other);
    }

    /* A borrowed handle dies with the handle it was reached from, and so
     * does everything reached from it in turn */
    {
        static int inst, group, child, grand, dsp, other;
        int liveAtStart = faxe_live_handle_count();
        int hInst = faxe_handle_alloc(&inst, FAXE_TYPE_EVI);
        int hGroup = faxe_handle_alloc(&group, FAXE_TYPE_CHANGROUP);
        int hChild = faxe_handle_alloc(&child, FAXE_TYPE_CHANGROUP);
        int hGrand = faxe_handle_alloc(&grand, FAXE_TYPE_CHANGROUP);
        int hDsp = faxe_handle_alloc(&dsp, FAXE_TYPE_DSP);
        int hOther = faxe_handle_alloc(&other, FAXE_TYPE_CHANGROUP);
        void* childAux = malloc(48);
        void* groupAux = malloc(48);
        assert(gFaxeSlots[hInst & 0xFFFF].kids == 0);   /* nothing hangs off a fresh slot */
        faxe_handle_set_owner(hGroup, hInst);
        faxe_handle_set_owner(hChild, hGroup);
        faxe_handle_set_owner(hGrand, hChild);
        faxe_handle_set_owner(hDsp, hGroup);
        assert(gFaxeSlots[hInst & 0xFFFF].kids == 1 && gFaxeSlots[hGroup & 0xFFFF].kids == 1);
        assert(gFaxeSlots[hOther & 0xFFFF].kids == 0 && gFaxeSlots[hGrand & 0xFFFF].kids == 0);
        assert(faxe_handle_get_borrowed(hGroup) == FAXE_BORROWED_LINKED);
        assert(faxe_handle_get_borrowed(hOther) == FAXE_BORROWED_NONE);
        assert(faxe_handle_get_parent(hGrand) == hChild);
        assert(faxe_handle_root(hGrand) == hInst && faxe_handle_root(hInst) == hInst);
        assert(faxe_handle_get_type(faxe_handle_root(hDsp)) == FAXE_TYPE_EVI);
        faxe_handle_set_aux(hChild, childAux);
        faxe_handle_set_aux(hGroup, groupAux);

        faxe_handle_free(hInst);
        assert(!faxe_handle_is_live(hGroup) && !faxe_handle_is_live(hChild));
        assert(!faxe_handle_is_live(hGrand) && !faxe_handle_is_live(hDsp));
        assert(faxe_handle_resolve(hOther, FAXE_TYPE_CHANGROUP) == &other);  /* an unlinked slot stays */
        assert(faxe_handle_get_type(hGroup) == FAXE_TYPE_NONE);
        /* the cascade leaves the rolloff blocks to FMOD, which can still
         * read them, and forgets them on the slot. ASan reports a double
         * free here if the table freed them. */
        assert(gFaxeSlots[hChild & 0xFFFF].aux == NULL && gFaxeSlots[hGroup & 0xFFFF].aux == NULL);
        free(childAux);
        free(groupAux);
        /* a recycled slot starts with no kids and no owner */
        {
            int again = faxe_handle_alloc(&inst, FAXE_TYPE_EVI);
            assert(gFaxeSlots[again & 0xFFFF].kids == 0 && gFaxeSlots[again & 0xFFFF].parent == 0);
            assert(faxe_handle_get_borrowed(again) == FAXE_BORROWED_NONE);
            faxe_handle_free(again);
        }

        /* the direct free of a borrowed handle still frees its own aux,
         * the object it names is gone */
        {
            int owner = faxe_handle_alloc(&inst, FAXE_TYPE_EVI);
            int borrowed = faxe_handle_alloc(&group, FAXE_TYPE_CHANGROUP);
            faxe_handle_set_owner(borrowed, owner);
            faxe_handle_set_aux(borrowed, malloc(16));
            faxe_handle_free(borrowed);
            assert(faxe_handle_is_live(owner));        /* a kid never takes its owner along */
            faxe_handle_free(owner);
        }

        /* an owner that does not resolve makes the handle volatile, and
         * the volatile sweep frees exactly those and what hangs off them */
        {
            int dead = faxe_handle_alloc(&inst, FAXE_TYPE_EVI);
            int linkedOwner = faxe_handle_alloc(&dsp, FAXE_TYPE_DSP);
            int vol;
            int volKid;
            int linked;
            faxe_handle_free(dead);
            vol = faxe_handle_alloc(&group, FAXE_TYPE_CHANGROUP);
            faxe_handle_set_owner(vol, dead);
            assert(faxe_handle_get_borrowed(vol) == FAXE_BORROWED_VOLATILE && faxe_handle_get_parent(vol) == 0);
            volKid = faxe_handle_alloc(&child, FAXE_TYPE_CHANGROUP);
            faxe_handle_set_owner(volKid, vol);
            assert(faxe_handle_get_borrowed(volKid) == FAXE_BORROWED_LINKED);
            linked = faxe_handle_alloc(&grand, FAXE_TYPE_SOUND);
            faxe_handle_set_owner(linked, linkedOwner);
            faxe_handle_set_aux(vol, malloc(8));       /* freed by hand below */
            {
                void* volAux = faxe_handle_get_aux(vol);
                faxe_handles_free_volatile();
                assert(!faxe_handle_is_live(vol) && !faxe_handle_is_live(volKid));
                assert(faxe_handle_is_live(linked) && faxe_handle_is_live(linkedOwner));
                free(volAux);                          /* the sweep kept it for FMOD */
            }
            /* set_volatile and clear_owner switch a live handle's kind */
            faxe_handle_set_volatile(linked);
            assert(faxe_handle_get_borrowed(linked) == FAXE_BORROWED_VOLATILE);
            faxe_handle_clear_owner(linked);
            assert(faxe_handle_get_borrowed(linked) == FAXE_BORROWED_NONE && faxe_handle_get_parent(linked) == 0);
            faxe_handles_free_volatile();
            assert(faxe_handle_is_live(linked));
            faxe_handle_free(linked);
            faxe_handle_free(linkedOwner);
            /* a handle never owns itself */
            {
                int self = faxe_handle_alloc(&group, FAXE_TYPE_CHANGROUP);
                faxe_handle_set_owner(self, self);
                assert(faxe_handle_get_parent(self) == 0);
                faxe_handle_free(self);
            }
        }

        /* free_ptr drops every slot of one type at an address, so a new
         * object there never meets a stale handle */
        {
            int a = faxe_handle_alloc(&group, FAXE_TYPE_CHANGROUP);
            int b = faxe_handle_alloc(&group, FAXE_TYPE_CHANGROUP);
            int c = faxe_handle_alloc(&group, FAXE_TYPE_DSP);
            int k = faxe_handle_alloc(&child, FAXE_TYPE_CHANGROUP);
            faxe_handle_set_owner(k, a);
            faxe_handle_set_aux(a, malloc(8));        /* the dead object's block goes */
            faxe_handles_free_ptr(&group, FAXE_TYPE_CHANGROUP);
            faxe_handles_free_ptr(NULL, FAXE_TYPE_CHANGROUP);
            assert(!faxe_handle_is_live(a) && !faxe_handle_is_live(b) && !faxe_handle_is_live(k));
            assert(faxe_handle_resolve(c, FAXE_TYPE_DSP) == &group);
            faxe_handle_free(c);
        }
        faxe_handle_free(hOther);
        assert(faxe_live_handle_count() == liveAtStart);
    }

    /* A group handle walked in one instance's tree is foreign to a walk
     * from another instance or a bus. The owners' own anchored handles
     * and walks that start elsewhere never count. */
    {
        static int instA, instB, bus, groupA, groupB, busGroup, nested, game, master;
        int liveAtStart = faxe_live_handle_count();
        int hA = faxe_handle_alloc(&instA, FAXE_TYPE_EVI);
        int hB = faxe_handle_alloc(&instB, FAXE_TYPE_EVI);
        int hBus = faxe_handle_alloc(&bus, FAXE_TYPE_BUS);
        int hGroupA = faxe_handle_alloc(&groupA, FAXE_TYPE_CHANGROUP);
        int hGroupB = faxe_handle_alloc(&groupB, FAXE_TYPE_CHANGROUP);
        int hBusGroup = faxe_handle_alloc(&busGroup, FAXE_TYPE_CHANGROUP);
        int hNested = faxe_handle_alloc(&nested, FAXE_TYPE_CHANGROUP);
        int hGame = faxe_handle_alloc(&game, FAXE_TYPE_CHANGROUP);
        int hMaster = faxe_handle_alloc(&master, FAXE_TYPE_CHANGROUP);
        int i;
        int borrowedSlots[] = {hGroupA, hGroupB, hBusGroup, hNested};
        for (i = 0; i < 4; i++) faxe_handle_set_owned(borrowedSlots[i], 1);
        faxe_handle_set_owned(hMaster, 1);
        faxe_handle_set_owner(hGroupA, hA);
        faxe_handle_set_owner(hGroupB, hB);
        faxe_handle_set_owner(hBusGroup, hBus);
        faxe_handle_set_owner(hNested, hGroupA);
        faxe_handle_set_volatile(hNested);
        assert(faxe_handle_is_group_owner_type(FAXE_TYPE_EVI) && faxe_handle_is_group_owner_type(FAXE_TYPE_BUS));
        assert(!faxe_handle_is_group_owner_type(FAXE_TYPE_CHANGROUP) && !faxe_handle_is_group_owner_type(FAXE_TYPE_NONE));
        /* the nested walk result is foreign to instance B and to the bus */
        assert(faxe_handle_walked_elsewhere(hNested, hB));
        assert(faxe_handle_walked_elsewhere(hNested, hBus));
        /* and belongs to a walk from A's own tree */
        assert(!faxe_handle_walked_elsewhere(hNested, hA));
        /* a walk that starts at no instance or bus cannot judge it */
        assert(!faxe_handle_walked_elsewhere(hNested, hGame));
        assert(!faxe_handle_walked_elsewhere(hNested, 0));
        /* anchored own groups stay, whoever walks into them */
        assert(!faxe_handle_walked_elsewhere(hGroupA, hB));
        assert(!faxe_handle_walked_elsewhere(hBusGroup, hA));
        /* a game group and the fixed master are not borrowed */
        assert(!faxe_handle_walked_elsewhere(hGame, hB));
        assert(!faxe_handle_walked_elsewhere(hMaster, hB));
        /* a plain parent link (a subsound's) makes no borrowed group */
        {
            static int linkedOnly;
            int hLinked = faxe_handle_alloc(&linkedOnly, FAXE_TYPE_CHANGROUP);
            faxe_handle_set_parent(hLinked, hGroupA);
            assert(!faxe_handle_walked_elsewhere(hLinked, hB));
            faxe_handle_set_owned(hLinked, 1);
            assert(!faxe_handle_walked_elsewhere(hLinked, hB));
            faxe_handle_free(hLinked);
        }
        /* a dead handle is never foreign */
        assert(!faxe_handle_walked_elsewhere(0, hB));

        /* on_chain sees a handle itself and every handle above it */
        assert(faxe_handle_on_chain(hNested, hNested));
        assert(faxe_handle_on_chain(hGroupA, hNested) && faxe_handle_on_chain(hA, hNested));
        assert(!faxe_handle_on_chain(hNested, hGroupA) && !faxe_handle_on_chain(hB, hNested));
        assert(!faxe_handle_on_chain(hA, 0));

        /* adopt moves a volatile handle under a live owner, linked */
        assert(faxe_handle_adopt(hNested, hBusGroup) == 1);
        assert(faxe_handle_get_parent(hNested) == hBusGroup);
        assert(faxe_handle_get_borrowed(hNested) == FAXE_BORROWED_LINKED);
        assert(gFaxeSlots[hBusGroup & 0xFFFF].kids == 1);
        faxe_handles_free_volatile();
        assert(faxe_handle_is_live(hNested));
        /* a linked handle keeps its first owner */
        assert(faxe_handle_adopt(hNested, hGroupB) == 0);
        assert(faxe_handle_get_parent(hNested) == hBusGroup);
        /* refused: no owner, a dead owner, itself, and an owner below it */
        faxe_handle_set_volatile(hNested);
        assert(faxe_handle_adopt(hNested, 0) == 0);
        assert(faxe_handle_adopt(hNested, hNested) == 0);
        {
            static int below;
            int hBelow = faxe_handle_alloc(&below, FAXE_TYPE_DSP);
            int deadOwner = faxe_handle_alloc(&below, FAXE_TYPE_DSP);
            faxe_handle_free(deadOwner);
            assert(faxe_handle_adopt(hNested, deadOwner) == 0);
            faxe_handle_set_owner(hBelow, hNested);
            assert(faxe_handle_adopt(hNested, hBelow) == 0);
            assert(faxe_handle_get_borrowed(hNested) == FAXE_BORROWED_VOLATILE);
            /* a handle the game owns is never adopted */
            assert(faxe_handle_adopt(hGame, hBusGroup) == 0 && faxe_handle_get_parent(hGame) == 0);
            /* the adopted handle dies with its new owner */
            assert(faxe_handle_adopt(hNested, hGroupB) == 1);
            faxe_handle_free(hB);
            assert(!faxe_handle_is_live(hGroupB) && !faxe_handle_is_live(hNested) && !faxe_handle_is_live(hBelow));
        }
        faxe_handle_free(hA);
        faxe_handle_free(hBus);
        assert(!faxe_handle_is_live(hGroupA) && !faxe_handle_is_live(hBusGroup));
        faxe_handle_free(hGame);
        faxe_handle_free(hMaster);
        assert(faxe_live_handle_count() == liveAtStart);
    }

    /* gFaxeVolatileCount follows every change of a slot's kind, so the
     * per-update drop can return at once with no volatile slot alive */
    {
        static int objs[64];
        int hs[64];
        int n = 0;
        int op;
        unsigned int seed = 0x9E3779B9u;
        int liveAtStart = faxe_live_handle_count();
        assert(gFaxeVolatileCount == 0 && count_volatile_slots() == 0);
        /* each helper by hand */
        {
            int owner = faxe_handle_alloc(&objs[0], FAXE_TYPE_EVI);
            int dead = faxe_handle_alloc(&objs[1], FAXE_TYPE_EVI);
            int a = faxe_handle_alloc(&objs[2], FAXE_TYPE_CHANGROUP);
            int b = faxe_handle_alloc(&objs[3], FAXE_TYPE_CHANGROUP);
            int kid = faxe_handle_alloc(&objs[4], FAXE_TYPE_DSP);
            faxe_handle_free(dead);
            faxe_handle_set_owner(a, dead);            /* dead owner: volatile */
            assert(gFaxeVolatileCount == 1);
            faxe_handle_set_owner(a, dead);            /* already volatile */
            faxe_handle_set_volatile(a);
            assert(gFaxeVolatileCount == 1);
            faxe_handle_set_owner(b, owner);           /* linked */
            assert(gFaxeVolatileCount == 1);
            faxe_handle_set_volatile(b);
            assert(gFaxeVolatileCount == 2);
            faxe_handle_set_owner(b, owner);           /* a live owner keeps the kind */
            assert(gFaxeVolatileCount == 2);
            faxe_handle_clear_owner(b);
            assert(gFaxeVolatileCount == 1);
            faxe_handle_set_owned(a, 1);
            assert(faxe_handle_adopt(a, owner) == 1);  /* volatile to linked */
            assert(gFaxeVolatileCount == 0);
            faxe_handle_set_volatile(a);
            faxe_handle_set_owner(kid, a);
            faxe_handle_set_volatile(kid);
            assert(gFaxeVolatileCount == 2);
            faxe_handle_free(owner);                   /* the cascade counts too */
            assert(gFaxeVolatileCount == 0 && !faxe_handle_is_live(kid));
            faxe_handle_free(b);
        }
        /* random kinds against the slow count */
        for (op = 0; op < 20000; op++) {
            unsigned int roll;
            int pick;
            seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5;
            roll = seed % 8;
            pick = n > 0 ? (int)((seed >> 8) % (unsigned int)n) : 0;
            if (roll == 0 && n < 64) {
                hs[n] = faxe_handle_alloc(&objs[n], FAXE_TYPE_CHANGROUP);
                faxe_handle_set_owned(hs[n], 1);
                n++;
            } else if (n == 0) {
                continue;
            } else if (roll == 1) {
                faxe_handle_set_owner(hs[pick], hs[(pick + 1) % n]);
            } else if (roll == 2) {
                faxe_handle_set_volatile(hs[pick]);
            } else if (roll == 3) {
                faxe_handle_clear_owner(hs[pick]);
            } else if (roll == 4) {
                faxe_handle_adopt(hs[pick], hs[(pick + 3) % n]);
            } else if (roll == 5) {
                faxe_handle_free(hs[pick]);
            } else if (roll == 6) {
                faxe_handles_free_volatile();
                assert(gFaxeVolatileCount == 0);
            } else {
                faxe_handle_set_owner(hs[pick], 0);
            }
            /* drop the dead from the pick list, an owner cascade included */
            {
                int i, w = 0;
                for (i = 0; i < n; i++) if (faxe_handle_is_live(hs[i])) hs[w++] = hs[i];
                n = w;
            }
            assert(gFaxeVolatileCount == count_volatile_slots());
        }
        while (n > 0) faxe_handle_free(hs[--n]);
        assert(gFaxeVolatileCount == 0);
        /* with the count at 0 the drop scans nothing. A slot marked behind
         * the helpers' backs shows it. */
        {
            int hidden = faxe_handle_alloc(&objs[0], FAXE_TYPE_CHANGROUP);
            gFaxeSlots[hidden & 0xFFFF].borrowed = FAXE_BORROWED_VOLATILE;
            faxe_handles_free_volatile();
            assert(faxe_handle_is_live(hidden));
            gFaxeSlots[hidden & 0xFFFF].borrowed = FAXE_BORROWED_NONE;
            faxe_handle_free(hidden);
        }
        assert(faxe_live_handle_count() == liveAtStart);
    }

    printf("faxe_handles: all assertions passed\n");
    return 0;
}
