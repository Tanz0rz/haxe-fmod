package kha;

/** The application state hooks FmodKhaSetup wires. */
class System {
	public static function notifyOnApplicationState(foregroundListener:Void->Void, resumeListener:Void->Void, pauseListener:Void->Void,
			backgroundListener:Void->Void, shutdownListener:Void->Void):Void {}

	public static function removeApplicationStateListeners(foregroundListener:Void->Void, resumeListener:Void->Void, pauseListener:Void->Void,
			backgroundListener:Void->Void, shutdownListener:Void->Void):Void {}
}
