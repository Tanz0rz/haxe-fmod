/*
 * Unit tests for native/shared/faxe_parking.h, the list of channel groups
 * whose FMOD release waits for the geometry thread. The window rule, the
 * list bound, the due check, and the walk index mapping are the logic
 * worth pinning.
 *
 * CI compiles and runs the file in both C99 and C++ modes. The build
 * lines:
 *   gcc -std=c99 -Wall -Wextra -Werror -o test_c   tests/native/test_faxe_parking.c && ./test_c
 *   g++ -x c++   -Wall -Wextra -Werror -o test_cpp tests/native/test_faxe_parking.c && ./test_cpp
 */
#include <stdio.h>
#include <assert.h>
#include <limits.h>
#include "../../native/shared/faxe_parking.h"

static int gObjects[FAXE_PARK_MAX + 2];
static int gAux;

/* A stand-in parent group: its children, and an index childAt refuses */
typedef struct {
    void* children[4];
    int refuseAt;
} FakeParent;

static int fake_child_at(void* parent, int i, void** child) {
    FakeParent* p = (FakeParent*)parent;
    if (i < 0 || i >= 4 || i == p->refuseAt) return 0;
    *child = p->children[i];
    return 1;
}

int main(void) {
    FaxeParked out[FAXE_PARK_MAX];
    int i;
    int n;

    /* No geometry was ever made, so nothing parks */
    assert(!faxe_park_needed(0.0));
    assert(!faxe_park_needed(1000000.0));

    /* A live geometry parks every release */
    faxe_park_geometry_made();
    faxe_park_geometry_made();
    assert(faxe_park_needed(5.0));
    /* One of two going leaves the other live */
    faxe_park_geometry_gone(10.0);
    assert(faxe_park_needed(1000.0));
    /* The last one going opens the window, which ends after the delay */
    faxe_park_geometry_gone(100.0);
    assert(faxe_park_needed(100.0));
    assert(faxe_park_needed(100.0 + FAXE_PARK_DELAY_MS - 0.5));
    assert(!faxe_park_needed(100.0 + FAXE_PARK_DELAY_MS));
    assert(!faxe_park_needed(5000.0));
    /* A release that finds no geometry counted starts the window again */
    faxe_park_geometry_gone(200.0);
    assert(faxe_park_needed(210.0));
    assert(!faxe_park_needed(200.0 + FAXE_PARK_DELAY_MS));
    /* A new geometry parks again */
    faxe_park_geometry_made();
    assert(faxe_park_needed(9000.0));
    faxe_park_geometry_gone(9000.0);

    /* Empty list */
    assert(faxe_park_count() == 0);
    assert(!faxe_park_contains(&gObjects[0]));
    assert(!faxe_park_contains(NULL));
    assert(faxe_park_wait_ms(0.0) == 0.0);
    assert(faxe_park_take_due(1000.0, out, FAXE_PARK_MAX) == 0);

    /* A NULL group never parks, and a parked one is not added twice */
    assert(faxe_park_add(NULL, NULL, 0.0) == 0);
    assert(faxe_park_add(&gObjects[0], &gAux, 1000.0) == 1);
    assert(faxe_park_add(&gObjects[0], NULL, 1010.0) == 1);
    assert(faxe_park_count() == 1);
    assert(faxe_park_contains(&gObjects[0]));
    assert(!faxe_park_contains(&gObjects[1]));

    /* Not due before the delay, due at it, with its aux and time */
    assert(faxe_park_wait_ms(1000.0) == FAXE_PARK_DELAY_MS);
    assert(faxe_park_wait_ms(1040.0) == FAXE_PARK_DELAY_MS - 40.0);
    assert(faxe_park_take_due(1000.0 + FAXE_PARK_DELAY_MS - 1.0, out, FAXE_PARK_MAX) == 0);
    assert(faxe_park_count() == 1);
    assert(faxe_park_wait_ms(5000.0) == 0.0);
    n = faxe_park_take_due(1000.0 + FAXE_PARK_DELAY_MS, out, FAXE_PARK_MAX);
    assert(n == 1);
    assert(out[0].ptr == &gObjects[0] && out[0].aux == &gAux && out[0].at == 1000.0);
    assert(faxe_park_count() == 0 && !faxe_park_contains(&gObjects[0]));

    /* Only the entries that are due leave, the rest keep their order */
    assert(faxe_park_add(&gObjects[0], NULL, 0.0));
    assert(faxe_park_add(&gObjects[1], NULL, 50.0));
    assert(faxe_park_add(&gObjects[2], NULL, 10.0));
    assert(faxe_park_wait_ms(20.0) == FAXE_PARK_DELAY_MS - 20.0);
    n = faxe_park_take_due(FAXE_PARK_DELAY_MS + 10.0, out, FAXE_PARK_MAX);
    assert(n == 2);
    assert(out[0].ptr == &gObjects[0] && out[1].ptr == &gObjects[2]);
    assert(faxe_park_count() == 1 && faxe_park_contains(&gObjects[1]));
    n = faxe_park_take_due(1000.0, out, FAXE_PARK_MAX);
    assert(n == 1 && out[0].ptr == &gObjects[1]);

    /* The list holds FAXE_PARK_MAX groups and refuses the next one */
    for (i = 0; i < FAXE_PARK_MAX; i++) assert(faxe_park_add(&gObjects[i], NULL, (double)i));
    assert(faxe_park_count() == FAXE_PARK_MAX);
    assert(faxe_park_add(&gObjects[FAXE_PARK_MAX], NULL, 100.0) == 0);
    assert(!faxe_park_contains(&gObjects[FAXE_PARK_MAX]));
    /* A take with a small out array leaves the rest parked */
    n = faxe_park_take_due(10000.0, out, 3);
    assert(n == 3 && faxe_park_count() == FAXE_PARK_MAX - 3);
    assert(out[0].ptr == &gObjects[0] && out[2].ptr == &gObjects[2]);
    assert(faxe_park_contains(&gObjects[3]) && !faxe_park_contains(&gObjects[2]));
    /* Room again for the refused one */
    assert(faxe_park_add(&gObjects[FAXE_PARK_MAX], NULL, 100.0) == 1);
    n = faxe_park_take_due(10000.0, out, FAXE_PARK_MAX);
    assert(n == FAXE_PARK_MAX - 2 && faxe_park_count() == 0);
    assert(out[n - 1].ptr == &gObjects[FAXE_PARK_MAX]);

    /* The walk helpers. With nothing parked, both pass through. */
    {
        FakeParent parent;
        parent.children[0] = &gObjects[0];
        parent.children[1] = &gObjects[1];
        parent.children[2] = &gObjects[2];
        parent.children[3] = &gObjects[3];
        parent.refuseAt = -1;
        assert(faxe_park_count() == 0);
        assert(faxe_park_shown_count(&parent, 4, fake_child_at) == 4);
        assert(faxe_park_shown_index(&parent, 4, 2, fake_child_at) == 2);
        assert(faxe_park_shown_index(&parent, 4, INT_MAX, fake_child_at) == INT_MAX);
        /* A parked child is skipped, and the indexes after it shift */
        assert(faxe_park_add(&gObjects[1], NULL, 0.0));
        assert(faxe_park_shown_count(&parent, 4, fake_child_at) == 3);
        assert(faxe_park_shown_index(&parent, 4, 0, fake_child_at) == 0);
        assert(faxe_park_shown_index(&parent, 4, 1, fake_child_at) == 2);
        assert(faxe_park_shown_index(&parent, 4, 2, fake_child_at) == 3);
        /* Any index past the shown children maps to count, never past it */
        assert(faxe_park_shown_index(&parent, 4, 3, fake_child_at) == 4);
        assert(faxe_park_shown_index(&parent, 4, INT_MAX, fake_child_at) == 4);
        assert(faxe_park_shown_index(&parent, 4, INT_MAX - 1, fake_child_at) == 4);
        /* A negative index stays for FMOD to refuse */
        assert(faxe_park_shown_index(&parent, 4, -1, fake_child_at) == -1);
        assert(faxe_park_shown_index(&parent, 4, INT_MIN, fake_child_at) == INT_MIN);
        /* A child that cannot be read is not shown, and leaves the index */
        parent.refuseAt = 2;
        assert(faxe_park_shown_count(&parent, 4, fake_child_at) == 2);
        assert(faxe_park_shown_index(&parent, 4, 1, fake_child_at) == 1);
        assert(faxe_park_shown_index(&parent, 4, 0, fake_child_at) == 0);
        parent.refuseAt = -1;
        /* A NULL child is shown */
        parent.children[3] = NULL;
        assert(faxe_park_shown_count(&parent, 4, fake_child_at) == 3);
        assert(faxe_park_shown_index(&parent, 4, 2, fake_child_at) == 3);
        /* Every child parked shows none */
        parent.children[3] = &gObjects[3];
        assert(faxe_park_add(&gObjects[0], NULL, 0.0));
        assert(faxe_park_add(&gObjects[2], NULL, 0.0));
        assert(faxe_park_add(&gObjects[3], NULL, 0.0));
        assert(faxe_park_shown_count(&parent, 4, fake_child_at) == 0);
        assert(faxe_park_shown_index(&parent, 4, 0, fake_child_at) == 4);
        assert(faxe_park_shown_index(&parent, 4, INT_MAX, fake_child_at) == 4);
        assert(faxe_park_shown_count(&parent, 0, fake_child_at) == 0);
        assert(faxe_park_shown_index(&parent, 0, INT_MAX, fake_child_at) == 0);
        n = faxe_park_take_due(10000.0, out, FAXE_PARK_MAX);
        assert(n == 4 && faxe_park_count() == 0);
    }

    printf("test_faxe_parking: all tests passed\n");
    return 0;
}
