/*
 * Unit tests for native/shared/faxe_guid.h (GUID string formatting and
 * strict parsing shared by the C++ and HashLink shims).
 *
 * Compiled and run in CI in both C99 and C++ modes:
 *   gcc -std=c99 -Wall -Wextra -Werror -o t_c   tests/native/test_faxe_guid.c && ./t_c
 *   g++ -x c++   -Wall -Wextra -Werror -o t_cpp tests/native/test_faxe_guid.c && ./t_cpp
 *
 * The unit-test job has no FMOD SDK, so FMOD_GUID is declared locally under
 * fmod_common.h's include guard. The layout matches the header exactly.
 */
#include <stdio.h>
#include <assert.h>
#include <string.h>

#define _FMOD_COMMON_H
typedef struct {
    unsigned int Data1;
    unsigned short Data2;
    unsigned short Data3;
    unsigned char Data4[8];
} FMOD_GUID;

#include "../../native/shared/faxe_guid.h"

int main(void) {
    FMOD_GUID id;
    char out[64];

    /* round trip: format then parse yields the same fields */
    memset(&id, 0, sizeof(id));
    id.Data1 = 0x1f687138u;
    id.Data2 = 0xe06c;
    id.Data3 = 0x40f5;
    for (int i = 0; i < 8; i++) id.Data4[i] = (unsigned char)(0x9b + i);
    faxe_guid_format(&id, out, sizeof(out));
    assert(strcmp(out, "{1f687138-e06c-40f5-9b9c-9d9e9fa0a1a2}") == 0);
    {
        FMOD_GUID parsed;
        memset(&parsed, 0, sizeof(parsed));
        assert(faxe_guid_parse(out, &parsed) == 1);
        assert(memcmp(&parsed, &id, sizeof(id)) == 0);
    }

    /* braces are optional, uppercase hex accepted */
    {
        FMOD_GUID parsed;
        assert(faxe_guid_parse("1F687138-E06C-40F5-9B9C-9D9E9FA0A1A2", &parsed) == 1);
        assert(parsed.Data1 == 0x1f687138u);
        assert(parsed.Data4[7] == 0xa2);
    }

    /* surrounding whitespace is tolerated (matching the html5 shim's trim,
     * and GUIDs read from files often keep a trailing newline) */
    {
        FMOD_GUID parsed;
        assert(faxe_guid_parse("  {1f687138-e06c-40f5-9b9c-9d9e9fa0a1a2}\n", &parsed) == 1);
        assert(parsed.Data1 == 0x1f687138u);
        assert(faxe_guid_parse("1f687138-e06c-40f5-9b9c-9d9e9fa0a1a2\r\n", &parsed) == 1);
    }

    /* malformed GUIDs are rejected instead of zero-padding wrong values */
    {
        FMOD_GUID parsed;
        /* short groups (sscanf alone would accept these) */
        assert(faxe_guid_parse("{12-34-56-7890-AABBCCDDEEFF}", &parsed) == 0);
        assert(faxe_guid_parse("1f68713-e06c-40f5-9b9c-9d9e9fa0a1a2", &parsed) == 0);
        /* trailing garbage */
        assert(faxe_guid_parse("{1f687138-e06c-40f5-9b9c-9d9e9fa0a1a2}x", &parsed) == 0);
        assert(faxe_guid_parse("1f687138-e06c-40f5-9b9c-9d9e9fa0a1a2extra", &parsed) == 0);
        /* wrong separators and non-hex */
        assert(faxe_guid_parse("1f687138_e06c_40f5_9b9c_9d9e9fa0a1a2", &parsed) == 0);
        assert(faxe_guid_parse("{1f687138-e06c-40f5-9b9c-9d9e9fa0a1gg}", &parsed) == 0);
        /* unbalanced brace */
        assert(faxe_guid_parse("{1f687138-e06c-40f5-9b9c-9d9e9fa0a1a2", &parsed) == 0);
        /* empty and null-ish input */
        assert(faxe_guid_parse("", &parsed) == 0);
        assert(faxe_guid_parse("bad", &parsed) == 0);
        assert(faxe_guid_parse(NULL, &parsed) == 0);
    }

    printf("faxe_guid: all assertions passed\n");
    return 0;
}
