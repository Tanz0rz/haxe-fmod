# welcome-whats-new-201

## Thread attributes
verdict: bound
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({threadAttributes: [
    {type: FmodThreadType.STREAM, stackSize: 128 * 1024},
    {type: FmodThreadType.NONBLOCKING, stackSize: 128 * 1024},
    {type: FmodThreadType.MIXER, stackSize: 128 * 1024},
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

