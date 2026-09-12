package fmodtest;

/**
 * What a test scenario needs from the game engine hosting it. Each engine's
 * example project implements this once and every scenario runs unchanged
 * on top of it.
 */
interface TestHost {
    /** Shows progress text on screen. Scenarios log separately. */
    function setStatus(text:String):Void;

    /** Ends the process with the given code where the platform allows it. */
    function exit(code:Int):Void;

    /** The engine's one-call FMOD setup (FmodFlxSetup.init() and its peers). */
    function setupInit():Void;

    /**
     * Calls setupInit() a second time and reports through check whether
     * exactly one per-frame updater remains installed.
     */
    function checkSetupReinit(check:String->Bool->String->Void):Void;

    /**
     * Drives whichever volume and mute controls the engine offers and
     * reports each result through check. An engine with its own global
     * volume proves that control lands on the FMOD master bus. An engine
     * without one drives the FMOD master bus directly, so the checks cover
     * the round trip only. Must leave full volume, unmuted.
     */
    function checkVolumeControls(check:String->Bool->String->Void):Void;

    /**
     * Installs or removes the engine's per-frame updater. A scenario that
     * must observe an undrained callback queue removes it for that phase
     * and puts it back afterwards.
     */
    function setUpdaterInstalled(installed:Bool):Void;

    /** Raises the engine's own focus lost or gained event. */
    function setFocusThroughEngine(focused:Bool):Void;

    /** Starts the engine's bank loader component for the given files. */
    function addBankLoader(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool):Void;
}
