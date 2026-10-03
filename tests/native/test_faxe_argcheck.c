/*
 * Unit tests for native/shared/faxe_argcheck.h against a real FMOD SDK's
 * headers. Each check refuses the values FMOD crashes on and passes the
 * values a game uses. The boundaries are the measured ones.
 * Build and run with:
 *
 *   gcc -std=c99 -Wall -Wextra -Werror -I<sdk>/api/core/inc \
 *       -o t tests/native/test_faxe_argcheck.c && ./t
 */
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "fmod.h"
#include "../../native/shared/faxe_argcheck.h"

static FMOD_CREATESOUNDEXINFO base(void) {
    FMOD_CREATESOUNDEXINFO exinfo;
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(exinfo);
    return exinfo;
}

/* A user sample the way a game creates one to lock and fill */
static FMOD_CREATESOUNDEXINFO user(unsigned int length) {
    FMOD_CREATESOUNDEXINFO exinfo = base();
    exinfo.numchannels = 2;
    exinfo.defaultfrequency = 48000;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    exinfo.length = length;
    return exinfo;
}

static void test_exinfo_counts(void) {
    FMOD_CREATESOUNDEXINFO exinfo = base();
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 1);
    exinfo.numsubsounds = -1;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    exinfo.numsubsounds = (int)0x80000000u;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    exinfo.numsubsounds = 0x00FFFFFF;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 1);
    exinfo.numsubsounds = 0x01000000;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    exinfo.numsubsounds = 0x3FFFFFFF;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER, 0) == 0);

    /* 32 channels of 4 byte samples wrap the decode buffer from 0x7FFFF8 frames */
    exinfo = base();
    exinfo.decodebuffersize = 4096;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER | FMOD_CREATESTREAM, 0) == 1);
    exinfo.decodebuffersize = 0x003FFFFF;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 1);
    exinfo.decodebuffersize = 0x00400000;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 0);
    exinfo.decodebuffersize = 0x007FFFF8;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER | FMOD_CREATESTREAM, 0) == 0);
    exinfo.decodebuffersize = 0x00FFFFFF;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER | FMOD_CREATESTREAM, 0) == 0);
    exinfo.decodebuffersize = 0x01000000;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 0);
    exinfo.decodebuffersize = 0x3FFFFFFF;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER | FMOD_CREATESTREAM, 0) == 0);
    exinfo.decodebuffersize = 0xFFFFFFFEu;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 0);
}

static void test_exinfo_file_buffer(void) {
    FMOD_CREATESOUNDEXINFO exinfo = base();
    exinfo.filebuffersize = -1;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 1);
    exinfo.filebuffersize = 0;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 1);
    exinfo.filebuffersize = 65536;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 1);
    exinfo.filebuffersize = -2;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    exinfo.filebuffersize = -8;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    exinfo.filebuffersize = (int)0x80000000u;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
}

static void test_exinfo_user_length(void) {
    FMOD_CREATESOUNDEXINFO exinfo = user(4000);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER, 0) == 1);
    exinfo = user(0x7FFEFFFFu);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER, 0) == 1);
    exinfo = user(0x7FFF0000u);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER, 0) == 0);
    exinfo = user(0x7FFFFFB0u);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER, 0) == 0);
    exinfo = user(0xFFFFFFF0u);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER | FMOD_LOOP_NORMAL, 0) == 0);
    /* A stream never allocates its length, and a file read is no user sample */
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER | FMOD_CREATESTREAM, 0) == 1);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 1);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENMEMORY | FMOD_OPENRAW, 0) == 1);
}

static void test_exinfo_frequency(void) {
    FMOD_CREATESOUNDEXINFO exinfo = user(4000);
    FMOD_MODE stream = FMOD_OPENUSER | FMOD_CREATESTREAM;
    exinfo.defaultfrequency = -1;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    exinfo.defaultfrequency = (int)0x80000000u;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_DEFAULT, 0) == 0);
    /* 400 ms of 1 or 2 Hz is no sample, and FMOD divides by that */
    exinfo.defaultfrequency = 1;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 0);
    exinfo.defaultfrequency = 2;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 0);
    exinfo.defaultfrequency = 3;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 1);
    /* FMOD multiplies in 32 bits, so 2^28 wraps to 0 */
    exinfo.defaultfrequency = 0x10000000;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 0);
    exinfo.defaultfrequency = 10737418;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 1);
    /* The configured default decode buffer counts */
    exinfo.defaultfrequency = 999;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 1) == 0);
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 1);
    exinfo.defaultfrequency = 1000;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 1) == 1);
    /* A decode buffer of its own, or a sample, takes any positive rate */
    exinfo.defaultfrequency = 1;
    exinfo.decodebuffersize = 4096;
    assert(faxe_argcheck_exinfo(&exinfo, stream, 0) == 1);
    exinfo.decodebuffersize = 0;
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_OPENUSER, 0) == 1);
    assert(faxe_argcheck_exinfo(&exinfo, FMOD_CREATESTREAM, 0) == 1);
}

static void test_record_length(void) {
    assert(faxe_argcheck_record_length(48000, 2, 1) == 192000u);
    assert(faxe_argcheck_record_length(44100, 1, 10) == 882000u);
    /* 11185 seconds is the first whole second past the limit. 22370 seconds wraps 32 bits. */
    assert(faxe_argcheck_record_length(48000, 2, 11185) == 0);
    assert(faxe_argcheck_record_length(48000, 2, 22370) == 0);
    assert(faxe_argcheck_record_length(1073741820, 2, 1) == 0);
    assert(faxe_argcheck_record_length(0x7FFFFFFF, 2, 0x7FFFFFFF) == 0);
    /* The last length under the limit and the limit itself */
    assert(faxe_argcheck_record_length(0x3FFF7FFF, 1, 1) == 0x7FFEFFFEu);
    assert(faxe_argcheck_record_length(0x3FFF8000, 1, 1) == 0);
}

static void test_indexes(void) {
    assert(faxe_argcheck_speaker(FMOD_SPEAKER_FRONT_LEFT) == 1);
    assert(faxe_argcheck_speaker(FMOD_SPEAKER_MAX - 1) == 1);
    assert(faxe_argcheck_speaker(FMOD_SPEAKER_MAX) == 0);
    assert(faxe_argcheck_speaker(FMOD_SPEAKER_NONE) == 0);
    assert(faxe_argcheck_speaker(-65536) == 0);
    assert(faxe_argcheck_speaker((int)0x80000000u) == 0);

    assert(faxe_argcheck_label_index(0) == 1);
    assert(faxe_argcheck_label_index(1000) == 1);
    assert(faxe_argcheck_label_index(-1) == 0);
    assert(faxe_argcheck_label_index((int)0x80000000u) == 0);

    assert(FMOD_CHANNELCONTROL_DSP_HEAD == -1 && FMOD_CHANNELCONTROL_DSP_TAIL == -3);
    assert(faxe_argcheck_dsp_index(FMOD_CHANNELCONTROL_DSP_HEAD) == 1);
    assert(faxe_argcheck_dsp_index(FMOD_CHANNELCONTROL_DSP_FADER) == 1);
    assert(faxe_argcheck_dsp_index(FMOD_CHANNELCONTROL_DSP_TAIL) == 1);
    assert(faxe_argcheck_dsp_index(0) == 1);
    assert(faxe_argcheck_dsp_index(1000) == 1);
    assert(faxe_argcheck_dsp_index(-4) == 0);
    assert(faxe_argcheck_dsp_index((int)0x80000000u) == 0);

    assert(faxe_argcheck_thread_type(FMOD_THREAD_TYPE_MIXER) == 1);
    assert(faxe_argcheck_thread_type(FMOD_THREAD_TYPE_MAX - 1) == 1);
    assert(faxe_argcheck_thread_type(FMOD_THREAD_TYPE_MAX) == 0);
    assert(faxe_argcheck_thread_type(-1) == 0);
    assert(faxe_argcheck_thread_type((int)0x80000000u) == 0);
}

static void test_dsp_buffer(void) {
    assert(faxe_argcheck_dsp_buffer(0) == 0);
    assert(faxe_argcheck_dsp_buffer(-1) == 0);
    assert(faxe_argcheck_dsp_buffer(64) == 1);
    assert(faxe_argcheck_dsp_buffer(1024) == 1);
    assert(faxe_argcheck_dsp_buffer(0x01000000) == 1);
    assert(faxe_argcheck_dsp_buffer(0x01000001) == 0);
    assert(faxe_argcheck_dsp_buffer(0x04000000) == 0);
    assert(faxe_argcheck_dsp_buffer(0x3FFFFFFF) == 0);
    assert(faxe_argcheck_dsp_buffer(0x7FFFFFFF) == 0);
}

static void test_software_channels(void) {
    assert(faxe_argcheck_software_channels(0) == 0);
    assert(faxe_argcheck_software_channels(-1) == 0);
    assert(faxe_argcheck_software_channels(64) == 1);
    assert(faxe_argcheck_software_channels(4096) == 1);
    assert(faxe_argcheck_software_channels(0x00100000) == 1);
    assert(faxe_argcheck_software_channels(0x00100001) == 0);
    /* 2.02.33 crashes from here */
    assert(faxe_argcheck_software_channels(10956550) == 0);
    /* 2.03.12 crashes from here */
    assert(faxe_argcheck_software_channels(0x20000000) == 0);
    assert(faxe_argcheck_software_channels(0x7FFFFFFF) == 0);
    assert(faxe_argcheck_software_channels((int)0x80000000u) == 0);
}

int main(void) {
    test_exinfo_counts();
    test_exinfo_file_buffer();
    test_exinfo_user_length();
    test_exinfo_frequency();
    test_record_length();
    test_indexes();
    test_dsp_buffer();
    test_software_channels();
    printf("faxe_argcheck: all tests passed\n");
    return 0;
}
