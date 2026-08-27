package haxefmod.runtime;

import haxefmod.studio.EventInstance;

/**
 * Tracks event instances attached to moving objects and pushes their 3D
 * attributes to FMOD once per update. Instances that die (released,
 * stopped and destroyed, stale handles) are pruned automatically.
 */
class AttachedInstances {
    var entries:Array<{instance:EventInstance, provider:IFmodPositionProvider, autoRelease:Bool}> = [];

    /**
     * Caps the velocity magnitude pushed to FMOD (game units per second).
     * 0 disables the cap. Set from FmodSettings.maxAttachedVelocity at init.
     */
    public var maxVelocity:Float = 0;

    public function new() {}

    /**
     * Attaches an instance. Replaces the provider if already attached.
     * With autoRelease the instance is released as soon as it reports
     * STOPPED, which is how one-shots clean themselves up without relying
     * on a callback registration that ClearAllCallbacks could remove.
     */
    public function attach(instance:EventInstance, provider:IFmodPositionProvider, autoRelease:Bool = false):Void {
        if (instance.isNull() || provider == null) return;
        for (entry in entries) {
            if ((entry.instance : Int) == (instance : Int)) {
                entry.provider = provider;
                entry.autoRelease = autoRelease;
                return;
            }
        }
        entries.push({instance: instance, provider: provider, autoRelease: autoRelease});
        push(instance, provider);
    }

    public function detach(instance:EventInstance):Void {
        for (entry in entries) {
            if ((entry.instance : Int) == (instance : Int)) {
                entries.remove(entry);
                return;
            }
        }
    }

    public function count():Int {
        return entries.length;
    }

    /** Pushes positions for all live entries and prunes dead ones. */
    public function update():Void {
        var i = entries.length - 1;
        while (i >= 0) {
            var entry = entries[i];
            if (!entry.instance.isValid()) {
                entries.splice(i, 1);
            } else if (entry.autoRelease
                    && entry.instance.getPlaybackState() == haxefmod.studio.Types.FmodPlaybackState.STOPPED) {
                entries.splice(i, 1);
                entry.instance.release();
            } else {
                push(entry.instance, entry.provider);
            }
            i--;
        }
    }

    function push(instance:EventInstance, provider:IFmodPositionProvider):Void {
        var velX = provider.fmodVelocityX();
        var velY = provider.fmodVelocityY();
        var scale = velocityScale(velX, velY, maxVelocity);
        instance.setPosition2D(provider.fmodX(), provider.fmodY(), velX * scale, velY * scale);
    }

    /**
     * Multiplier that caps a velocity vector at maxMagnitude, preserving
     * direction. Returns 1.0 when no cap applies (also used by the flixel
     * listener, so listener and emitter velocities clamp identically).
     */
    public static function velocityScale(velX:Float, velY:Float, maxMagnitude:Float):Float {
        if (maxMagnitude <= 0) return 1.0;
        var mag = Math.sqrt(velX * velX + velY * velY);
        return mag > maxMagnitude ? maxMagnitude / mag : 1.0;
    }
}
