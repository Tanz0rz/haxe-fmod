/*
 * Unit tests for native/shared/faxe_handles.h (the generational handle table
 * shared by the C++ and HashLink shims. jaxe.js mirrors the same logic).
 *
 * Compiled and run in CI in both C99 and C++ modes:
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

static int sweep_all_dead(void* ptr, unsigned char type) {
    (void)ptr; (void)type;
    return 0;
}


/* Seeded pseudo-random fuzz with a shadow model. Arbitrary integers into
 * resolve and free must behave exactly like the model predicts: a random
 * int resolves to a live slot's pointer only when it IS that slot's
 * current handle with the right type, frees only that exact handle, and
 * never corrupts unrelated live entries. Deterministic (fixed seed), and
 * run under ASan/UBSan in CI so a wild read or overflow fails loudly. */
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

    /* slot reuse bumps generation */
    int h2 = faxe_handle_alloc(&dummy2, FAXE_TYPE_EVI);
    assert((h2 & 0xFFFF) == (h1 & 0xFFFF));  /* same slot recycled */
    assert(h2 != h1);                          /* different generation */
    assert(faxe_handle_resolve(h1, FAXE_TYPE_EVI) == NULL);
    assert(faxe_handle_resolve(h2, FAXE_TYPE_EVI) == &dummy2);

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

    /* generation wrap: recycle one slot many times, gen stays in 1..0x7FFF */
    int h = h2;
    for (int i = 0; i < 40000; i++) {
        faxe_handle_free(h);
        h = faxe_handle_alloc(&dummy2, FAXE_TYPE_EVI);
        assert(h > 0);
        int gen = (h >> 16) & 0x7FFF;
        assert(gen >= 1 && gen <= 0x7FFF);
    }
    assert(faxe_handle_resolve(h, FAXE_TYPE_EVI) == &dummy2);

    /* sweep of dead lookup slots: only BUS/VCA/EVD slots the validator
     * rejects are freed, other types are untouched even when "dead" */
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

        /* everything dead: sweep frees exactly the three lookup slots */
        faxe_handles_sweep_lookups(sweep_all_dead);
        assert(gFaxeLiveCount == liveBefore - 3);
        assert(faxe_handle_resolve(hb, FAXE_TYPE_BUS) == NULL);
        assert(faxe_handle_resolve(hv, FAXE_TYPE_VCA) == NULL);
        assert(faxe_handle_resolve(he, FAXE_TYPE_EVD) == NULL);
        assert(faxe_handle_resolve(hi, FAXE_TYPE_EVI) == &eviObj);
        assert(faxe_handle_resolve(hk, FAXE_TYPE_BANK) == &bankObj);

        /* the freed slot recycles under a new generation, so a fresh lookup
         * for a reused address gets a NEW handle and the stale one stays dead */
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

    printf("faxe_handles: all assertions passed\n");
    return 0;
}
