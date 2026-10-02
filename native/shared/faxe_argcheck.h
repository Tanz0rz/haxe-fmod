/**
 * Argument checks the haxefmod native shims run before FMOD sees a value
 * that FMOD does not check itself. FMOD crashes, or writes outside its
 * own memory, on the values these refuse. The user length, decode
 * buffer, mixer block, and software channel limits also refuse a margin
 * below the crash. jaxe.js mirrors each check, where a refused value
 * traps the wasm module instead.
 *
 * The limits were measured on FMOD 2.03.12 and 2.02.33. Every limit holds
 * on both.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_ARGCHECK_H
#define FAXE_ARGCHECK_H

/* Both shims include the FMOD headers before this one. */

/* FMOD sizes a subsound table in 32 bits. A count from this limit up
 * can wrap that size, and FMOD then writes past the allocation. */
#define FAXE_ARGCHECK_COUNT_LIMIT 0x01000000u

/* FMOD sizes the decode buffer of a user stream as about four blocks of
 * decodebuffersize sample frames in 32 bits. With 32 channels of 4 byte
 * samples that size wraps from 0x7FFFF8 frames up, and FMOD then writes
 * past the allocation. The limit is half that, which holds for every
 * channel count and format FMOD takes. */
#define FAXE_ARGCHECK_DECODE_LIMIT 0x00400000u

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

/* The largest software channel count the shims hand FMOD. FMOD sizes its
 * channel pool in 32 bits, and the initialize crashes from 0x20000000
 * channels up on 2.03.12 and from 10956550 up on 2.02.33. The limit
 * keeps a wide margin. */
#define FAXE_ARGCHECK_SOFTWARE_CHANNELS_LIMIT 0x00100000u

/* The FMOD_CREATESOUNDEXINFO fields a create hands FMOD. mode is the full
 * create mode. decodeMs is the core system's defaultDecodeBufferSize, 0
 * for FMOD's default. A user stream with no decode buffer of its own
 * sizes one from that and the rate in 32 bits, and FMOD divides by the
 * result. Returns 1 when FMOD may see the struct. */
static int faxe_argcheck_exinfo(const FMOD_CREATESOUNDEXINFO* exinfo, FMOD_MODE mode, unsigned int decodeMs) {
    /* A negative subsound count reads as a huge one here */
    if ((unsigned int)exinfo->numsubsounds >= FAXE_ARGCHECK_COUNT_LIMIT) return 0;
    if (exinfo->filebuffersize < -1) return 0;
    if (exinfo->decodebuffersize >= FAXE_ARGCHECK_DECODE_LIMIT) return 0;
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

/* A software channel count the initialize can take. 0 keeps FMOD's
 * default and is no request. */
static int faxe_argcheck_software_channels(int count) {
    return count > 0 && (unsigned int)count <= FAXE_ARGCHECK_SOFTWARE_CHANNELS_LIMIT;
}

/* Whether child is group itself or a group above it, such as the master.
 * FMOD recurses without end on such an addGroup and overflows the stack.
 * The walk reads FMOD's parent links. The depth bound keeps it finite. */
static inline int faxe_argcheck_group_above(FMOD_CHANNELGROUP* group, FMOD_CHANNELGROUP* child) {
    int depth;
    for (depth = 0; group && depth < 4096; depth++) {
        FMOD_CHANNELGROUP* parent = NULL;
        if (group == child) return 1;
        if (FMOD_ChannelGroup_GetParentGroup(group, &parent) != FMOD_OK) break;
        group = parent;
    }
    return 0;
}

/* Counts the connections that join a unit's head DSP to the tail of its
 * parent group and puts the first one in *conn, NULL when there is none.
 * A move to another parent destroys the parent connection and leaves the
 * head's other connections alone. A game connection between the same two
 * DSPs can come first, so with a count above one the caller cannot tell
 * which one a move destroys. */
static inline int faxe_parent_connection(FMOD_DSP* head, FMOD_CHANNELGROUP* parent, FMOD_DSPCONNECTION** conn) {
    FMOD_DSP* tail = NULL;
    int count = 0, found = 0, i;
    *conn = NULL;
    if (!head || !parent || FMOD_ChannelGroup_GetDSP(parent, FMOD_CHANNELCONTROL_DSP_TAIL, &tail) != FMOD_OK) return 0;
    if (FMOD_DSP_GetNumOutputs(head, &count) != FMOD_OK) return 0;
    for (i = 0; i < count; i++) {
        FMOD_DSP* output = NULL;
        FMOD_DSPCONNECTION* c = NULL;
        if (FMOD_DSP_GetOutput(head, i, &output, &c) == FMOD_OK && output == tail) {
            if (!found) *conn = c;
            found++;
        }
    }
    return found;
}

/* The top sound of a subsound tree. The subsounds of a stream share its
 * decoder. */
static inline FMOD_SOUND* faxe_argcheck_sound_root(FMOD_SOUND* sound) {
    int depth;
    for (depth = 0; depth < 16; depth++) {
        FMOD_SOUND* parent = NULL;
        if (FMOD_Sound_GetSubSoundParent(sound, &parent) != FMOD_OK || !parent) break;
        sound = parent;
    }
    return sound;
}

/* Whether readData and seekData may run on the sound. This check reads
 * FMOD's channel pool instead of a value. FMOD decodes a playing sound on
 * its mixer and stream threads. A readData or seekData on a sound of the
 * same subsound tree races that decoder and crashes FMOD. Returns 0 while
 * a channel plays a sound of the tree. A paused channel counts as playing.
 * Its decoder keeps working for a moment after the pause. A virtual
 * channel counts as playing too. Studio plays a programmer sound on a pool
 * channel. The scan sees that channel too. The scan covers every pool
 * channel. It costs about 4 microseconds at 128 channels and 270 at 4095.
 * The game thread makes the check and the read. That thread also starts
 * every channel the game plays. Studio starts event channels on its own
 * update thread. A programmer sound can start between the check and the
 * read. jaxe.js has no counterpart. The web build reports readData and
 * seekData unsupported. */
static inline int faxe_argcheck_sound_idle(FMOD_SYSTEM* system, FMOD_SOUND* sound) {
    FMOD_SOUND* root;
    FMOD_CHANNEL* channel = NULL;
    int i;
    if (!system) return 1;
    root = faxe_argcheck_sound_root(sound);
    for (i = 0; FMOD_System_GetChannel(system, i, &channel) == FMOD_OK; i++) {
        FMOD_BOOL playing = 0;
        FMOD_SOUND* current = NULL;
        if (FMOD_Channel_IsPlaying(channel, &playing) != FMOD_OK || !playing) continue;
        if (FMOD_Channel_GetCurrentSound(channel, &current) != FMOD_OK || !current) continue;
        if (faxe_argcheck_sound_root(current) == root) return 0;
    }
    return 1;
}

#endif /* FAXE_ARGCHECK_H */
