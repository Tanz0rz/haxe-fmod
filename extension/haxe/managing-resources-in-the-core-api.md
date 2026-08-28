# managing-resources-in-the-core-api

## 9.5.1 Use a Fixed-size Memory Pool.
verdict: bound
The memoryPoolSize setting allocates the pool and hands it to FMOD before the system is created. StudioSystem.getMemoryStats reports how much of it is in use. Native only, the web build allocates from the wasm heap.
```haxe
FmodManager.Initialize({memoryPoolSize: 4 * 1024 * 1024}); // allocate 4mb and pass it to the FMOD Engine to use.
```
