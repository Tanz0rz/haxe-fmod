/* Tests for native/shared/faxe_pcmring.h in both C99 and C++ modes.
 * Covers data integrity through wraparound, full-buffer partial writes,
 * underrun padding and counting, and a two-thread producer/consumer run
 * with byte-exact sequence validation. */

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "../../native/shared/faxe_pcmring.h"

#ifdef _WIN32
#include <process.h>
#else
#include <pthread.h>
#endif

static void test_roundtrip_and_wraparound(void) {
    FaxePcmRing* r = faxe_pcmring_create(16);
    unsigned char in[12], out[12];
    int i;

    assert(r != NULL);
    assert(faxe_pcmring_space(r) == 16);
    assert(faxe_pcmring_fill(r) == 0);

    for (i = 0; i < 12; i++) in[i] = (unsigned char)(i + 1);
    assert(faxe_pcmring_write(r, in, 12) == 12);
    assert(faxe_pcmring_fill(r) == 12);
    assert(faxe_pcmring_read(r, out, 12) == 12);
    assert(memcmp(in, out, 12) == 0);

    /* readPos/writePos now sit at 12 of 16: the next 12 bytes wrap */
    for (i = 0; i < 12; i++) in[i] = (unsigned char)(100 + i);
    assert(faxe_pcmring_write(r, in, 12) == 12);
    assert(faxe_pcmring_read(r, out, 12) == 12);
    assert(memcmp(in, out, 12) == 0);

    faxe_pcmring_destroy(r);
}

static void test_partial_write_when_full(void) {
    FaxePcmRing* r = faxe_pcmring_create(8);
    unsigned char data[12];
    unsigned char sink[8];

    memset(data, 0xAB, sizeof(data));
    assert(faxe_pcmring_write(r, data, 12) == 8); /* only capacity fits */
    assert(faxe_pcmring_space(r) == 0);
    assert(faxe_pcmring_write(r, data, 1) == 0);  /* full: nothing fits */
    assert(faxe_pcmring_read(r, sink, 8) == 8);
    faxe_pcmring_destroy(r);
}

static void test_underrun_pads_with_silence(void) {
    FaxePcmRing* r = faxe_pcmring_create(32);
    unsigned char out[16];
    unsigned char in[4] = {9, 9, 9, 9};
    int i;

    assert(faxe_pcmring_write(r, in, 4) == 4);
    memset(out, 0xFF, sizeof(out));
    assert(faxe_pcmring_read(r, out, 16) == 4); /* 4 real bytes */
    for (i = 0; i < 4; i++) assert(out[i] == 9);
    for (i = 4; i < 16; i++) assert(out[i] == 0); /* silence padding */
    assert(faxe_pcmring_take_underruns(r) == 1);
    assert(faxe_pcmring_take_underruns(r) == 0); /* cleared */
    faxe_pcmring_destroy(r);
}

static void test_null_and_bad_args(void) {
    FaxePcmRing* r = faxe_pcmring_create(8);
    unsigned char b[4];
    assert(faxe_pcmring_create(0) == NULL);
    assert(faxe_pcmring_create(-1) == NULL);
    assert(faxe_pcmring_write(NULL, b, 4) == 0);
    assert(faxe_pcmring_read(NULL, b, 4) == 0);
    assert(faxe_pcmring_write(r, NULL, 4) == 0);
    assert(faxe_pcmring_write(r, b, 0) == 0);
    assert(faxe_pcmring_space(NULL) == 0);
    assert(faxe_pcmring_fill(NULL) == 0);
    assert(faxe_pcmring_take_underruns(NULL) == 0);
    faxe_pcmring_destroy(NULL);
    faxe_pcmring_destroy(r);
}

/* Two-thread run: the producer streams an incrementing byte sequence while
 * the consumer drains fixed-size blocks, mimicking mixer pulls. Every real
 * byte must arrive in order with none lost or duplicated. */

#define STREAM_TOTAL 262144
#define READ_BLOCK 512

static FaxePcmRing* gRing;
static volatile int gProducerDone = 0;

#ifdef _WIN32
static unsigned __stdcall producer_main(void* arg)
#else
static void* producer_main(void* arg)
#endif
{
    unsigned char chunk[300];
    int sent = 0;
    (void)arg;
    while (sent < STREAM_TOTAL) {
        int want = STREAM_TOTAL - sent;
        int i, wrote;
        if (want > (int)sizeof(chunk)) want = (int)sizeof(chunk);
        for (i = 0; i < want; i++) chunk[i] = (unsigned char)((sent + i) & 0xFF);
        wrote = faxe_pcmring_write(gRing, chunk, want);
        sent += wrote;
    }
    gProducerDone = 1;
#ifdef _WIN32
    return 0;
#else
    return NULL;
#endif
}

static void test_two_thread_stream(void) {
    unsigned char block[READ_BLOCK];
    long expected = 0;
    int idleReads = 0;

    gRing = faxe_pcmring_create(4096);
    gProducerDone = 0;

#ifdef _WIN32
    HANDLE th = (HANDLE)_beginthreadex(NULL, 0, producer_main, NULL, 0, NULL);
    assert(th != NULL);
#else
    pthread_t th;
    assert(pthread_create(&th, NULL, producer_main, NULL) == 0);
#endif

    while (expected < STREAM_TOTAL) {
        int got = faxe_pcmring_read(gRing, block, READ_BLOCK);
        int i;
        for (i = 0; i < got; i++) {
            assert(block[i] == (unsigned char)(expected & 0xFF));
            expected++;
        }
        if (got == 0) {
            idleReads++;
            assert(idleReads < 10000000); /* the stream must make progress */
        }
    }
    assert(expected == STREAM_TOTAL);
    assert(gProducerDone);

#ifdef _WIN32
    WaitForSingleObject(th, INFINITE);
    CloseHandle(th);
#else
    pthread_join(th, NULL);
#endif

    /* underruns were counted while the consumer outpaced the producer;
     * they only need to be non-negative and clearable */
    assert(faxe_pcmring_take_underruns(gRing) >= 0);
    faxe_pcmring_destroy(gRing);
}

int main(void) {
    test_roundtrip_and_wraparound();
    test_partial_write_when_full();
    test_underrun_pads_with_silence();
    test_null_and_bad_args();
    test_two_thread_stream();
    printf("faxe_pcmring: all assertions passed\n");
    return 0;
}
