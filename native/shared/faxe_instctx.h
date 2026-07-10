/**
 * Per-instance native context for the haxefmod shims.
 *
 * Stored in FMOD userdata on every managed event instance (replacing the
 * raw handle int). FMOD callback threads receive it through the callback's
 * event pointer, so they can read the handle and programmer-sound key
 * without ever touching the handle table (which is only safe to access
 * from the Haxe thread).
 *
 * Lifetime: allocated at instance creation, freed by the DESTROYED
 * callback (instance creation always installs the shim callback with at
 * least the DESTROYED bit so cleanup is guaranteed).
 *
 * Threading: handle is written once before the context is attached. psKey
 * is written from the Haxe thread and read from FMOD threads. Both sides
 * must hold the callback-queue mutex (see faxe_cbqueue.h) around access.
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

#define FAXE_PS_KEY_MAX 256

typedef struct {
    int handle;               /* handle-table handle for this instance */
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
