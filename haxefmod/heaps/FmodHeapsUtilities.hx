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
        one-shot (self-ending) events. A looping event played this way
        never releases.
        @param eventPath The full event path, for example "event:/SFX/Explosion".
        @param target The object the event follows.
    **/
    public static function PlayOneShotAttached(eventPath:String, target:Object):Void {
        var provider = new H2dObjectPositionProvider(target);
        // The first push happens inside the call, so sample the target now
        provider.sample(0);
        FmodManager.PlayOneShotAttached(eventPath, provider);
        // The provider has to be sampled every frame for as long as the
        // one-shot lives. The sampler unregisters once the runtime drops
        // the attachment, which happens when the instance ends.
        FmodHeapsUpdater.add(new OneShotSampler(provider));
    }

}

/** Samples a one-shot's provider every frame until the runtime drops the attachment. **/
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
