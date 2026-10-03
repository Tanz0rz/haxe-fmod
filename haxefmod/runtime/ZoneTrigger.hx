package haxefmod.runtime;

import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;

/**
    Engine-free half of a parameter trigger. While the provider's position
    is inside the rectangle the parameter reads valueInside. Otherwise it
    reads valueOutside. The value is applied on the first update, and
    then only when the position crosses the zone edge. Manual parameter
    changes in between are left alone.

    With an event instance the parameter is set on that instance. Without
    one, the trigger drives a global parameter through
    StudioSystem.setParameter. The parameter must be marked global in
    FMOD Studio.
*/
class ZoneTrigger {
    /** Left edge of the zone. */
    public var zoneX:Float;

    /** Top edge of the zone. */
    public var zoneY:Float;

    /** Width of the zone. */
    public var zoneWidth:Float;

    /** Height of the zone. */
    public var zoneHeight:Float;

    var provider:IFmodPositionProvider;
    var parameterName:String;
    var valueInside:Float;
    var valueOutside:Float;
    var instance:EventInstance;
    var wasInside:Null<Bool> = null;

    /** Creates the trigger. Omit instance to drive a global parameter. */
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

    /** Tests the position and applies the parameter on an edge crossing. Call it once per frame. */
    public function update():Void {
        // Before init the value is dropped, and the latched state hides the
        // crossing that reports it. HTML5 initializes asynchronously.
        if (!FmodRuntime.isInitialized()) return;
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
