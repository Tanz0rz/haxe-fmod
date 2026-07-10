package haxefmod.runtime;

import haxefmod.studio.EventInstance;

/**
 * Tracks event instances attached to moving objects and pushes their 3D
 * attributes to FMOD once per update. Instances that die (released,
 * stopped and destroyed, stale handles) are pruned automatically.
 */
class AttachedInstances {
    var entries:Array<{instance:EventInstance, provider:IFmodPositionProvider}> = [];

    public function new() {}

    /** Attaches an instance. replaces the provider if already attached. */
    public function attach(instance:EventInstance, provider:IFmodPositionProvider):Void {
        if (instance.isNull() || provider == null) return;
        for (entry in entries) {
            if ((entry.instance : Int) == (instance : Int)) {
                entry.provider = provider;
                return;
            }
        }
        entries.push({instance: instance, provider: provider});
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
            } else {
                push(entry.instance, entry.provider);
            }
            i--;
        }
    }

    static inline function push(instance:EventInstance, provider:IFmodPositionProvider):Void {
        instance.setPosition2D(provider.fmodX(), provider.fmodY(),
            provider.fmodVelocityX(), provider.fmodVelocityY());
    }
}
