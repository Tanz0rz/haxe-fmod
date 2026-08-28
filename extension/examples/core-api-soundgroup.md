# core-api-soundgroup

## 0
<!-- FMOD_SOUNDGROUP_BEHAVIOR -->
The behaviors are constants on SoundGroup.
```haxe
import haxefmod.core.SoundGroup;

var footsteps = SoundGroup.create("footsteps");
footsteps.setMaxAudible(3);
footsteps.setMaxAudibleBehavior(SoundGroup.BEHAVIOR_STEAL_LOWEST);
```
