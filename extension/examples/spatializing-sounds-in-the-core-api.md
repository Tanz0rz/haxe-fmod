# spatializing-sounds-in-the-core-api

## 0
<!-- 5.0.2 Loading Sounds as 3D -->
CoreSound.create takes no mode flags. Switch the sound to 3D with setMode after loading, or call setMode on the channel that plays it.
```haxe
import haxefmod.studio.CoreSound;
import haxefmod.core.ChannelMode;

var sound = CoreSound.create("assets/drumloop.wav");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
var result = sound.setMode(ChannelMode.MODE_3D);
if (!result.isOk()) {
    trace('setMode failed: $result');
}
```

## 1
<!-- 5.1 Controlling a Spatializer DSP -->
Spatializer parameters of the FMOD_DSP_PARAMETER_3DATTRIBUTES kind are not settable from Haxe. Give the channel its world-space position with Channel.set3DAttributes and let FMOD compute the listener-relative part itself.
```haxe
import haxefmod.studio.CoreSound;
import haxefmod.core.ChannelMode;

var sound = CoreSound.create("assets/drumloop.wav");
sound.setMode(ChannelMode.MODE_3D);
var channel = sound.play();
channel.set3DAttributes(carX, carY, 0, 0, 0, 0);
```

## 2
<!-- 5.1 Controlling a Spatializer DSP -->
The library calls System::update once per frame on its own. The game loop only moves the sources and the listener.
```haxe
import haxefmod.studio.Types;

function updateGame():Void {
    // move sources here with channel.set3DAttributes
    channel.set3DAttributes(carX, carY, 0);

    // update 'ears'
    StudioSystem.setListenerAttributes(0, {
        position: {x: cameraX, y: cameraY, z: 0},
        velocity: {x: 0, y: 0, z: 0},
        forward: {x: 0, y: 0, z: 1},
        up: {x: 0, y: 1, z: 0}
    });
}
```

## 3
<!-- 5.1.1 Velocity -->
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

## 4
<!-- 5.1.1 Velocity -->
```haxe
var vel = 0.1 * 1000 / 16.67; // 6 meters per second
```

## 5
<!-- 5.1.1 Velocity -->
```haxe
var vel = 0.2 * 1000 / 33.33; // 6 meters per second
```
