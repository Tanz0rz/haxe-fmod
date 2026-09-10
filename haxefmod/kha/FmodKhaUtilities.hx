package haxefmod.kha;

import haxefmod.FmodManager;
import haxefmod.kha.FmodKhaEmitter.KhaBody;
import haxefmod.kha.FmodKhaEmitter.KhaBodyPositionProvider;
import haxefmod.kha.FmodKhaUpdater.IKhaTicker;
import haxefmod.runtime.FmodRuntime;

/** Helpers that tie FmodManager to Kha bodies. **/
class FmodKhaUtilities {
    /**
        Fire-and-forget playback that follows a body (midpoint, derived
        velocity) until the event ends. Intended for one-shot
        (self-ending) events. A looping event played this way never
        releases.
        @param eventPath The full event path, for example "event:/SFX/Explosion".
        @param target The body the event follows.
    **/
    public static function PlayOneShotAttached(eventPath:String, target:KhaBody):Void {
        var provider = new KhaBodyPositionProvider(target);
        // The first push happens inside the call, so sample the target now
        provider.sample(0);
        FmodManager.PlayOneShotAttached(eventPath, provider);
        // The provider has to be sampled every frame for as long as the
        // one-shot lives. The sampler unregisters once the runtime drops
        // the attachment, which happens when the instance ends.
        FmodKhaUpdater.add(new OneShotSampler(provider));
    }

}

/** Samples a one-shot's provider every frame until the runtime drops the attachment. **/
private class OneShotSampler implements IKhaTicker {
    var provider:KhaBodyPositionProvider;

    public function new(provider:KhaBodyPositionProvider) {
        this.provider = provider;
    }

    public function tick(dt:Float):Void {
        provider.sample(dt);
        if (!FmodRuntime.isAttachedProvider(provider)) {
            FmodKhaUpdater.remove(this);
        }
    }
}
