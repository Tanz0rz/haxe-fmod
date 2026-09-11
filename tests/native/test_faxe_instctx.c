/*
 * Unit tests for native/shared/faxe_instctx.h, the per-instance context
 * the C++ and HashLink shims keep in FMOD userdata. The programmer sound
 * fields are the logic worth pinning. They are the name-to-key table and
 * the armed check the callback mask is built from. The pending check holds
 * the destroy bit on a shim-created sound, and the clear drops every
 * assignment at once.
 *
 * CI compiles and runs the file in both C99 and C++ modes. The build
 * lines:
 *   gcc -std=c99 -Wall -Wextra -Werror -o test_c   tests/native/test_faxe_instctx.c && ./test_c
 *   g++ -x c++   -Wall -Wextra -Werror -o test_cpp tests/native/test_faxe_instctx.c && ./test_cpp
 */
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "../../native/shared/faxe_instctx.h"

static void fill(char* out, int len, char c) {
    memset(out, c, (size_t)len);
    out[len] = '\0';
}

int main(void) {
    FaxeInstCtx* ctx = faxe_instctx_create(7);
    char key[FAXE_PS_KEY_MAX];
    char longName[FAXE_PS_NAME_MAX + 1];
    char longKey[FAXE_PS_KEY_MAX + 1];
    char name[16];
    int i;
    assert(ctx != NULL);
    assert(ctx->handle == 7);
    assert(ctx->psGameSubsound == -1);
    assert(ctx->psNamed == NULL && ctx->psNamedCount == 0);
    assert(!faxe_instctx_ps_armed(ctx));

    /* a key alone arms the callback */
    strcpy(ctx->psKey, "hello");
    assert(faxe_instctx_ps_armed(ctx));
    faxe_instctx_ps_clear(ctx);
    assert(!faxe_instctx_ps_armed(ctx) && ctx->psKey[0] == '\0');

    /* a game sound alone arms it too */
    ctx->psGameSound = (void*)ctx;
    ctx->psGameSubsound = 2;
    assert(faxe_instctx_ps_armed(ctx));
    faxe_instctx_ps_clear(ctx);
    assert(ctx->psGameSound == NULL && ctx->psGameSubsound == -1);

    /* a sound the shim created outlives the clear, so the installed mask
     * keeps its destroy bit and the release still runs */
    assert(!faxe_instctx_ps_sound_pending(ctx));
    assert(faxe_instctx_ps_sound_add(ctx, (void*)ctx));
    strcpy(ctx->psKey, "hello");
    assert(faxe_instctx_ps_armed(ctx) && faxe_instctx_ps_sound_pending(ctx));
    faxe_instctx_ps_clear(ctx);
    assert(!faxe_instctx_ps_armed(ctx));
    assert(faxe_instctx_ps_sound_pending(ctx) && ctx->psSounds[0] == (void*)ctx);
    /* two instruments live at once keep separate slots, and a take only
     * forgets its own sound */
    {
        static int second;
        int i;
        assert(faxe_instctx_ps_sound_add(ctx, (void*)&second));
        assert(faxe_instctx_ps_take_count(ctx) == 2);
        assert(!faxe_instctx_ps_sound_take(ctx, (void*)&i));
        assert(faxe_instctx_ps_sound_take(ctx, (void*)ctx));
        assert(faxe_instctx_ps_sound_pending(ctx) && ctx->psSounds[1] == (void*)&second);
        assert(faxe_instctx_ps_sound_take(ctx, (void*)&second));
        assert(!faxe_instctx_ps_sound_take(ctx, (void*)&second));
        /* every slot taken: the add reports it */
        for (i = 0; i < FAXE_PS_NAMED_MAX; i++) assert(faxe_instctx_ps_sound_add(ctx, (void*)(&second + 1 + i)));
        assert(!faxe_instctx_ps_sound_add(ctx, (void*)ctx));
        for (i = 0; i < FAXE_PS_NAMED_MAX; i++) assert(faxe_instctx_ps_sound_take(ctx, (void*)(&second + 1 + i)));
    }
    assert(!faxe_instctx_ps_sound_pending(ctx));

    /* the create drain records a handle on the sound's slot, and the take
     * hands it back once, so the destroy record carries a handle rather
     * than an address a later sound can reuse */
    {
        static int sound;
        int handle = -1;
        assert(faxe_instctx_ps_sound_add(ctx, (void*)&sound));
        assert(faxe_instctx_ps_sound_take_handle(ctx, (void*)&ctx, &handle) == 0 && handle == 0);
        assert(faxe_instctx_ps_sound_set_handle(ctx, (void*)&sound, 0x10007) == 1);
        assert(faxe_instctx_ps_sound_set_handle(ctx, (void*)&ctx, 5) == 0);
        assert(faxe_instctx_ps_sound_take_handle(ctx, (void*)&sound, &handle) == 1 && handle == 0x10007);
        assert(faxe_instctx_ps_sound_take_handle(ctx, (void*)&sound, &handle) == 0 && handle == 0);
        assert(!faxe_instctx_ps_sound_pending(ctx));
    }

    /* the plugin table works the same way and fills up */
    {
        static int dsps[FAXE_PLUGIN_MAX + 1];
        int i, handle = -1;
        for (i = 0; i < FAXE_PLUGIN_MAX; i++) assert(faxe_instctx_plugin_add(ctx, (void*)&dsps[i]));
        assert(!faxe_instctx_plugin_add(ctx, (void*)&dsps[FAXE_PLUGIN_MAX]));
        assert(faxe_instctx_plugin_set_handle(ctx, (void*)&dsps[3], 0x20003) == 1);
        assert(faxe_instctx_plugin_set_handle(ctx, (void*)&dsps[FAXE_PLUGIN_MAX], 9) == 0);
        assert(faxe_instctx_plugin_take(ctx, (void*)&dsps[3], &handle) == 1 && handle == 0x20003);
        assert(faxe_instctx_plugin_take(ctx, (void*)&dsps[3], &handle) == 0 && handle == 0);
        for (i = 0; i < FAXE_PLUGIN_MAX; i++) if (i != 3) assert(faxe_instctx_plugin_take(ctx, (void*)&dsps[i], NULL) == 1);
    }

    /* the name table allocates on first use, replaces by name, and fills up */
    assert(faxe_instctx_ps_set_named(ctx, "Line", "hello") == 1);
    assert(ctx->psNamed != NULL && ctx->psNamedCount == 1);
    assert(faxe_instctx_ps_armed(ctx));
    assert(faxe_instctx_ps_set_named(ctx, "Line", "goodbye") == 1);
    assert(ctx->psNamedCount == 1);
    strcpy(key, "untouched");
    assert(faxe_instctx_ps_find_named(ctx, "Line", key) == 1);
    assert(strcmp(key, "goodbye") == 0);
    strcpy(key, "untouched");
    assert(faxe_instctx_ps_find_named(ctx, "Other", key) == 0);
    assert(strcmp(key, "untouched") == 0);
    assert(faxe_instctx_ps_find_named(ctx, NULL, key) == 0);
    for (i = 1; i < FAXE_PS_NAMED_MAX; i++) {
        snprintf(name, sizeof name, "n%d", i);
        assert(faxe_instctx_ps_set_named(ctx, name, "k") == 1);
    }
    assert(ctx->psNamedCount == FAXE_PS_NAMED_MAX);
    assert(faxe_instctx_ps_set_named(ctx, "overflow", "k") == 0);
    assert(faxe_instctx_ps_set_named(ctx, "n3", "replaced") == 1);
    assert(faxe_instctx_ps_find_named(ctx, "n3", key) == 1 && strcmp(key, "replaced") == 0);

    /* oversized name or key, or a missing one, is refused before storage */
    fill(longName, FAXE_PS_NAME_MAX, 'a');
    fill(longKey, FAXE_PS_KEY_MAX, 'b');
    assert(faxe_instctx_ps_set_named(ctx, longName, "k") == -1);
    assert(faxe_instctx_ps_set_named(ctx, "short", longKey) == -1);
    assert(faxe_instctx_ps_set_named(ctx, NULL, "k") == -1);
    assert(faxe_instctx_ps_set_named(ctx, "short", NULL) == -1);
    longName[FAXE_PS_NAME_MAX - 1] = '\0';
    longKey[FAXE_PS_KEY_MAX - 1] = '\0';
    faxe_instctx_ps_clear(ctx);
    assert(faxe_instctx_ps_set_named(ctx, longName, longKey) == 1);
    assert(faxe_instctx_ps_find_named(ctx, longName, key) == 1 && strcmp(key, longKey) == 0);

    /* clear empties the table but keeps the allocation for reuse */
    faxe_instctx_ps_clear(ctx);
    assert(!faxe_instctx_ps_armed(ctx));
    assert(ctx->psNamed != NULL && ctx->psNamedCount == 0);
    assert(faxe_instctx_ps_find_named(ctx, longName, key) == 0);
    assert(faxe_instctx_ps_set_named(ctx, "again", "k") == 1);

    /* a context that never used names has nothing to look up */
    faxe_instctx_destroy(ctx);
    ctx = faxe_instctx_create(8);
    assert(faxe_instctx_ps_find_named(ctx, "Line", key) == 0);
    faxe_instctx_destroy(ctx);
    faxe_instctx_destroy(NULL);

    printf("test_faxe_instctx: all tests passed\n");
    return 0;
}
