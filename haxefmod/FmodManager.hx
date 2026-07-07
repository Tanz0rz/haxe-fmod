package haxefmod;

import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.FmodManagerPrivate;

@:access(haxefmod.FmodManagerPrivate)
class FmodManager {
    //// System

    /**
        Enables console debug messages for the system-specific calls made to FMOD
    **/
    public static function EnableDebugMessages() {
        FmodManagerPrivate.GetInstance().EnableDebugMessages();
    }

    /**
        Explicitly starts the FMOD audio engine (only required on html5)
    **/
    public static function Initialize() {
        FmodManagerPrivate.GetInstance();
    }

    /**
        Returns true if the FMOD audio engine is initialized
    **/
    public static function IsInitialized():Bool {
        return FmodManagerPrivate.GetInstance().IsInitialized();
    }

    /**
        Processes FMOD's asynchronous events including parameter changes and callbacks.

        With auto-update enabled (the default), FMOD is automatically updated at ~60fps on a
        background thread (C++/HashLink) or via setInterval (HTML5). This means calling Update()
        manually is optional for most use cases.

        You may still call Update() in your game loop if you want updates synchronized exactly
        with your frame timing, but this provides minimal benefit since auto-update already
        runs at the same rate as a typical game loop.

        To disable auto-update and manage FMOD updates entirely yourself, call SetAutoUpdate(false).
    **/
    public static function Update() {
        FmodManagerPrivate.GetInstance().Update();
    }

    /**
        Enables or disables automatic FMOD updates.

        When enabled (the default), FMOD is updated automatically at ~60fps:
        - C++: Background thread with 16ms sleep
        - HashLink: Background thread using pthread (Linux) or Windows threads
        - HTML5: JavaScript setInterval

        This ensures FMOD processes parameter changes and callbacks even when the game loop
        is paused (e.g., when the window loses focus).

        @param enabled true to enable auto-update (default), false to disable
    **/
    public static function SetAutoUpdate(enabled:Bool) {
        FmodManagerPrivate.GetInstance().SetAutoUpdate(enabled);
    }

    public static function StopAllSounds() {
        FmodManagerPrivate.GetInstance().StopAllSounds();
    }

    public static function PauseAllSounds() {
        FmodManagerPrivate.GetInstance().PauseAllSounds();
    }

    public static function UnpauseAllSounds() {
        FmodManagerPrivate.GetInstance().UnpauseAllSounds();
    }

    //// Bus

    /**
        Sets the volume for a bus.
        Volume is linear: 0.0 = silent, 1.0 = full (default). Values > 1.0 amplify.
        @param busPath FMOD bus path (e.g. "bus:/Music")
        @param volume linear volume level
    **/
    public static function SetBusVolume(busPath:String, volume:Float) {
        FmodManagerPrivate.GetInstance().SetBusVolume(busPath, volume);
    }

    /**
        Gets the user-set volume for a bus (not the final mixed value).
        @param busPath FMOD bus path (e.g. "bus:/Music")
        @return linear volume level
    **/
    public static function GetBusVolume(busPath:String):Float {
        return FmodManagerPrivate.GetInstance().GetBusVolume(busPath);
    }

    /**
        Sets the mute state for a bus.
        @param busPath FMOD bus path (e.g. "bus:/Music")
        @param mute true to mute, false to unmute
    **/
    public static function SetBusMute(busPath:String, mute:Bool) {
        FmodManagerPrivate.GetInstance().SetBusMute(busPath, mute);
    }

    /**
        Gets the mute state for a bus.
        @param busPath FMOD bus path (e.g. "bus:/Music")
        @return true if muted
    **/
    public static function GetBusMute(busPath:String):Bool {
        return FmodManagerPrivate.GetInstance().GetBusMute(busPath);
    }

    //// Master Bus

    /**
        Sets the master bus volume.
        Volume is linear: 0.0 = silent, 1.0 = full (default). Values > 1.0 amplify.
        @param volume linear volume level
    **/
    public static function SetBusVolumeMaster(volume:Float) {
        FmodManagerPrivate.GetInstance().SetBusVolume("bus:/", volume);
    }

    /**
        Gets the master bus volume (user-set value, not the final mixed value).
        @return linear volume level
    **/
    public static function GetBusVolumeMaster():Float {
        return FmodManagerPrivate.GetInstance().GetBusVolume("bus:/");
    }

    /**
        Sets the master bus mute state.
        @param mute true to mute, false to unmute
    **/
    public static function SetBusMuteMaster(mute:Bool) {
        FmodManagerPrivate.GetInstance().SetBusMute("bus:/", mute);
    }

    /**
        Gets the master bus mute state.
        @return true if muted
    **/
    public static function GetBusMuteMaster():Bool {
        return FmodManagerPrivate.GetInstance().GetBusMute("bus:/");
    }

    //// Master Bus (deprecated)

    /**
        Deprecated: Use SetBusVolumeMaster() instead. Will be removed in 2.0.0.
        @param volume linear volume level
    **/
    @:deprecated("Use SetBusVolumeMaster() instead. Will be removed in 2.0.0.")
    public static function SetMasterVolume(volume:Float) {
        SetBusVolumeMaster(volume);
    }

    /**
        Deprecated: Use GetBusVolumeMaster() instead. Will be removed in 2.0.0.
        @return linear volume level
    **/
    @:deprecated("Use GetBusVolumeMaster() instead. Will be removed in 2.0.0.")
    public static function GetMasterVolume():Float {
        return GetBusVolumeMaster();
    }

    /**
        Deprecated: Use SetBusMuteMaster() instead. Will be removed in 2.0.0.
        @param mute true to mute, false to unmute
    **/
    @:deprecated("Use SetBusMuteMaster() instead. Will be removed in 2.0.0.")
    public static function SetMasterMute(mute:Bool) {
        SetBusMuteMaster(mute);
    }

    /**
        Deprecated: Use GetBusMuteMaster() instead. Will be removed in 2.0.0.
        @return true if muted
    **/
    @:deprecated("Use GetBusMuteMaster() instead. Will be removed in 2.0.0.")
    public static function GetMasterMute():Bool {
        return GetBusMuteMaster();
    }

    /**
        Prints out a warning message to console if Update() has not been called recently
    **/
    public static function CheckIfUpdateIsBeingCalled() {
        FmodManagerPrivate.GetInstance().CheckIfUpdateIsBeingCalled();
    }

    //// Music

    /**
        Plays a song from the sound bank
        @param songPath bank path of the song event in the sound bank
    **/
    public static function PlaySong(songPath:String) {
        FmodManagerPrivate.GetInstance().PlaySong(songPath);
    }

    /**
        Used to transition between two songs

        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before playing a new song from the sound bank
        @param songPath bank path of the song event in the sound bank
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function PlaySongTransition(songPath:String) {
        FmodManagerPrivate.GetInstance().PlaySongTransition(songPath);
    }

    /**
        Gets an event parameter value from the song
        @param parameterName name of parameter on song
    **/
    public static function GetEventParameterOnSong(parameterName:String) {
        return FmodManagerPrivate.GetInstance().GetEventParameterOnSong(parameterName);
    }

    /**
        Sets an event parameter value on the song
        @param parameterName name of parameter on song
        @param parameterValue value for parameter
    **/
    public static function SetEventParameterOnSong(parameterName:String, parameterValue:Float) {
        FmodManagerPrivate.GetInstance().SetEventParameterOnSong(parameterName, parameterValue);
    }

    /**
        Sends the "stop" command to the FMOD API for the current song
    **/
    public static function StopSong() {
        FmodManagerPrivate.GetInstance().StopSong();
    }

    /**
        If a song is playing, it will stop immediately
    **/
    public static function StopSongImmediately() {
        FmodManagerPrivate.GetInstance().StopSongImmediately();
    }

    /**
        If a song is playing, it will pause
    **/
    public static function PauseSong() {
        FmodManagerPrivate.GetInstance().PauseSong();
    }

    /**
        If a song is paused, it will unpause
    **/
    public static function UnpauseSong() {
        FmodManagerPrivate.GetInstance().UnpauseSong();
    }

    /**
        If a song is paused, it will unpause
    **/
    public static function ClearAllCallbacks() {
        FmodManagerPrivate.GetInstance().ClearAllCallbacks();
    }

    /**
        Returns true if a song is playing
    **/
    public static function IsSongPlaying():Bool {
        return FmodManagerPrivate.GetInstance().IsSongPlaying();
    }

    /**
        Gets the event path of the current song.
        If no song is playing, returns an empty string
    **/
    public static function GetCurrentSongPath():String {
        return FmodManagerPrivate.GetInstance().GetCurrentSongPath();
    }

    /**
        Gets the timeline position of the current song in milliseconds.
        This reflects FMOD's audio processing timeline, which may differ
        from wall-clock time when using output modes like WAVWRITER.
        @return position in milliseconds, or 0 if no song is playing
    **/
    public static function GetSongTimelinePosition():Int {
        return FmodManagerPrivate.GetInstance().GetSongTimelinePosition();
    }

    //// Sound effects

    /**
        Plays a sound in a fire-and-forget fashion

        There is no way to interact with these sounds once they are started

        Follows the Master Track rules which are set in FMOD Studio (Max Instances, Stealing, and probably more)

        @param soundPath bank path of the sound event in the sound bank
        @see https://tanneris.me/FMOD-Macro-Controls
    **/
    public static function PlaySoundOneShot(soundPath:String) {
        FmodManagerPrivate.GetInstance().PlaySoundOneShot(soundPath);
    }

    /**
        Plays a sound and returns the Id to allow further interactions

        When this sound is no longer needed, call ReleaseSound to cleanup memory

        Simple sound effects should be played with PlaySoundOneShot
        @param soundPath bank path of the sound event in the sound bank
        @return soundId of the new event instance
    **/
    public static function PlaySoundWithReference(soundPath:String):String {
        return FmodManagerPrivate.GetInstance().PlaySoundWithReference(soundPath);
    }

    /**
        Plays a sound and sets the reference Id

        When this sound is no longer needed, call ReleaseSound to cleanup memory

        Simple sound effects should be played with PlaySoundOneShot
        @param soundPath bank path of the sound event in the sound bank
        @return soundId of the new event instance
    **/
    public static function PlaySoundAndAssignId(soundPath:String, soundId:String):String {
        return FmodManagerPrivate.GetInstance().PlaySoundAndAssignId(soundPath, soundId);
    }

    /**
        Checks if a given sound Id is loaded

        @param soundId Id of a loaded sound
        @return bool
    **/
    public static function IsSoundLoaded(soundId:String):Bool {
        return FmodManagerPrivate.GetInstance().IsSoundLoaded(soundId);
    }

    /**
        Checks if a given sound Id is currently playing

        @param soundId Id of a loaded sound
        @return bool
    **/
    public static function IsSoundPlaying(soundId:String):Bool {
        return FmodManagerPrivate.GetInstance().IsSoundPlaying(soundId);
    }

    /**
        Gets an event parameter value from a sound
        @param soundId Id of a loaded sound
        @param parameterName name of parameter on sound
    **/
    public static function GetEventParameterOnSound(soundId:String, parameterName:String):Float {
        return FmodManagerPrivate.GetInstance().GetEventParameterOnSound(soundId, parameterName);
    }

    /**
        Sets an event parameter value on a sound
        @param soundId Id of a loaded sound
        @param parameterName name of parameter on sound
        @param parameterValue value for parameter
    **/
    public static function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float) {
        FmodManagerPrivate.GetInstance().SetEventParameterOnSound(soundId, parameterName, parameterValue);
    }

    /**
        Stops a sound for the provided sound Id

        To stop a sound immediately, use StopSoundImmediately(soundId)
        @param soundId Id of a loaded sound
    **/
    public static function StopSound(soundId:String) {
        FmodManagerPrivate.GetInstance().StopSound(soundId);
    }

    /**
        Immediately stops a sound for the provided sound Id
        @param soundId Id of a loaded sound
    **/
    public static function StopSoundImmediately(soundId:String) {
        FmodManagerPrivate.GetInstance().StopSoundImmediately(soundId);
    }

    /**
        Pauses a sound
        @param soundId Id of a loaded sound
    **/
    public static function PauseSound(soundId:String) {
        FmodManagerPrivate.GetInstance().PauseSound(soundId);
    }

    /**
        Unpauses a sound
        @param soundId Id of a loaded sound
    **/
    public static function UnpauseSound(soundId:String) {
        FmodManagerPrivate.GetInstance().UnpauseSound(soundId);
    }

    /**
        Immediately stops a sound for the provided sound Id and releases it from memory
        @param soundId Id of a loaded sound
    **/
    public static function ReleaseSound(soundId:String) {
        FmodManagerPrivate.GetInstance().ReleaseSound(soundId);
    }

    //// Callbacks

    /**
        Register a callback for the current song
        @param callback Function to execute when the provided playbackEventMask is triggered
        @param playbackEventMask Event mask that will trigger the callback 
        @see The FmodCallback class in FmodEvents.hx
        @see https://tanneris.me/FMOD-Callback-Types
    **/
    public static function RegisterCallbacksForSong(callback:Void->Void, playbackEventMask:UInt) {
        FmodManagerPrivate.GetInstance().RegisterCallbacksForSong(callback, playbackEventMask);
    }

    /**
        Registers a typed callback on the current song that receives full
        payload data (timeline beats with bar/beat/tempo, timeline markers
        with names, and playback lifecycle events).

        Replaces any previously registered song callback. Requires
        FmodManager.Update() to be called in the game loop.
        @param handler Receives one EventCallbackData value per event
        @param playbackEventMask Optional bitmask of EventCallbackType values (defaults to all playback events)
    **/
    public static function OnSongEvent(handler:haxefmod.studio.Callbacks.EventCallbackData->Void, ?playbackEventMask:Int) {
        FmodManagerPrivate.GetInstance().OnSongEvent(handler, playbackEventMask);
    }

    /**
        Disables callbacks for the current song
    **/
    private function UnregisterCallbacksForSong() {
        FmodManagerPrivate.GetInstance().UnregisterCallbacksForSong();
    }

    /**
        Register a callback for a sound
        @param soundId Id of a loaded sound
        @param callback Function to execute when the provided playbackEventMask is triggered
        @param playbackEventMask Event mask that will trigger the callback 
        @see The FmodCallback class in FmodEvents.hx
        @see https://tanneris.me/FMOD-Callback-Types
    **/
    public static function RegisterCallbacksForSound(soundId:String, callback:Void->Void, playbackEventMask:UInt) {
        FmodManagerPrivate.GetInstance().RegisterCallbacksForSound(soundId, callback, playbackEventMask);
    }

    /**
        Disables callbacks for a sound
        @param soundId Id of a sound with registered callbacks
    **/
    private function UnregisterCallbacksForSound(soundId:String) {
        FmodManagerPrivate.GetInstance().UnregisterCallbacksForSound(soundId);
    }

    //// Utility

    /**
        Experimental: register any class that satisfies the FmodEventListener interface

        Will be used to allow utility methods (like screen transition helpers) for any Haxe framework
        @param eventListener An implementer of the FmodEventListener interface
    **/
    public static function RegisterEventListener(eventListener:FmodEventListener) {
        FmodManagerPrivate.GetInstance().RegisterEventListener(eventListener);
    }
}
