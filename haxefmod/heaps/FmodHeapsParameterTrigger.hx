package haxefmod.heaps;

import h2d.Object;
import h2d.col.Bounds;
import haxefmod.heaps.FmodHeapsEmitter.H2dObjectPositionProvider;
import haxefmod.heaps.FmodHeapsUpdater.IHeapsTicker;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;

/**
    Drives an FMOD parameter from a zone. While the center of the target's
    bounds is inside the rectangle the parameter reads valueInside.
    Otherwise it reads valueOutside. The value is applied on the first
    frame, and then only when the target crosses the zone edge. Manual
    parameter changes in between are left alone.

    With an event instance the parameter is set on that instance. Without
    one, the trigger drives a global parameter through
    StudioSystem.setParameter. The parameter must be marked global in
    FMOD Studio.

        // Muffle the music while the player is underwater
        new FmodHeapsParameterTrigger(player, waterZone, "Underwater", 1, 0);
**/
class FmodHeapsParameterTrigger implements IHeapsTicker {
    var trigger:ZoneTrigger;
    var provider:H2dObjectPositionProvider;

    /**
        @param target The object whose center is tested against the zone.
        @param zone The rectangle in scene coordinates.
        @param parameterName The FMOD parameter to set.
        @param valueInside The value applied when the target enters the zone.
        @param valueOutside The value applied when the target leaves the zone.
        @param instance An optional event instance to drive. Omit to drive a
        global parameter.
    **/
    public function new(target:Object, zone:Bounds, parameterName:String,
            valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        provider = new H2dObjectPositionProvider(target);
        trigger = new ZoneTrigger(provider, zone.xMin, zone.yMin, zone.width, zone.height,
            parameterName, valueInside, valueOutside, instance);
        FmodHeapsUpdater.add(this);
    }

    /** Samples the target and applies the parameter on an edge crossing. **/
    public function tick(dt:Float):Void {
        provider.sample(dt);
        trigger.update();
    }

    /** Unregisters the trigger from FmodHeapsUpdater. **/
    public function dispose():Void {
        FmodHeapsUpdater.remove(this);
    }
}
