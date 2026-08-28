# studio-api-commandreplay

## *
<!-- page default -->
Record with StudioSystem.startCommandCapture(path), load the file with StudioSystem.loadCommandReplay(path), and drive the CommandReplay handle with start, stop, setPaused, seekToTime, seekToCommand, getPlaybackState, and getLength. getCommandCount, getCommandInfo, getCommandString, and getCommandAtTime inspect the capture, and setBankPath redirects its bank loads.
The per-command callbacks (create instance, frame, load bank) cannot be bound, FMOD runs them on its update thread while the replay plays and no Haxe target can execute code there.
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
