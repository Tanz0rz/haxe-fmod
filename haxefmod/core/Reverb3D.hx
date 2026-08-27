package haxefmod.core;

import haxefmod.core.Reverb;
import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A positional reverb zone: a sphere in 3D space whose reverb properties
 * apply based on the listener's position. Inside minDistance the zone is
 * at full strength, fading out to maxDistance. FMOD blends overlapping
 * zones automatically, so rooms can each get their own environment.
 *
 * Zones use the same properties and presets as the global Reverb.
 */
abstract Reverb3D(Int) from Int to Int {
    public static inline var NULL:Reverb3D = cast 0;

    /** Creates a zone. Returns Reverb3D.NULL on failure. */
    public static inline function create():Reverb3D {
        return NativeStudio.sys_create_reverb3d();
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Places the zone: full strength inside minDistance, silent past maxDistance. */
    public inline function set3DAttributes(x:Float, y:Float, z:Float,
            minDistance:Float, maxDistance:Float):FmodResult {
        return NativeStudio.r3d_set_3d_attributes(this, x, y, z, minDistance, maxDistance);
    }

    public function setProperties(properties:ReverbProperties):FmodResult {
        Scratch.writeF(0, properties.decayTime);
        Scratch.writeF(1, properties.earlyDelay);
        Scratch.writeF(2, properties.lateDelay);
        Scratch.writeF(3, properties.hfReference);
        Scratch.writeF(4, properties.hfDecayRatio);
        Scratch.writeF(5, properties.diffusion);
        Scratch.writeF(6, properties.density);
        Scratch.writeF(7, properties.lowShelfFrequency);
        Scratch.writeF(8, properties.lowShelfGain);
        Scratch.writeF(9, properties.highCut);
        Scratch.writeF(10, properties.earlyLateMix);
        Scratch.writeF(11, properties.wetLevel);
        return NativeStudio.r3d_set_properties(this);
    }

    public function getProperties():Null<ReverbProperties> {
        var result:FmodResult = NativeStudio.r3d_get_properties(this);
        if (!result.isOk()) return null;
        return {
            decayTime: Scratch.readF(0),
            earlyDelay: Scratch.readF(1),
            lateDelay: Scratch.readF(2),
            hfReference: Scratch.readF(3),
            hfDecayRatio: Scratch.readF(4),
            diffusion: Scratch.readF(5),
            density: Scratch.readF(6),
            lowShelfFrequency: Scratch.readF(7),
            lowShelfGain: Scratch.readF(8),
            highCut: Scratch.readF(9),
            earlyLateMix: Scratch.readF(10),
            wetLevel: Scratch.readF(11),
        };
    }

    public inline function setActive(active:Bool):FmodResult {
        return NativeStudio.r3d_set_active(this, active);
    }

    public inline function getActive():Bool {
        return NativeStudio.r3d_get_active(this);
    }

    public function get3DAttributes():Null<{x:Float, y:Float, z:Float, minDistance:Float, maxDistance:Float}> {
        var result:FmodResult = NativeStudio.r3d_get_3d_attributes(this);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2),
            minDistance: Scratch.readF(3), maxDistance: Scratch.readF(4)};
    }

    /** Frees the zone and invalidates this handle. */
    public inline function release():FmodResult {
        return NativeStudio.r3d_release(this);
    }
}
