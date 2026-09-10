package haxefmod.heaps;

import h2d.Object;
import haxefmod.FmodManager;
import haxefmod.heaps.FmodHeapsEmitter.H2dObjectPositionProvider;
import haxefmod.heaps.FmodHeapsUpdater.IHeapsTicker;
import haxefmod.runtime.FmodRuntime;

/** Helpers that tie FmodManager to Heaps objects. **/
class FmodHeapsUtilities {
    /**
        Fire-and-forget playback that follows an object (center of its
        bounds, derived velocity) until the event ends. Intended for
        one-shot (self-ending) events - a looping event played this way
        never releases.
        @param eventPath the full event path (e.g. "event:/SFX/Explosion")
        @param target the object the event follows
    **/
    public static function PlayOneShotAttached(eventPath:String, target:Object):Void {
        var provider = new H2dObjectPositionProvider(target);
        FmodManager.PlayOneShotAttached(eventPath, provider);
        // The provider has to be sampled every frame for as long as the
        // one-shot lives. The sampler unregisters once the runtime drops
        // the attachment, which happens when the instance ends.
        FmodHeapsUpdater.add(new OneShotSampler(provider));
    }
    @:deprecated("FmodHeapsUtilities.PlaySoundOneShotAttached is now PlayOneShotAttached")
    public static function PlaySoundOneShotAttached(eventPath:String, target:Object):Void {
        PlayOneShotAttached(eventPath, target);
    }
}

private class OneShotSampler implements IHeapsTicker {
    var provider:H2dObjectPositionProvider;

    public function new(provider:H2dObjectPositionProvider) {
        this.provider = provider;
    }

    public function tick(dt:Float):Void {
        provider.sample(dt);
        if (!FmodRuntime.isAttachedProvider(provider)) {
            FmodHeapsUpdater.remove(this);
        }
    }
}
