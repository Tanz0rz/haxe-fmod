# running-the-core-api

## 3.1 Initializing the Core API
verdict: bound
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

