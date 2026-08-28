package haxefmod.core;

/**
 * A channel playback event delivered to a Channel.setCallback handler.
 */
enum ChannelEvent {
    /** The channel finished playing (also fires on stop). */
    End;
    /** Playback crossed a sync point (see Sound.addSyncPoint). */
    SyncPoint(index:Int);
}
