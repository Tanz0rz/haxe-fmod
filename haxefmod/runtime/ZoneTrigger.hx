package haxefmod.runtime;

import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;

/**
    Engine-free half of a parameter trigger: while the provider's position
    is inside the rectangle the parameter reads valueInside, otherwise
    valueOutside. The value is applied on the first update and then only
    when the position crosses the zone edge, so manual parameter changes
    in between are not fought over.

    With an event instance the parameter is set on that instance. Without
    one it drives a global parameter via StudioSystem.setParameter (the
    parameter must be marked global in FMOD Studio).
**/
class ZoneTrigger {
    public var zoneX:Float;
    public var zoneY:Float;
    public var zoneWidth:Float;
    public var zoneHeight:Float;

    var provider:IFmodPositionProvider;
    var parameterName:String;
    var valueInside:Float;
    var valueOutside:Float;
    var instance:EventInstance;
    var wasInside:Null<Bool> = null;

    public function new(provider:IFmodPositionProvider, zoneX:Float, zoneY:Float, zoneWidth:Float, zoneHeight:Float,
            parameterName:String, valueInside:Float, valueOutside:Float, ?instance:EventInstance) {
        this.provider = provider;
        this.zoneX = zoneX;
        this.zoneY = zoneY;
        this.zoneWidth = zoneWidth;
        this.zoneHeight = zoneHeight;
        this.parameterName = parameterName;
        this.valueInside = valueInside;
        this.valueOutside = valueOutside;
        this.instance = instance == null ? EventInstance.NULL : instance;
    }

    public function update():Void {
        var midX = provider.fmodX();
        var midY = provider.fmodY();
        var inside = midX >= zoneX && midX <= zoneX + zoneWidth
            && midY >= zoneY && midY <= zoneY + zoneHeight;
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
