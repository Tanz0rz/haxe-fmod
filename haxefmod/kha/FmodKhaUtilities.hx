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
        (self-ending) events - a looping event played this way never
        releases.
        @param eventPath the full event path (e.g. "event:/SFX/Explosion")
        @param target the body the sound follows
    **/
    public static function PlayOneShotAttached(eventPath:String, target:KhaBody):Void {
        var provider = new KhaBodyPositionProvider(target);
        FmodManager.PlayOneShotAttached(eventPath, provider);
        // The provider has to be sampled every frame for as long as the
        // one-shot lives. The sampler unregisters once the runtime drops
        // the attachment, which happens when the instance ends.
        FmodKhaUpdater.add(new OneShotSampler(provider));
    }
    @:deprecated("FmodKhaUtilities.PlaySoundOneShotAttached is now PlayOneShotAttached")
    public static function PlaySoundOneShotAttached(eventPath:String, target:KhaBody):Void {
        PlayOneShotAttached(eventPath, target);
    }
}

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
