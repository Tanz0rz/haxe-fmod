package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.math.FlxRect;
import haxefmod.flixel.FmodFlxEmitter.FlxObjectPositionProvider;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;

/**
    Drives an FMOD parameter from a zone. While the target's midpoint is
    inside the rectangle the parameter reads valueInside. Otherwise it
    reads valueOutside. The value is applied on the first update, and
    then only when the target crosses the zone edge. Manual parameter
    changes in between are left alone.

    With an event instance the parameter is set on that instance. Without
    one, the trigger drives a global parameter through
    StudioSystem.setParameter. The parameter must be marked global in
    FMOD Studio.

        // Muffle the music while the player is underwater
        add(new FmodFlxParameterTrigger(player, waterZone, "Underwater", 1, 0));
**/
class FmodFlxParameterTrigger extends FlxBasic {
    var trigger:ZoneTrigger;

    /**
        @param target The object whose midpoint is tested against the zone.
        @param zone The rectangle in world coordinates.
        @param parameterName The FMOD parameter to set.
        @param valueInside The value applied when the target enters the zone.
        @param valueOutside The value applied when the target leaves the zone.
        @param instance An optional event instance to drive. Omit to drive a
        global parameter.
    **/
    public function new(target:FlxObject, zone:FlxRect, parameterName:String,
            valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        super();
        trigger = new ZoneTrigger(new FlxObjectPositionProvider(target), zone.x, zone.y, zone.width, zone.height,
            parameterName, valueInside, valueOutside, instance);
        FmodFlxUpdater.init();
    }

    /** Tests the target against the zone and applies the parameter on an edge crossing. **/
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        trigger.update();
    }
}
