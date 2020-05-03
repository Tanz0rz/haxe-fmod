package faxe;

import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;

@:access(faxe.FaxeSoundHelperPrivate)
class FaxeSoundHelper {

    /**
        Plays a song from the sound bank
        @param songName event name of song in sound bank
    **/
    public static function PlaySong(songName:String){
        FaxeSoundHelperPrivate.GetInstance().PlaySongPrivate(songName);
    }
    
    /**
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before playing a new song from the sound bank
        @param songName event name of song in sound bank
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function PlaySongTransition(songName:String) {
        FaxeSoundHelperPrivate.GetInstance().PlaySongTransitionPrivate(songName);
    }
   
    /**
        Sets the parameter on a song 
        @param parameterName name of parameter on song
        @param parameterValue value for parameter
    **/
    public static function SetEventParameterOnSong(parameterName:String, parameterValue:Float){
        FaxeSoundHelperPrivate.GetInstance().SetEventParameterOnSongPrivate(parameterName, parameterValue);
    }
    
    /**
        If a song is playing, it will stop immediately
    **/
    public static function StopSong(){
        FaxeSoundHelperPrivate.GetInstance().StopSongPrivate();
    }
    
    /**
        If a song is playing, it will pause 
    **/
    public static function PauseSong(){
        FaxeSoundHelperPrivate.GetInstance().PauseSongPrivate();
    }
    
    /**
        If a song is paused, it will unpause 
    **/
    public static function UnpauseSong(){
        FaxeSoundHelperPrivate.GetInstance().UnpauseSongPrivate();
    }
  
    /**
        Plays a sound in a fire-and-forget fashion

        Do not play sounds with Loop Regions with this call
        @param songName event name of song in sound bank
        @see https://tanneris.me/FMOD-Macro-Controls
        @see https://tanneris.me/FMOD-Loop-Region
    **/
    public static function PlaySoundOneShot(soundName:String) {
        FaxeSoundHelperPrivate.GetInstance().PlaySoundOneShotPrivate(soundName);
    }
    
    /**
        Plays a sound and returns the Id to allow further processing
        @param soundName event name of sound in sound bank
        @return soundId of the new event instance
    **/
    public static function PlaySound(soundName:String):String {
        return FaxeSoundHelperPrivate.GetInstance().PlaySoundPrivate(soundName);
    }
    
    /**
        Stops a sound for the provided sound Id

        To stop a sound immediately, use StopSoundImmediately(soundId)
        @param soundId Id of a currently-loaded sound
    **/
    public static function StopSound(soundId:String){
        FaxeSoundHelperPrivate.GetInstance().StopSoundPrivate(soundId);
    }
  
    /**
        Immediately stops a sound for the provided sound Id
        @param soundId Id of a currently-loaded sound
    **/
    public static function StopSoundImmediately(soundId:String){
        FaxeSoundHelperPrivate.GetInstance().StopSoundImmediatelyPrivate(soundId);
    }
 
    /**
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before triggering a state transition
        @param state the state to load after the music stops
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function TransitionToStateAndStopMusic(state:FlxState){
        FaxeSoundHelperPrivate.GetInstance().TransitionToStateAndStopMusicPrivate(state);
    }
   
    /**
        Convenience method that imply calls FlxG.switchState(state)

        Music will continue to play even after loading the new state
        @param state the state to load
    **/
    public static function TransitionToState(state:FlxState){
        FaxeSoundHelperPrivate.GetInstance().TransitionToStatePrivate(state);
    }
   
    /**
        A call required by the FMOD API for update loop of the game

        This is managed automatically as long as add(new FaxeUpdater()) is in the create() of every state
    **/
    public static function Update() {
        FaxeSoundHelperPrivate.GetInstance().UpdatePrivate();
    }
}
