package faxe;

import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;

@:access(faxe.FaxeSoundHelperPrivate)
class FaxeSoundHelper {

    //// Music

    /**
        Plays a song from the sound bank
        @param songName event name of song in sound bank
    **/
    public static function PlaySong(songName:String){
        FaxeSoundHelperPrivate.GetInstance().PlaySong(songName);
    }
    
    /**
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before playing a new song from the sound bank
        @param songName event name of song in sound bank
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function PlaySongTransition(songName:String) {
        FaxeSoundHelperPrivate.GetInstance().PlaySongTransition(songName);
    }
   
    /**
        Gets event parameter value from song 
        @param parameterName name of parameter on song
    **/
    public static function GetEventParameterOnSong(parameterName:String){
        return FaxeSoundHelperPrivate.GetInstance().GetEventParameterOnSong(parameterName);
    }
   
    /**
        Sets event parameter value on a song 
        @param parameterName name of parameter on song
        @param parameterValue value for parameter
    **/
    public static function SetEventParameterOnSong(parameterName:String, parameterValue:Float){
        FaxeSoundHelperPrivate.GetInstance().SetEventParameterOnSong(parameterName, parameterValue);
    }
    
    /**
        Sends the "stop" command to the FMOD API for the current song
    **/
    public static function StopSong(){
        FaxeSoundHelperPrivate.GetInstance().StopSong();
    }
    
    /**
        If a song is playing, it will stop immediately
    **/
    public static function StopSongImmediately(){
        FaxeSoundHelperPrivate.GetInstance().StopSongImmediately();
    }
    
    /**
        If a song is playing, it will pause 
    **/
    public static function PauseSong(){
        FaxeSoundHelperPrivate.GetInstance().PauseSong();
    }
    
    /**
        If a song is paused, it will unpause 
    **/
    public static function UnpauseSong(){
        FaxeSoundHelperPrivate.GetInstance().UnpauseSong();
    }

    //// Sound effects
  
    /**
        Plays a sound in a fire-and-forget fashion

        Do not play sounds with Loop Regions with this call
        @param songName event name of song in sound bank
        @see https://tanneris.me/FMOD-Macro-Controls
        @see https://tanneris.me/FMOD-Loop-Region
    **/
    public static function PlaySoundOneShot(soundName:String) {
        FaxeSoundHelperPrivate.GetInstance().PlaySoundOneShot(soundName);
    }
    
    /**
        Plays a sound and returns the Id to allow further processing
        @param soundName event name of sound in sound bank
        @return soundId of the new event instance
    **/
    public static function PlaySound(soundName:String):String {
        return FaxeSoundHelperPrivate.GetInstance().PlaySound(soundName);
    }
   
    /**
        Get the parameter on a sound 
        @param soundId Id of a currently-loaded sound
        @param parameterName name of parameter on sound
    **/
    public static function GetEventParameterOnSound(soundId:String, parameterName:String):Float{
        return FaxeSoundHelperPrivate.GetInstance().GetEventParameterOnSound(soundId, parameterName);
    }
   
    /**
        Sets the parameter on a sound 
        @param soundId Id of a currently-loaded sound
        @param parameterName name of parameter on sound
        @param parameterValue value for parameter
    **/
    public static function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float){
        FaxeSoundHelperPrivate.GetInstance().SetEventParameterOnSound(soundId, parameterName, parameterValue);
    }
    
    /**
        Stops a sound for the provided sound Id

        To stop a sound immediately, use StopSoundImmediately(soundId)
        @param soundId Id of a currently-loaded sound
    **/
    public static function StopSound(soundId:String){
        FaxeSoundHelperPrivate.GetInstance().StopSound(soundId);
    }
  
    /**
        Immediately stops a sound for the provided sound Id
        @param soundId Id of a currently-loaded sound
    **/
    public static function StopSoundImmediately(soundId:String){
        FaxeSoundHelperPrivate.GetInstance().StopSoundImmediately(soundId);
    }

    //// Utility

    /**
        Experimental: register any class that satisfies the FaxeEventLister interface

        Will be used to allow utility methods (like screen transition helpers) for any Haxe framework
        @param eventListener An implementer of the FaxeEventListener interface
    **/
    public static function RegisterEventListener(eventListener:FaxeEventListener) {
        FaxeSoundHelperPrivate.GetInstance().RegisterEventListener(eventListener);
    }

    //// System

    /**
        A call required by the FMOD API for the update loop of the game

        This is managed automatically as long as add(new FaxeUpdater()) is in the create() of every state
    **/
    public static function Update() {
        FaxeSoundHelperPrivate.GetInstance().Update();
    }
}
