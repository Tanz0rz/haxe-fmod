# managing-resources-in-the-core-api

## 9.5.1 Use a Fixed-size Memory Pool.
verdict: library Memory_Initialize must run before System_Create, which the library performs itself, so FMOD allocates from the process heap. StudioSystem.getMemoryStats and StudioSystem.getMemoryUsage report what it holds
