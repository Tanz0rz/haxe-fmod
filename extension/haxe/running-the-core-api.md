# running-the-core-api

## 3.1 Initializing the Core API
verdict: bound
The library always creates the Studio system, and CoreSystem is the Core system underneath it. FmodManager.Initialize creates and initializes both in one call and StudioSystem.lastResult holds the result.
There is no release call, FMOD lives until the process exits. On HTML5 initialization finishes in the background and FmodManager.IsInitialized reports when it is done.
```haxe
import haxefmod.studio.FmodResult;

var result:FmodResult;

FmodManager.Initialize({numChannels: 512}); // Create the main system object and initialize FMOD.
result = StudioSystem.lastResult();
if (result != FmodResult.FMOD_OK)
{
    trace('FMOD error! (${(result : Int)}) $result');
}
```
