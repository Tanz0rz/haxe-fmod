package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.math.FlxRect;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;

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
    var target:FlxObject;
    var zone:FlxRect;
    var parameterName:String;
    var valueInside:Float;
    var valueOutside:Float;
    var instance:EventInstance;
    var wasInside:Null<Bool> = null;

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
        this.target = target;
        this.zone = zone;
        this.parameterName = parameterName;
        this.valueInside = valueInside;
        this.valueOutside = valueOutside;
        this.instance = instance == null ? EventInstance.NULL : instance;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var midX = target.x + target.width / 2;
        var midY = target.y + target.height / 2;
        var inside = midX >= zone.x && midX <= zone.x + zone.width
            && midY >= zone.y && midY <= zone.y + zone.height;
        if (wasInside == null || inside != wasInside) {
            wasInside = inside;
            apply(inside ? valueInside : valueOutside);
        }
    }

    function apply(value:Float):Void {
        if (!instance.isNull()) {
            instance.setParameter(parameterName, value);
        } else {
            StudioSystem.setParameter(parameterName, value);
        }
    }
}
