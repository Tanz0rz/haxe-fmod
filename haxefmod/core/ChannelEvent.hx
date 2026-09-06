package haxefmod.core;

/**
 * FMOD_CHANNELCONTROL_CALLBACK as game code holds it. Channel.setCallback
 * and ChannelGroup.setCallback take one. The handle it was registered on
 * stands in for the channelcontrol and controltype arguments, the event
 * carries the callback type and its data, and nothing is returned.
 */
typedef ChannelCallback = ChannelEvent->Void;

/**
 * A playback event delivered to a Channel.setCallback or
 * ChannelGroup.setCallback handler.
 */
enum ChannelEvent {
    /** The channel finished playing (also fires on stop). Channels only. */
    End;
    /**
     * Playback crossed a sync point (see Sound.addSyncPoint). Channels
     * only. index is the point's position in offset order, the same value
     * a FmodSyncPoint holds, so (index : FmodSyncPoint) addresses it.
     */
    SyncPoint(index:Int);
    /** The channel went virtual (true) or came back to a real voice (false). Channels only. */
    VirtualVoice(isVirtual:Bool);
    /**
     * Geometry occlusion was computed for a 3D channel or group. The
     * values are the ones FMOD is about to apply, read-only here.
     */
    Occlusion(direct:Float, reverb:Float);
}
