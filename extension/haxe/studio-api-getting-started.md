# studio-api-getting-started

## 12.1.1 Studio API Initialization
verdict: bound
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

