package haxefmod.studio;

/**
 * FMOD_STUDIO_EVENT_CALLBACK_* bits, pinned to FMOD 2.03.12.
 * Combine with | to build masks for callback registration.
 */
enum abstract EventCallbackType(Int) from Int to Int {
    var CREATED = 0x00000001;
    var DESTROYED = 0x00000002;
    var STARTING = 0x00000004;
    var STARTED = 0x00000008;
    var RESTARTED = 0x00000010;
    var STOPPED = 0x00000020;
    var START_FAILED = 0x00000040;
    var CREATE_PROGRAMMER_SOUND = 0x00000080;
    var DESTROY_PROGRAMMER_SOUND = 0x00000100;
    var PLUGIN_CREATED = 0x00000200;
    var PLUGIN_DESTROYED = 0x00000400;
    var TIMELINE_MARKER = 0x00000800;
    var TIMELINE_BEAT = 0x00001000;
    var SOUND_PLAYED = 0x00002000;
    var SOUND_STOPPED = 0x00004000;
    var REAL_TO_VIRTUAL = 0x00008000;
    var VIRTUAL_TO_REAL = 0x00010000;
    var START_EVENT_COMMAND = 0x00020000;
    var NESTED_TIMELINE_BEAT = 0x00040000;
    var ALL = 0xFFFFFFFF;

    /** All playback lifecycle events (no programmer sound / plugin / command hooks). */
    public static inline var PLAYBACK_ALL:Int = CREATED | DESTROYED | STARTING | STARTED | RESTARTED
        | STOPPED | START_FAILED | TIMELINE_MARKER | TIMELINE_BEAT | SOUND_PLAYED | SOUND_STOPPED
        | REAL_TO_VIRTUAL | VIRTUAL_TO_REAL | NESTED_TIMELINE_BEAT;
}

/**
 * A decoded FMOD Studio event callback with its payload.
 * Delivered on the game thread by the CallbackDispatcher during update().
 */
enum EventCallbackData {
    Created;
    Destroyed;
    Starting;
    Started;
    Restarted;
    Stopped;
    StartFailed;
    TimelineMarker(name:String, positionMs:Int);
    TimelineBeat(bar:Int, beat:Int, positionMs:Int, tempo:Float, timeSigUpper:Int, timeSigLower:Int);
    /** A beat on a referenced event's timeline. eventId is the GUID FMOD reports for that timeline, in FMOD's text form. */
    NestedTimelineBeat(bar:Int, beat:Int, positionMs:Int, tempo:Float, timeSigUpper:Int, timeSigLower:Int, eventId:String);
    SoundPlayed;
    SoundStopped;
    RealToVirtual;
    VirtualToReal;
    /** A programmer instrument asked for its sound. name is the instrument's name in FMOD Studio. */
    ProgrammerSoundCreated(name:String);
    /** A programmer instrument finished with its sound. */
    ProgrammerSoundDestroyed(name:String);
    /**
     * A plugin effect on the instance was created. dsp is the effect unit,
     * valid until PluginDestroyed arrives for it.
     */
    PluginCreated(name:String, dsp:haxefmod.core.Dsp);
    /**
     * A plugin effect on the instance is gone. dsp carries the same handle
     * PluginCreated delivered, for matching, and no longer resolves.
     */
    PluginDestroyed(name:String, dsp:haxefmod.core.Dsp);
    /** A callback type without a dedicated constructor. */
    Other(type:EventCallbackType);
}
