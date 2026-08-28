# studio-api-common

## 1
<!-- FMOD_STUDIO_MEMORY_USAGE -->
Memory usage is native only (unsupported in HTML5), where the getters return null.

## 2
<!-- FMOD_STUDIO_PARAMETER_DESCRIPTION -->
The guid field is always empty, the native side does not read it. Look a parameter up by path with StudioSystem.lookupID when you need its GUID.

## 3
<!-- FMOD_STUDIO_PARAMETER_FLAGS -->
The flags field of a description is an Int, mask it with these bits.
