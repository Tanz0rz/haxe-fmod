/**
 * Per-instance native context for the haxefmod shims.
 *
 * Stored in FMOD userdata on every managed event instance (replacing the
 * raw handle int). FMOD callback threads receive it through the callback's
 * event pointer, so they can read the handle and programmer-sound key
 * without ever touching the handle table (which is only safe to access
 * from the Haxe thread).
 *
 * Lifetime: allocated at instance creation. The DESTROYED callback detaches
 * the context from FMOD userdata and hands it to the callback queue as the
 * event's opaque payload (instance creation always installs the shim
 * callback with at least the DESTROYED bit, so hand-off is guaranteed).
 * The game-thread drain frees it, along with the instance's handle-table
 * slot and any channel-group handle recorded in cgHandle. Freeing on the
 * FMOD thread would race game-thread writers that read the context pointer
 * from userdata just before destruction.
 *
 * Threading: handle and cgHandle are written from the game thread and read
 * on FMOD threads (handle) or the game thread only (cgHandle). psKey is
 * written from the Haxe thread and read from FMOD threads. Writers and the
 * FMOD-thread readers of handle and psKey must hold the callback-queue
 * mutex (see faxe_cbqueue.h) around access.
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

typedef struct {
    void* qnext;              /* reserved for the callback queue's orphan list */
    int handle;               /* handle-table handle for this instance */
    int cgHandle;             /* handle minted for the instance's channel group, or 0 */
    unsigned int cbMask;      /* callback mask requested via evi_set_callback_mask */
    char psKey[FAXE_PS_KEY_MAX]; /* programmer-sound key or file path. "" = none */
    void* psSound;            /* FMOD_SOUND* created for the active programmer sound */
} FaxeInstCtx;

static FaxeInstCtx* faxe_instctx_create(int handle) {
    FaxeInstCtx* ctx = (FaxeInstCtx*)calloc(1, sizeof(FaxeInstCtx));
    if (ctx) ctx->handle = handle;
    return ctx;
}

static void faxe_instctx_destroy(FaxeInstCtx* ctx) {
    free(ctx);
}

#endif /* FAXE_INSTCTX_H */
