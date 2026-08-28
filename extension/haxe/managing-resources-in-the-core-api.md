# managing-resources-in-the-core-api

## 9.5.1 Use a Fixed-size Memory Pool.
verdict: bound
Memory_Initialize is not exposed. The library owns system creation and FMOD allocates from the process heap. StudioSystem.getMemoryUsage reports what the engine holds on native targets.
```haxe
var usage = StudioSystem.getMemoryUsage();
if (usage != null) {
    trace('FMOD memory: $usage');
}
```
