package haxefmod.core;

/**
 * A playback event delivered to a Channel.setCallback or
 * ChannelGroup.setCallback handler.
 */
enum ChannelEvent {
    /** The channel finished playing (also fires on stop). Channels only. */
    End;
    /** Playback crossed a sync point (see Sound.addSyncPoint). Channels only. */
    SyncPoint(index:Int);
    /** The channel went virtual (true) or came back to a real voice (false). Channels only. */
    VirtualVoice(isVirtual:Bool);
    /**
     * Geometry occlusion was computed for a 3D channel or group. The
     * values are the ones FMOD is about to apply, read-only here.
     */
    Occlusion(direct:Float, reverb:Float);
}
