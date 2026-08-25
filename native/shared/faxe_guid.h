/**
 * GUID string helpers shared by the haxefmod native shims.
 *
 * GUIDs cross the FFI boundary as formatted strings "{8-4-4-4-12}", e.g.
 * "{1f687138-e06c-40f5-9bac-57f84bbcedd3}". Used by linc_faxe.cpp (C++) and
 * hlaxe_fmod.c (C99). jaxe.js mirrors the same logic in JavaScript.
 *
 * The MIT License (MIT)
 * Copyright (c) 2020 Tanner Moore
 */
#ifndef FAXE_GUID_H
#define FAXE_GUID_H

#include <stdio.h>
/* Both shims include the FMOD headers before this one. The conditional
 * allows the unit test to define its own FMOD_GUID when no FMOD SDK is
 * installed. */
#ifndef _FMOD_COMMON_H
#include "fmod_common.h"
#endif

/* Formats a GUID into out (must hold at least 40 bytes). */
static void faxe_guid_format(const FMOD_GUID* id, char* out, size_t outSize) {
    snprintf(out, outSize,
        "{%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x}",
        (unsigned int)id->Data1, (unsigned int)id->Data2, (unsigned int)id->Data3,
        id->Data4[0], id->Data4[1], id->Data4[2], id->Data4[3],
        id->Data4[4], id->Data4[5], id->Data4[6], id->Data4[7]);
}

static int faxe_guid_is_hex(char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

/* Parses "{8-4-4-4-12}" (braces optional) into id. Returns 1 on success.
 * Group widths are enforced exactly and no trailing text is accepted, so a
 * malformed GUID fails here instead of resolving a zero-padded wrong GUID
 * (sscanf alone accepts short groups and ignores trailing garbage). */
static int faxe_guid_parse(const char* text, FMOD_GUID* id) {
    static const int groups[5] = { 8, 4, 4, 4, 12 };
    unsigned int d1;
    unsigned int d2;
    unsigned int d3;
    unsigned int b[8];
    int matched;
    int braced;
    int g;
    int i;
    const char* p;

    if (!text || !id) return 0;
    braced = text[0] == '{';
    if (braced) text++;

    p = text;
    for (g = 0; g < 5; g++) {
        for (i = 0; i < groups[g]; i++) {
            if (!faxe_guid_is_hex(*p)) return 0;
            p++;
        }
        if (g < 4) {
            if (*p != '-') return 0;
            p++;
        }
    }
    if (braced) {
        if (*p != '}') return 0;
        p++;
    }
    if (*p != '\0') return 0;

    matched = sscanf(text, "%8x-%4x-%4x-%2x%2x-%2x%2x%2x%2x%2x%2x",
        &d1, &d2, &d3,
        &b[0], &b[1], &b[2], &b[3], &b[4], &b[5], &b[6], &b[7]);
    if (matched != 11) return 0;

    id->Data1 = d1;
    id->Data2 = (unsigned short)d2;
    id->Data3 = (unsigned short)d3;
    for (i = 0; i < 8; i++) {
        id->Data4[i] = (unsigned char)b[i];
    }
    return 1;
}

#endif /* FAXE_GUID_H */
