/**
 * Argument checks the haxefmod native shims run before FMOD sees a value
 * that FMOD does not check itself. FMOD crashes, or writes outside its
 * own memory, on every value these refuse. jaxe.js mirrors each check,
 * where a refused value traps the wasm module instead.
 *
 * The limits were measured on FMOD 2.03.12 and 2.02.33. Both behave the
 * same on every value here.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_ARGCHECK_H
#define FAXE_ARGCHECK_H

/* Both shims include the FMOD headers before this one. */

/* FMOD sizes a subsound table and a decode buffer in 32 bits. A count
 * from this limit up can wrap that size, and FMOD then writes past the
 * allocation. */
#define FAXE_ARGCHECK_COUNT_LIMIT 0x01000000u

/* FMOD adds its own header to the byte length of a user sample. A length
 * from 0x7FFFFFB0 up overflows that sum and crashes the create, and one
 * near 4 GB wraps it to a tiny buffer. The limit keeps a wide margin. */
#define FAXE_ARGCHECK_USER_LENGTH_LIMIT 0x7FFF0000u

/* The defaultDecodeBufferSize FMOD uses when the advanced settings leave
 * it at 0, in milliseconds. */
#define FAXE_ARGCHECK_DEFAULT_DECODE_MS 400u

/* The largest mixer block FMOD initializes with on both SDK lines. Larger
 * blocks fail with FMOD_ERR_MEMORY, and from 0x3FFFFFF samples up the
 * initialize crashes. */
#define FAXE_ARGCHECK_DSP_BUFFER_LIMIT 0x01000000u

/* The FMOD_CREATESOUNDEXINFO fields a create hands FMOD. mode is the full
 * create mode. decodeMs is the core system's defaultDecodeBufferSize, 0
 * for FMOD's default. A user stream with no decode buffer of its own
 * sizes one from that and the rate in 32 bits, and FMOD divides by the
 * result. Returns 1 when FMOD may see the struct. */
static int faxe_argcheck_exinfo(const FMOD_CREATESOUNDEXINFO* exinfo, FMOD_MODE mode, unsigned int decodeMs) {
    /* A negative subsound count reads as a huge one here */
    if ((unsigned int)exinfo->numsubsounds >= FAXE_ARGCHECK_COUNT_LIMIT) return 0;
    if (exinfo->filebuffersize < -1) return 0;
    if (exinfo->decodebuffersize >= FAXE_ARGCHECK_COUNT_LIMIT) return 0;
    if (exinfo->defaultfrequency < 0) return 0;
    if (!(mode & FMOD_OPENUSER)) return 1;
    if (!(mode & FMOD_CREATESTREAM)) return exinfo->length < FAXE_ARGCHECK_USER_LENGTH_LIMIT;
    if (exinfo->decodebuffersize == 0) {
        unsigned int ms = decodeMs ? decodeMs : FAXE_ARGCHECK_DEFAULT_DECODE_MS;
        unsigned int product = ms * (unsigned int)exinfo->defaultfrequency;
        if (product / 1000u == 0) return 0;
    }
    return 1;
}

/* The byte length of a PCM16 record buffer, computed in 64 bits. The
 * arguments are positive. Returns 0 when the length reaches the user
 * sample limit. */
static unsigned int faxe_argcheck_record_length(int sampleRate, int channels, int seconds) {
    unsigned long long length = (unsigned long long)(unsigned int)sampleRate
        * (unsigned long long)(unsigned int)channels * 2ull * (unsigned long long)(unsigned int)seconds;
    if (length >= FAXE_ARGCHECK_USER_LENGTH_LIMIT) return 0;
    return (unsigned int)length;
}

/* FMOD checks only the upper bound of a speaker. FMOD_SPEAKER_NONE and
 * every other negative value index before its speaker table. */
static int faxe_argcheck_speaker(int speaker) {
    return speaker >= 0 && speaker < (int)FMOD_SPEAKER_MAX;
}

/* Studio reads a parameter label at a negative index from before its
 * label table. */
static int faxe_argcheck_label_index(int labelIndex) {
    return labelIndex >= 0;
}

/* A channel or group DSP chain index. FMOD takes the head, fader, and
 * tail markers down to FMOD_CHANNELCONTROL_DSP_TAIL and indexes before
 * the chain below that. */
static int faxe_argcheck_dsp_index(int index) {
    return index >= (int)FMOD_CHANNELCONTROL_DSP_TAIL;
}

/* FMOD checks only the upper bound of a thread type. */
static int faxe_argcheck_thread_type(int type) {
    return type >= 0 && type < (int)FMOD_THREAD_TYPE_MAX;
}

/* A mixer block length the initialize can take. 0 keeps FMOD's default
 * and is no request. */
static int faxe_argcheck_dsp_buffer(int length) {
    return length > 0 && (unsigned int)length <= FAXE_ARGCHECK_DSP_BUFFER_LIMIT;
}

#endif /* FAXE_ARGCHECK_H */
