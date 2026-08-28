# studio-api-getting-started

## 12.1.1 Studio API Initialization
verdict: bound
FmodManager.Initialize creates the Studio system and initializes it, which also initializes the Core system. StudioSystem.lastResult holds the result.
There is no release call, FMOD lives until the process exits. On HTML5 initialization finishes in the background and FmodManager.IsInitialized reports when it is done.
```haxe
import haxefmod.studio.FmodResult;

var result:FmodResult;

FmodManager.Initialize({numChannels: 512}); // Create and initialize the Studio system, which also initializes the Core system
result = StudioSystem.lastResult();
if (result != FmodResult.FMOD_OK)
{
    trace('FMOD error! (${(result : Int)}) $result');
}
```
