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
verdict: covered The relative and absolute 3D attributes of a spatializer are not computed in Haxe. A source played through a 3D channel is positioned in world space with Channel.set3DAttributes and FMOD derives the listener-relative attributes from the listener set with StudioSystem.setListenerAttributes. A pan DSP created by hand can only take its 3D attributes as a raw byte payload through Dsp.setParameterData.

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
