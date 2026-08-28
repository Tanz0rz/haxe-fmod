# welcome-whats-new-201

## Thread attributes
verdict: bound
One threadAttributes entry per thread, applied before the system is created. An unset priority or affinity keeps FMOD's default. Native only, the web build has no threads to place.
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
The affinity is a 32-bit core mask. Native only, the web build has no threads to place.
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({threadAttributes: [
    {type: FmodThreadType.MIXER, affinity: FmodThreadAffinity.CORE_5},
    {type: FmodThreadType.STREAM, affinity: FmodThreadAffinity.CORE_3},
]});
```
