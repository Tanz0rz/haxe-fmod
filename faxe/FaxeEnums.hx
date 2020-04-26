package faxe;

import faxe.Faxe.FmodStudioPlaybackState;

class FaxeEnums{
    public static function EventPlaybackStateToString(playbackState:FmodStudioPlaybackState):String{
        switch(playbackState){
            case FMOD_STUDIO_PLAYBACK_PLAYING:
                return "FMOD_STUDIO_PLAYBACK_PLAYING";
            case FMOD_STUDIO_PLAYBACK_SUSTAINING:
                return "FMOD_STUDIO_PLAYBACK_SUSTAINING";
            case FMOD_STUDIO_PLAYBACK_STOPPED:
                return "FMOD_STUDIO_PLAYBACK_STOPPED";
            case FMOD_STUDIO_PLAYBACK_STARTING:
                return "FMOD_STUDIO_PLAYBACK_STARTING";
            case FMOD_STUDIO_PLAYBACK_STOPPING:
                return "FMOD_STUDIO_PLAYBACK_STOPPING";
            case FMOD_STUDIO_PLAYBACK_FORCEINT:
                return "FMOD_STUDIO_PLAYBACK_ERROR";
        }
        return "FMOD_STUDIO_PLAYBACK_ERROR";
    }
}