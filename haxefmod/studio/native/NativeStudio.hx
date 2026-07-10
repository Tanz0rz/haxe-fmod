package haxefmod.studio.native;

/**
 * Compile-time backend selection for the FMOD Studio bindings.
 *
 * Each backend exposes the exact same static API (names and Haxe-level
 * types match native/manifest/studio_api.txt). string and buffer
 * conversions are handled inside the per-target wrapper, so callers like
 * Bus.hx are fully target-agnostic.
 */
#if cpp
typedef NativeStudio = haxefmod.studio.native.NativeStudioCpp;
#elseif hl
typedef NativeStudio = haxefmod.studio.native.NativeStudioHl;
#elseif js
typedef NativeStudio = haxefmod.studio.native.NativeStudioJs;
#else
typedef NativeStudio = haxefmod.studio.native.NativeStudioStub;
#end
