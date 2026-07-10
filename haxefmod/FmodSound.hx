package haxefmod;

import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;

/**
 * A playing sound returned by FmodManager.PlaySound. Wraps a typed event
 * instance handle.
 *
 *   var explosion = FmodManager.PlaySound(FmodEvents.SFXExplosion);
 *   explosion.setParameter("Distance", 0.5);
 *   explosion.onEvent(data -> switch (data) {
 *       case Stopped: trace("done");
 *       default:
 *   });
 *   explosion.release();
 *
 * All calls are safe on stale/invalid handles. The full event instance API
 * is available by casting: `(sound : EventInstance)`.
 */
abstract FmodSound(EventInstance) from EventInstance to EventInstance {
    public static inline var NULL:FmodSound = cast 0;

    /** True when PlaySound failed (unknown event path or uninitialized). */
    public inline function isNull():Bool {
        return this.isNull();
    }

    public inline function isValid():Bool {
        return this.isValid();
    }

    public inline function isPlaying():Bool {
        return this.getPlaybackState() == FmodPlaybackState.PLAYING;
    }

    /** Stops with a fadeout (as authored in FMOD Studio). */
    public inline function stop():FmodResult {
        return this.stop(ALLOWFADEOUT);
    }

    public inline function stopImmediately():FmodResult {
        return this.stop(IMMEDIATE);
    }

    public inline function pause():FmodResult {
        return this.setPaused(true);
    }

    public inline function unpause():FmodResult {
        return this.setPaused(false);
    }

    /** The volume as set on this sound (linear: 0.0 = silent, 1.0 = full). */
    public inline function getVolume():Float {
        return this.getVolume();
    }

    public inline function setVolume(volume:Float):FmodResult {
        return this.setVolume(volume);
    }

    /** The pitch multiplier as set on this sound (1.0 = as authored). */
    public inline function getPitch():Float {
        return this.getPitch();
    }

    public inline function setPitch(pitch:Float):FmodResult {
        return this.setPitch(pitch);
    }

    public inline function getParameter(name:String):Float {
        return this.getParameter(name);
    }

    public inline function setParameter(name:String, value:Float):FmodResult {
        return this.setParameter(name, value);
    }

    /**
     * Registers a typed payload callback (beats, markers, lifecycle) for
     * this sound. Replaces any previous handler. delivered from
     * FmodManager.Update.
     */
    public inline function onEvent(handler:EventCallbackData->Void, ?mask:Int):Void {
        this.setCallback(handler, mask);
    }

    /**
     * Releases the sound. It keeps playing to completion (or call stop
     * first). The handle becomes invalid immediately.
     */
    public inline function release():FmodResult {
        return this.release();
    }
}
