package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.math.FlxRect;
import haxefmod.flixel.FmodFlxEmitter.FlxObjectPositionProvider;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;

/**
    Drives an FMOD parameter from a zone: while the target's midpoint is
    inside the rectangle the parameter reads valueInside, otherwise
    valueOutside. The value is applied on the first update and then only
    when the target crosses the zone edge, so manual parameter changes in
    between are not fought over.

    With an event instance the parameter is set on that instance. WITHOUT
    one it drives a GLOBAL parameter via StudioSystem.setParameter (the
    parameter must be marked global in FMOD Studio).

        // Muffle the music while the player is underwater
        add(new FmodFlxParameterTrigger(player, waterZone, "Underwater", 1, 0));
**/
class FmodFlxParameterTrigger extends FlxBasic {
    var trigger:ZoneTrigger;

    /**
        @param target the object whose midpoint is tested against the zone
        @param zone the rectangle (world coordinates)
        @param parameterName the FMOD parameter to set
        @param valueInside value applied when the target enters the zone
        @param valueOutside value applied when the target leaves the zone
        @param instance optional event instance to drive. Omit to drive a
        global parameter
    **/
    public function new(target:FlxObject, zone:FlxRect, parameterName:String,
            valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        super();
        trigger = new ZoneTrigger(new FlxObjectPositionProvider(target), zone.x, zone.y, zone.width, zone.height,
            parameterName, valueInside, valueOutside, instance);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        trigger.update();
    }
}
