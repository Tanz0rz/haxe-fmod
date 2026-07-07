/*
 * Unit tests for native/shared/faxe_cbqueue.h (the thread-safe callback
 * event ring shared by the C++ and HashLink shims).
 *
 * Compiled and run in CI in both C99 and C++ modes:
 *   gcc -std=c99 -pthread -Wall -Wextra -Werror -o t_c   tests/native/test_faxe_cbqueue.c && ./t_c
 *   g++ -x c++   -pthread -Wall -Wextra -Werror -o t_cpp tests/native/test_faxe_cbqueue.c && ./t_cpp
 */
#include <stdio.h>
#include <assert.h>
#include "../../native/shared/faxe_cbqueue.h"

int main(void) {
    FaxeCbEvent ev;
    FaxeCbEvent out;

    /* pop before init is a safe no-op */
    assert(faxe_cbq_pop(&out) == 0);
    assert(faxe_cbq_take_overflow() == 0);

    faxe_cbq_init();
    faxe_cbq_init(); /* double init is a safe no-op */

    /* empty pop */
    assert(faxe_cbq_pop(&out) == 0);

    /* FIFO order with payloads */
    memset(&ev, 0, sizeof(ev));
    for (int i = 0; i < 5; i++) {
        ev.handle = 100 + i;
        ev.type = 1u << i;
        ev.i1 = i;
        ev.i2 = i * 2;
        ev.i3 = i * 3;
        ev.f1 = (float)i * 0.5f;
        snprintf(ev.str, sizeof(ev.str), "marker-%d", i);
        faxe_cbq_push(&ev);
    }
    for (int i = 0; i < 5; i++) {
        char expected[32];
        assert(faxe_cbq_pop(&out) == 1);
        assert(out.handle == 100 + i);
        assert(out.type == (1u << i));
        assert(out.i1 == i && out.i2 == i * 2 && out.i3 == i * 3);
        snprintf(expected, sizeof(expected), "marker-%d", i);
        assert(strcmp(out.str, expected) == 0);
    }
    assert(faxe_cbq_pop(&out) == 0);
    assert(faxe_cbq_take_overflow() == 0);

    /* string truncation stays NUL-terminated */
    memset(&ev, 0, sizeof(ev));
    memset(ev.str, 'x', sizeof(ev.str)); /* no terminator on purpose */
    faxe_cbq_push(&ev);
    assert(faxe_cbq_pop(&out) == 1);
    assert(out.str[FAXE_CBQ_STR_MAX - 1] == '\0');

    /* overflow drops oldest and sets the flag */
    memset(&ev, 0, sizeof(ev));
    for (int i = 0; i < FAXE_CBQ_CAPACITY + 10; i++) {
        ev.handle = i;
        faxe_cbq_push(&ev);
    }
    assert(faxe_cbq_take_overflow() == 1);
    assert(faxe_cbq_take_overflow() == 0); /* flag cleared */
    assert(faxe_cbq_pop(&out) == 1);
    assert(out.handle == 10); /* oldest 10 events were dropped */
    int drained = 1;
    while (faxe_cbq_pop(&out)) drained++;
    assert(drained == FAXE_CBQ_CAPACITY);
    assert(out.handle == FAXE_CBQ_CAPACITY + 9); /* newest survived */

    printf("faxe_cbqueue: all assertions passed\n");
    return 0;
}
