# running-the-core-api

## 3.1 Initializing the Core API
verdict: bound
The library creates and initializes the system in one call. Init-time settings such as the voice count come from FmodSettings, and there is no shutdown call. FMOD lives until the process exits.
```haxe
FmodManager.Initialize({numChannels: 512});
if (!FmodManager.IsInitialized()) {
    trace('FMOD error! ${StudioSystem.lastResult()}');
}
```
