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
#include <stdint.h>
#include "../../native/shared/faxe_cbqueue.h"

#ifdef _WIN32
#include <process.h>
#else
#include <pthread.h>
#endif

/* Stand-in for the opaque payloads the shims attach to DESTROYED events.
 * The leading next pointer is the queue's orphan-list contract. */
typedef struct {
    void* qnext;
    int tag;
} TestPayload;

/* Concurrent producer/consumer stress modeling the real deployment: the
 * FMOD studio thread pushes events (some carrying opaque DESTROYED-ctx
 * payloads) while the game thread drains. The invariant is the lifetime
 * contract the shims depend on: every payload is delivered EXACTLY once,
 * through the queue or the orphan list, never lost and never twice. Run
 * under TSan in CI to also prove the locking. */
#define STRESS_TOTAL 20000

typedef struct {
    void* qnext;
    int tag;
} StressPayload;

static StressPayload gPayloads[STRESS_TOTAL];
static unsigned char gSeen[STRESS_TOTAL];

#ifdef _WIN32
static unsigned __stdcall stress_producer(void* arg)
#else
static void* stress_producer(void* arg)
#endif
{
    FaxeCbEvent ev;
    int i;
    (void)arg;
    memset(&ev, 0, sizeof(ev));
    for (i = 0; i < STRESS_TOTAL; i++) {
        ev.handle = i;
        gPayloads[i].qnext = NULL;
        gPayloads[i].tag = i;
        ev.opaque = &gPayloads[i];
        faxe_cbq_push(&ev);
    }
#ifdef _WIN32
    return 0;
#else
    return NULL;
#endif
}

static int stress_note_orphans(void) {
    int noted = 0;
    StressPayload* orphan = (StressPayload*)faxe_cbq_take_orphans();
    while (orphan) {
        gSeen[orphan->tag]++;
        noted++;
        orphan = (StressPayload*)orphan->qnext;
    }
    return noted;
}

static void test_concurrent_payload_delivery(void) {
    FaxeCbEvent out;
    int lastHandle = -1;
    int seen = 0;
    int i;
#ifdef _WIN32
    HANDLE th = (HANDLE)_beginthreadex(NULL, 0, stress_producer, NULL, 0, NULL);
    assert(th != NULL);
#else
    pthread_t th;
    assert(pthread_create(&th, NULL, stress_producer, NULL) == 0);
#endif

    /* Drain concurrently with the producer. Every payload must arrive
     * exactly once - through a popped event or the orphan list - so the
     * running count reaching the total IS the termination condition (a
     * lost payload would hang here, which the CI job timeout turns into
     * a failure). */
    while (seen < STRESS_TOTAL) {
        if (faxe_cbq_pop(&out)) {
            assert(out.handle > lastHandle); /* FIFO order survives drops */
            lastHandle = out.handle;
            assert(out.opaque != NULL); /* every stress event carries one */
            gSeen[((StressPayload*)out.opaque)->tag]++;
            seen++;
        }
        seen += stress_note_orphans();
    }
    assert(faxe_cbq_pop(&out) == 0); /* nothing beyond the total */
    faxe_cbq_take_overflow(); /* drops are legal, the flag just reports them */

#ifdef _WIN32
    WaitForSingleObject(th, INFINITE);
    CloseHandle(th);
#else
    pthread_join(th, NULL);
#endif

    for (i = 0; i < STRESS_TOTAL; i++) {
        assert(gSeen[i] == 1); /* delivered exactly once, queue or orphan */
    }
}

int main(void) {
    FaxeCbEvent ev;
    FaxeCbEvent out;

    /* pop before init is a safe no-op */
    assert(faxe_cbq_pop(&out) == 0);
    assert(faxe_cbq_take_overflow() == 0);
    assert(faxe_cbq_take_orphans() == NULL);

    faxe_cbq_init();
    faxe_cbq_init(); /* double init is a safe no-op */

    /* bank path stash: put, take once, then gone */
    {
        char path[FAXE_CBQ_STR_MAX];
        int bankA = 1, bankB = 2, i;
        char name[16];
        assert(faxe_bankpath_take(&bankA, path) == 0 && path[0] == '\0'); /* nothing stashed yet */
        faxe_bankpath_put(&bankA, "bank:/A");
        faxe_bankpath_put(&bankA, "bank:/A2"); /* same bank updates in place */
        assert(faxe_bankpath_take(&bankA, path) == 1);
        assert(strcmp(path, "bank:/A2") == 0);
        assert(faxe_bankpath_take(&bankA, path) == 0); /* consumed */
        faxe_bankpath_put(&bankB, "");             /* empty path is ignored */
        assert(faxe_bankpath_take(&bankB, path) == 0);
        faxe_bankpath_put(NULL, "bank:/none");     /* null bank is ignored */
        /* a full table overwrites the oldest entry */
        for (i = 0; i < FAXE_BANKPATH_CAPACITY + 1; i++) {
            snprintf(name, sizeof(name), "bank:/%d", i);
            faxe_bankpath_put((const void*)(uintptr_t)(100 + i), name);
        }
        assert(faxe_bankpath_take((const void*)(uintptr_t)100, path) == 0);   /* oldest gone */
        assert(faxe_bankpath_take((const void*)(uintptr_t)(100 + FAXE_BANKPATH_CAPACITY), path) == 1);
        faxe_bankpath_clear();
        assert(faxe_bankpath_take((const void*)(uintptr_t)101, path) == 0);   /* cleared */
    }

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
        ev.i4 = i * 4;
        ev.i5 = i * 5;
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
        assert(out.i4 == i * 4 && out.i5 == i * 5);
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

    /* opaque payloads ride the queue and come back intact */
    {
        TestPayload payload;
        payload.qnext = NULL;
        payload.tag = 42;
        memset(&ev, 0, sizeof(ev));
        ev.handle = 7;
        ev.opaque = &payload;
        faxe_cbq_push(&ev);
        assert(faxe_cbq_pop(&out) == 1);
        assert(out.opaque == &payload);
        assert(((TestPayload*)out.opaque)->tag == 42);
        assert(faxe_cbq_take_orphans() == NULL); /* consumed, not orphaned */
    }

    /* payloads of dropped events land on the orphan list, oldest-dropped
     * last (the list is a stack), and the list clears on take */
    {
        TestPayload first;
        TestPayload second;
        TestPayload* orphan;
        first.qnext = NULL;
        first.tag = 1;
        second.qnext = NULL;
        second.tag = 2;
        memset(&ev, 0, sizeof(ev));
        ev.opaque = &first;
        faxe_cbq_push(&ev);
        ev.opaque = &second;
        faxe_cbq_push(&ev);
        ev.opaque = NULL;
        for (int i = 0; i < FAXE_CBQ_CAPACITY; i++) {
            ev.handle = i;
            faxe_cbq_push(&ev); /* pushes both payload events off the ring */
        }
        assert(faxe_cbq_take_overflow() == 1);
        orphan = (TestPayload*)faxe_cbq_take_orphans();
        assert(orphan == &second);
        assert(((TestPayload*)orphan->qnext) == &first);
        assert(((TestPayload*)orphan->qnext)->qnext == NULL);
        assert(faxe_cbq_take_orphans() == NULL); /* cleared */
        while (faxe_cbq_pop(&out)) {
            assert(out.opaque == NULL); /* surviving events carry no payload */
        }
    }

    test_concurrent_payload_delivery();

    printf("faxe_cbqueue: all assertions passed\n");
    return 0;
}
