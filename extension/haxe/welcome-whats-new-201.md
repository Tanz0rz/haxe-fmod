# welcome-whats-new-201

## Thread attributes
verdict: bound
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({threadAttributes: [
    {type: FmodThreadType.STREAM, stackSize: stackSizeStream},
    {type: FmodThreadType.NONBLOCKING, stackSize: stackSizeNonBlocking},
    {type: FmodThreadType.MIXER, stackSize: stackSizeMixer},
]});
```

## Thread attributes#2
verdict: bound
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({threadAttributes: [
    {type: FmodThreadType.MIXER, affinity: FmodThreadAffinity.CORE_5},
    {type: FmodThreadType.STREAM, affinity: FmodThreadAffinity.CORE_3},
]});
```

