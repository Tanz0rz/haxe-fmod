/*
 * Unit tests for native/shared/faxe_instctx.h, the per-instance context
 * the C++ and HashLink shims keep in FMOD userdata. The programmer sound
 * fields are the logic worth pinning: the name-to-key table, the armed
 * check the callback mask is built from, and the clear that drops every
 * assignment at once.
 *
 * Compiled and run in CI in both C99 and C++ modes:
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
        sprintf(name, "n%d", i);
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
