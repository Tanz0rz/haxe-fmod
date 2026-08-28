# platforms-win

## *
<!-- page default -->
On Windows the library's build integration compiles the binding, links against the FMOD libraries in FMOD_SDK, and copies the DLLs next to the executable after the build. The binding initializes FMOD with the default output type, so there is no ASIO selection, and the port attachment API for background music and pass-through is not exposed. Route music through an ordinary bus or channel group instead.
