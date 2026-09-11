/**
 * Per-instance native context for the haxefmod shims.
 *
 * Stored in FMOD userdata on every managed event instance (replacing the
 * raw handle int). FMOD callback threads receive it through the callback's
 * event pointer. They can read the handle and programmer-sound key
 * without ever touching the handle table, which is only safe to access
 * from the Haxe thread.
 *
 * Lifetime: allocated at instance creation. The DESTROYED callback detaches
 * the context from FMOD userdata and hands it to the callback queue as the
 * event's opaque payload. Instance creation always installs the shim
 * callback with at least the DESTROYED bit, so hand-off is guaranteed.
 * The game-thread drain frees it, along with the instance's handle-table
 * slot and any channel-group handle recorded in cgHandle. Freeing on the
 * FMOD thread would race game-thread writers that read the context pointer
 * from userdata just before destruction.
 *
 * Threading: handle and cgHandle are written from the game thread and read
 * on FMOD threads (handle) or the game thread only (cgHandle). The
 * programmer-sound fields (psKey, psGameSound, psGameSubsound, psNamed)
 * are written from the Haxe thread and read from FMOD threads. psSounds
 * is written from the FMOD thread and read from the Haxe thread. Every
 * writer and every cross-thread reader of handle and those fields must
 * hold the callback-queue mutex (see faxe_cbqueue.h) around access.
 *
 * Used by linc_faxe.cpp (C++) and hlaxe_fmod.c (C99). jaxe.js mirrors the
 * same logic with a plain map (JS is single-threaded).
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_INSTCTX_H
#define FAXE_INSTCTX_H

#include <stdlib.h>
#include <string.h>

/* Matches the 512-byte native string buffer so keys and file paths
 * truncate at the same point on every target. */
#define FAXE_PS_KEY_MAX 512
/* Programmer instrument names as authored in FMOD Studio. */
#define FAXE_PS_NAME_MAX 64
/* Name-to-key entries one instance can hold. */
#define FAXE_PS_NAMED_MAX 8

typedef struct {
    char name[FAXE_PS_NAME_MAX];
    char key[FAXE_PS_KEY_MAX];
} FaxePsNamed;

typedef struct {
    void* qnext;              /* reserved for the callback queue's orphan list */
    int handle;               /* handle-table handle for this instance */
    int cgHandle;             /* handle minted for the instance's channel group, or 0 */
    unsigned int cbMask;      /* callback mask requested via evi_set_callback_mask */
    char psKey[FAXE_PS_KEY_MAX]; /* programmer-sound key or file path. "" = none */
    void* psSounds[FAXE_PS_NAMED_MAX]; /* FMOD_SOUND* the shim created per live instrument, released on destroy */
    void* psGameSound;        /* FMOD_SOUND* the game owns and keeps alive, never released here */
    int psGameSubsound;       /* subsound index handed over with psGameSound, -1 for the sound itself */
    FaxePsNamed* psNamed;     /* name-to-key entries, allocated on first use */
    int psNamedCount;
} FaxeInstCtx;

static FaxeInstCtx* faxe_instctx_create(int handle) {
    FaxeInstCtx* ctx = (FaxeInstCtx*)calloc(1, sizeof(FaxeInstCtx));
    if (ctx) {
        ctx->handle = handle;
        ctx->psGameSubsound = -1;
    }
    return ctx;
}

static void faxe_instctx_destroy(FaxeInstCtx* ctx) {
    if (ctx) free(ctx->psNamed);
    free(ctx);
}

/* True when any programmer-sound assignment is present. Caller holds
 * the callback-queue lock. */
static int faxe_instctx_ps_armed(const FaxeInstCtx* ctx) {
    return ctx->psKey[0] != '\0' || ctx->psGameSound != NULL || ctx->psNamedCount > 0;
}

/* True while the shim still owns a sound it created for an instrument.
 * The installed callback mask keeps its DESTROY_PROGRAMMER_SOUND bit as
 * long as this holds, so the release runs even after a clear. Caller
 * holds the callback-queue lock. */
static int faxe_instctx_ps_sound_pending(const FaxeInstCtx* ctx) {
    int i;
    for (i = 0; i < FAXE_PS_NAMED_MAX; i++) {
        if (ctx->psSounds[i] != NULL) return 1;
    }
    return 0;
}

/* Records a sound the shim created for an instrument. Several
 * instruments on one instance can be live at once, so each gets its
 * own slot. Returns 0 when every slot is taken. Caller holds the
 * callback-queue lock. */
static int faxe_instctx_ps_sound_add(FaxeInstCtx* ctx, void* sound) {
    int i;
    if (!sound) return 0;
    for (i = 0; i < FAXE_PS_NAMED_MAX; i++) {
        if (ctx->psSounds[i] == NULL) {
            ctx->psSounds[i] = sound;
            return 1;
        }
    }
    return 0;
}

/* How many sounds are recorded. */
static int faxe_instctx_ps_take_count(const FaxeInstCtx* ctx) {
    int i, n = 0;
    for (i = 0; i < FAXE_PS_NAMED_MAX; i++) {
        if (ctx->psSounds[i] != NULL) n++;
    }
    return n;
}

/* Forgets a recorded sound. Returns 1 when the shim owned it, so the
 * caller releases it, 0 for a game-owned or unknown sound. Caller holds
 * the callback-queue lock. */
static int faxe_instctx_ps_sound_take(FaxeInstCtx* ctx, const void* sound) {
    int i;
    if (!sound) return 0;
    for (i = 0; i < FAXE_PS_NAMED_MAX; i++) {
        if (ctx->psSounds[i] == sound) {
            ctx->psSounds[i] = NULL;
            return 1;
        }
    }
    return 0;
}

/* Drops every assignment. The recorded sounds survive, because the
 * sounds behind them are live and still need their release. Caller
 * holds the callback-queue lock. */
static void faxe_instctx_ps_clear(FaxeInstCtx* ctx) {
    ctx->psKey[0] = '\0';
    ctx->psGameSound = NULL;
    ctx->psGameSubsound = -1;
    ctx->psNamedCount = 0;
}

/* Adds or replaces the key for an instrument name. Returns 1 on success,
 * 0 when the table is full, -1 when name or key does not fit. Caller
 * holds the callback-queue lock. */
static int faxe_instctx_ps_set_named(FaxeInstCtx* ctx, const char* name, const char* key) {
    int i;
    if (!name || !key || strlen(name) >= FAXE_PS_NAME_MAX || strlen(key) >= FAXE_PS_KEY_MAX) return -1;
    if (!ctx->psNamed) {
        ctx->psNamed = (FaxePsNamed*)calloc(FAXE_PS_NAMED_MAX, sizeof(FaxePsNamed));
        if (!ctx->psNamed) return 0;
        ctx->psNamedCount = 0;
    }
    for (i = 0; i < ctx->psNamedCount; i++) {
        if (strcmp(ctx->psNamed[i].name, name) == 0) break;
    }
    if (i == ctx->psNamedCount) {
        if (i >= FAXE_PS_NAMED_MAX) return 0;
        ctx->psNamedCount++;
        strncpy(ctx->psNamed[i].name, name, FAXE_PS_NAME_MAX - 1);
        ctx->psNamed[i].name[FAXE_PS_NAME_MAX - 1] = '\0';
    }
    strncpy(ctx->psNamed[i].key, key, FAXE_PS_KEY_MAX - 1);
    ctx->psNamed[i].key[FAXE_PS_KEY_MAX - 1] = '\0';
    return 1;
}

/* Copies the key for an instrument name into out, which holds
 * FAXE_PS_KEY_MAX bytes, and returns 1. A name with no entry returns 0
 * and leaves out alone. Caller holds the callback-queue lock. */
static int faxe_instctx_ps_find_named(const FaxeInstCtx* ctx, const char* name, char* out) {
    int i;
    if (!name || !ctx->psNamed) return 0;
    for (i = 0; i < ctx->psNamedCount; i++) {
        if (strcmp(ctx->psNamed[i].name, name) == 0) {
            strncpy(out, ctx->psNamed[i].key, FAXE_PS_KEY_MAX - 1);
            out[FAXE_PS_KEY_MAX - 1] = '\0';
            return 1;
        }
    }
    return 0;
}

#endif /* FAXE_INSTCTX_H */
