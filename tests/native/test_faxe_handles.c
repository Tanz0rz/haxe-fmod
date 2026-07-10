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
#include "../../native/shared/faxe_handles.h"

static int sweep_all_valid(void* ptr, unsigned char type) {
    (void)ptr; (void)type;
    return 1;
}

static int sweep_all_dead(void* ptr, unsigned char type) {
    (void)ptr; (void)type;
    return 0;
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

    /* free -> stale handle stops resolving */
    faxe_handle_free(h1);
    assert(faxe_handle_resolve(h1, FAXE_TYPE_EVI) == NULL);
    assert(faxe_live_handle_count() == 0);
    faxe_handle_free(h1); /* double free is a safe no-op */
    assert(faxe_live_handle_count() == 0);

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
     * rejects are freed; other types are untouched even when "dead" */
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

    printf("faxe_handles: all assertions passed\n");
    return 0;
}
