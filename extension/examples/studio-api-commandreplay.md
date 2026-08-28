# studio-api-commandreplay

## *
<!-- page default -->
haxefmod binds command capture and basic replay playback only. Record with StudioSystem.startCommandCapture(path), load the file with StudioSystem.loadCommandReplay(path), and drive the CommandReplay handle with start, stop, setPaused, seekToTime, and getLength.
The per-command callbacks (create instance, frame, load bank), command info queries, and instance type lookups are FMOD tooling hooks that would run Haxe code from FMOD's threads, so they are not exposed. Use FMOD Studio's own profiler tools to inspect a capture.
```haxe
if (StudioSystem.startCommandCapture("capture.cmd.txt").isOk()) {
    // play the game for a while
    StudioSystem.stopCommandCapture();
}

var replay = StudioSystem.loadCommandReplay("capture.cmd.txt");
if (!replay.isNull()) {
    replay.start();
    trace('replay length ${replay.getLength()} seconds');
    // when finished
    replay.stop();
    replay.release();
}
```
