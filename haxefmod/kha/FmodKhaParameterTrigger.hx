package haxefmod.kha;

import haxefmod.kha.FmodKhaEmitter.KhaBody;
import haxefmod.kha.FmodKhaEmitter.KhaBodyPositionProvider;
import haxefmod.kha.FmodKhaUpdater.IKhaTicker;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;

/**
    Drives an FMOD parameter from a zone: while the body's midpoint is
    inside the rectangle the parameter reads valueInside, otherwise
    valueOutside. The value is applied on the first frame and then only
    when the body crosses the zone edge, so manual parameter changes in
    between are not fought over.

    With an event instance the parameter is set on that instance. Without
    one it drives a global parameter via StudioSystem.setParameter (the
    parameter must be marked global in FMOD Studio).

        // Muffle the music while the player is underwater
        new FmodKhaParameterTrigger(player, 0, 200, 640, 100, "Underwater", 1, 0);
**/
class FmodKhaParameterTrigger implements IKhaTicker {
    var trigger:ZoneTrigger;
    var provider:KhaBodyPositionProvider;

    /**
        @param target the body whose midpoint is tested against the zone
        @param zoneX, zoneY, zoneWidth, zoneHeight the rectangle (world coordinates)
        @param parameterName the FMOD parameter to set
        @param valueInside value applied when the body enters the zone
        @param valueOutside value applied when the body leaves the zone
        @param instance optional event instance to drive. Omit to drive a
        global parameter
    **/
    public function new(target:KhaBody, zoneX:Float, zoneY:Float, zoneWidth:Float, zoneHeight:Float,
            parameterName:String, valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        provider = new KhaBodyPositionProvider(target);
        trigger = new ZoneTrigger(provider, zoneX, zoneY, zoneWidth, zoneHeight,
            parameterName, valueInside, valueOutside, instance);
        FmodKhaUpdater.add(this);
    }

    public function tick(dt:Float):Void {
        provider.sample(dt);
        trigger.update();
    }

    public function dispose():Void {
        FmodKhaUpdater.remove(this);
    }
}
