package haxefmod.kha;

import haxefmod.kha.FmodKhaEmitter.KhaBody;
import haxefmod.kha.FmodKhaEmitter.KhaBodyPositionProvider;
import haxefmod.kha.FmodKhaUpdater.IKhaTicker;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;

/**
    Drives an FMOD parameter from a zone. While the body's midpoint is
    inside the rectangle the parameter reads valueInside. Otherwise it
    reads valueOutside. The value is applied on the first frame, and
    then only when the body crosses the zone edge. Manual parameter
    changes in between are left alone.

    With an event instance the parameter is set on that instance. Without
    one, the trigger drives a global parameter through
    StudioSystem.setParameter. The parameter must be marked global in
    FMOD Studio.

        // Muffle the music while the player is underwater
        new FmodKhaParameterTrigger(player, 0, 200, 640, 100, "Underwater", 1, 0);
**/
class FmodKhaParameterTrigger implements IKhaTicker {
    var trigger:ZoneTrigger;
    var provider:KhaBodyPositionProvider;

    /**
        Kha has no rectangle type, so the zone is four numbers in world
        coordinates.
        @param target The body whose midpoint is tested against the zone.
        @param zoneX The left edge of the rectangle.
        @param zoneY The top edge of the rectangle.
        @param zoneWidth The width of the rectangle.
        @param zoneHeight The height of the rectangle.
        @param parameterName The FMOD parameter to set.
        @param valueInside The value applied when the body enters the zone.
        @param valueOutside The value applied when the body leaves the zone.
        @param instance An optional event instance to drive. Omit to drive a
        global parameter.
    **/
    public function new(target:KhaBody, zoneX:Float, zoneY:Float, zoneWidth:Float, zoneHeight:Float,
            parameterName:String, valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        provider = new KhaBodyPositionProvider(target);
        trigger = new ZoneTrigger(provider, zoneX, zoneY, zoneWidth, zoneHeight,
            parameterName, valueInside, valueOutside, instance);
        FmodKhaUpdater.add(this);
    }

    /** Samples the body and applies the parameter on an edge crossing. **/
    @:dox(hide)
    public function tick(dt:Float):Void {
        provider.sample(dt);
        trigger.update();
    }

    /** Unregisters the trigger from FmodKhaUpdater. **/
    public function dispose():Void {
        FmodKhaUpdater.remove(this);
    }
}
