# spatializing-sounds-in-the-core-api

## 5.0.2 Loading Sounds as 3D
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;
import haxefmod.studio.FmodResult;

var handleError = (result:FmodResult) -> trace(result);

var sound = Sound.create("../media/drumloop.wav", false, false, ChannelMode.MODE_3D);
if (sound.isNull()) {
    handleError(StudioSystem.lastResult());
}
```

## 5.1 Controlling a Spatializer DSP
verdict: bound
```haxe
import haxefmod.studio.Types;

function dot(a:FmodVector, b:FmodVector):Float {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

function cross(a:FmodVector, b:FmodVector):FmodVector {
    return {x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x};
}

function toListenerSpace(v:FmodVector, listener:Fmod3DAttributes):FmodVector {
    var right = cross(listener.up, listener.forward);
    return {x: dot(v, right), y: dot(v, listener.up), z: dot(v, listener.forward)};
}

function calculatePannerAttributes(listener:Fmod3DAttributes, emitter:Fmod3DAttributes):FmodDspParameter3DAttributes {
    var offset = {x: emitter.position.x - listener.position.x, y: emitter.position.y - listener.position.y, z: emitter.position.z - listener.position.z};
    var motion = {x: emitter.velocity.x - listener.velocity.x, y: emitter.velocity.y - listener.velocity.y, z: emitter.velocity.z - listener.velocity.z};
    return {
        relative: {
            position: toListenerSpace(offset, listener),
            velocity: toListenerSpace(motion, listener),
            forward: toListenerSpace(emitter.forward, listener),
            up: toListenerSpace(emitter.up, listener)
        },
        absolute: emitter
    };
}
```

## 5.1 Controlling a Spatializer DSP#2
verdict: bound
waive: extra-calls the core set3DListenerAttributes has no Haxe form, the listener goes through Studio's setListenerAttributes
```haxe
import haxefmod.studio.Types;

do
{
    updateGame();       // here the game is updated and the sources would be moved with channel.set3DAttributes.

    StudioSystem.setListenerAttributes(0, {position: listenerPos, velocity: listenerVel, forward: listenerForward, up: listenerUp});     // update 'ears'

    // the library runs the once-per-frame update itself.

} while (gameRunning);
```

## 5.1.1 Velocity
verdict: bound
```haxe
var velx = (posx - lastposx) * 1000 / timedelta;
var vely = (posy - lastposy) * 1000 / timedelta;
var velz = (posz - lastposz) * 1000 / timedelta;
```

## 5.1.1 Velocity#2
verdict: bound
waive: missing-numbers the snippet's = 6 is the arithmetic result, the fence carries it in the comment
```haxe
var vel = 0.1 * 1000 / 16.67; // 6 meters per second
```

## 5.1.1 Velocity#3
verdict: bound
waive: missing-numbers the snippet's = 6 is the arithmetic result, the fence carries it in the comment
```haxe
var vel = 0.2 * 1000 / 33.33; // 6 meters per second
```
