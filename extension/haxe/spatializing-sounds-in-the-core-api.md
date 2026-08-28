# spatializing-sounds-in-the-core-api

## 5.0.2 Loading Sounds as 3D
verdict: bound
The mode argument of Sound.create takes the 3D flag at load time.
Sound.create returns Sound.NULL on failure and StudioSystem.lastResult() holds the FMOD_RESULT.
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
The relative attributes are the emitter transformed into the listener's space, the absolute attributes are the emitter itself. Dsp.setParameter3DAttributesMulti packs both into the pan unit's 3D position parameter.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspPan;
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

function updatePanner(panner:Dsp, listener:Fmod3DAttributes, emitter:Fmod3DAttributes):Void {
    var attributes = calculatePannerAttributes(listener, emitter);
    panner.setParameter3DAttributesMulti(DspPan._3D_POSITION, attributes.absolute, [attributes.relative]);
}
```

## 5.1 Controlling a Spatializer DSP#2
verdict: bound
The library calls System::update once per frame on its own, so the loop does not call it.
The listener is set through the Studio system, which drives the Core listener.
```haxe
import haxefmod.studio.Types;

var listenerPos:FmodVector = {x: cameraX, y: cameraY, z: 0};
var listenerVel:FmodVector = {x: 0, y: 0, z: 0};
var listenerForward:FmodVector = {x: 0, y: 0, z: 1};
var listenerUp:FmodVector = {x: 0, y: 1, z: 0};
var gameRunning = true;
function updateGame():Void {
    channel.set3DAttributes(carX, carY, 0);
}

do
{
    updateGame();       // here the game is updated and the sources would be moved with channel.set3DAttributes.

    StudioSystem.setListenerAttributes(0, {
        position: listenerPos,
        velocity: listenerVel,
        forward: listenerForward,
        up: listenerUp
    });     // update 'ears'

} while (gameRunning);
```

## 5.1.1 Velocity
verdict: bound
```haxe
var posX = carX;
var posY = carY;
var posZ = 0.0;
var lastPosX = 0.0;
var lastPosY = 0.0;
var lastPosZ = 0.0;
var timeDelta = 16.67; // milliseconds since the last frame

var velX = (posX - lastPosX) * 1000 / timeDelta;
var velY = (posY - lastPosY) * 1000 / timeDelta;
var velZ = (posZ - lastPosZ) * 1000 / timeDelta;
channel.set3DAttributes(posX, posY, posZ, velX, velY, velZ);
```

## 5.1.1 Velocity#2
verdict: bound
```haxe
var vel = 0.1 * 1000 / 16.67; // 6 meters per second
```

## 5.1.1 Velocity#3
verdict: bound
```haxe
var vel = 0.2 * 1000 / 33.33; // 6 meters per second
```
