package haxefmod.heaps;

import h2d.Object;
import h2d.col.Bounds;
import haxefmod.heaps.FmodHeapsEmitter.H2dObjectPositionProvider;
import haxefmod.heaps.FmodHeapsUpdater.IHeapsTicker;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;

/**
    Drives an FMOD parameter from a zone: while the center of the target's
    bounds is inside the rectangle the parameter reads valueInside,
    otherwise valueOutside. The value is applied on the first frame and
    then only when the target crosses the zone edge, so manual parameter
    changes in between are not fought over.

    With an event instance the parameter is set on that instance. Without
    one it drives a global parameter via StudioSystem.setParameter (the
    parameter must be marked global in FMOD Studio).

        // Muffle the music while the player is underwater
        new FmodHeapsParameterTrigger(player, waterZone, "Underwater", 1, 0);
**/
class FmodHeapsParameterTrigger implements IHeapsTicker {
    var trigger:ZoneTrigger;
    var provider:H2dObjectPositionProvider;

    /**
        @param target the object whose center is tested against the zone
        @param zone the rectangle (scene coordinates)
        @param parameterName the FMOD parameter to set
        @param valueInside value applied when the target enters the zone
        @param valueOutside value applied when the target leaves the zone
        @param instance optional event instance to drive. Omit to drive a
        global parameter
    **/
    public function new(target:Object, zone:Bounds, parameterName:String,
            valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        provider = new H2dObjectPositionProvider(target);
        trigger = new ZoneTrigger(provider, zone.xMin, zone.yMin, zone.width, zone.height,
            parameterName, valueInside, valueOutside, instance);
        FmodHeapsUpdater.add(this);
    }

    public function tick(dt:Float):Void {
        provider.sample(dt);
        trigger.update();
    }

    public function dispose():Void {
        FmodHeapsUpdater.remove(this);
    }
}
