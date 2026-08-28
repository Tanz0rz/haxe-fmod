# platforms-mac

## *
<!-- page default -->
On macOS the library's build integration links against the FMOD dylibs in FMOD_SDK and copies them next to the executable after the build. The native output handle is not exposed, so the device buffer size stays at FMOD's default. If macOS blocks the downloaded dylibs, clear the quarantine flag with xattr -dr com.apple.quarantine on the SDK folder.
