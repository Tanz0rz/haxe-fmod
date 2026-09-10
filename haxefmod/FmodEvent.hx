package haxefmod;

import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;

/**
 * A playing event returned by FmodManager.PlayEvent. It wraps a typed event instance handle.
 *
 *   var explosion = FmodManager.PlayEvent(FmodEvents.SFXExplosion);
 *   explosion.setParameter("Distance", 0.5);
 *   explosion.onEvent(data -> switch (data) {
 *       case Stopped: trace("done");
 *       default:
 *   });
 *   explosion.release();
 *
 * Every call is safe on a null or stale handle. The full event instance API is one cast away: `(event : EventInstance)`.
 */
abstract FmodEvent(EventInstance) from EventInstance to EventInstance {
    /** The null handle. Every call on it is a safe no-op. */
    public static inline var NULL:FmodEvent = cast 0;

    /** Returns true when PlayEvent or CreateEvent failed, because the event path is unknown or FMOD is not initialized. */
    public inline function isNull():Bool {
        return this.isNull();
    }

    /** Asks the native side whether the handle still points at a live event instance. A released event is stale. */
    public inline function isValid():Bool {
        return this.isValid();
    }

    /**
     * Returns true until the event fully stops. Starting, playing, sustaining, and fading out all count.
     * FMOD starts sounds asynchronously, so the PLAYING state alone would misread the first frames after play.
     */
    public inline function isPlaying():Bool {
        return this.getPlaybackState() != FmodPlaybackState.STOPPED;
    }

    /** Starts an event from FmodManager.CreateEvent. An event from PlayEvent is already started, and starting it again restarts it from the beginning. */
    public inline function start():FmodResult {
        return this.start();
    }

    /** Stops the event with the fadeout authored in FMOD Studio. */
    public inline function stop():FmodResult {
        return this.stop(ALLOWFADEOUT);
    }

    /** Stops the event with no fade. */
    public inline function stopImmediately():FmodResult {
        return this.stop(IMMEDIATE);
    }

    /** Freezes the event at its position. */
    public inline function pause():FmodResult {
        return this.setPaused(true);
    }

    /** Resumes an event paused by pause(). */
    public inline function unpause():FmodResult {
        return this.setPaused(false);
    }

    /** Returns the volume set on this event, from 0.0, silent, to 1.0, full. */
    public inline function getVolume():Float {
        return this.getVolume();
    }

    /** Sets the volume of this event, from 0.0, silent, to 1.0, full. */
    public inline function setVolume(volume:Float):FmodResult {
        return this.setVolume(volume);
    }

    /** Returns the pitch multiplier set on this event. 1.0 is as authored. */
    public inline function getPitch():Float {
        return this.getPitch();
    }

    /** Sets the pitch multiplier of this event. 1.0 is as authored. */
    public inline function setPitch(pitch:Float):FmodResult {
        return this.setPitch(pitch);
    }

    /** Places the event in 2D space relative to listener 0, the same space PlayOneShotAt uses. The velocity feeds doppler and is zero when omitted. */
    public inline function setPosition2D(x:Float, y:Float, velocityX:Float = 0, velocityY:Float = 0):FmodResult {
        return this.setPosition2D(x, y, velocityX, velocityY);
    }

    /** True while the event is paused. */
    public inline function isPaused():Bool {
        return this.getPaused();
    }

    /** The timeline position in milliseconds, 0 on failure. */
    public inline function getTimelinePosition():Int {
        return this.getTimelinePosition();
    }

    /** Moves the timeline to a position in milliseconds. */
    public inline function setTimelinePosition(positionMs:Int):FmodResult {
        return this.setTimelinePosition(positionMs);
    }

    /** Returns the value of a parameter on this event. */
    public inline function getParameter(name:String):Float {
        return this.getParameter(name);
    }

    /** Sets a parameter on this event by name. */
    public inline function setParameter(name:String, value:Float):FmodResult {
        return this.setParameter(name, value);
    }

    /** Sets a labeled parameter on this event by its label text, for example "Surface" to "Grass". */
    public inline function setParameterWithLabel(name:String, label:String):FmodResult {
        return this.setParameterWithLabel(name, label);
    }

    /**
     * Registers a typed callback for this event. Beats, markers, and lifecycle events arrive from FmodManager.Update() as EventCallbackData values.
     * The optional mask limits the delivered EventCallbackType bits. A new registration replaces the previous handler.
     */
    public inline function onEvent(handler:EventCallbackData->Void, ?mask:Int):Void {
        this.setCallback(handler, mask);
    }

    /**
     * Registers a typed callback that fires for the first delivered event and then removes itself, like FmodManager.OnceSongEvent.
     * The mask picks which events qualify. It replaces any previous handler.
     */
    public function onceEvent(handler:EventCallbackData->Void, ?mask:Int):Void {
        var instance:EventInstance = this;
        instance.setCallback(data -> {
            var unwanted = switch (data) {
                case Destroyed: mask != null && (mask & EventCallbackType.DESTROYED) == 0;
                default: false;
            }
            instance.setCallback(null);
            if (!unwanted) handler(data);
        }, mask);
    }

    /** Releases the event. It plays to completion unless you stopped it first. The handle becomes invalid immediately. */
    public inline function release():FmodResult {
        return this.release();
    }
}
