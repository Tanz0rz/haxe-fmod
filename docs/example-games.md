# Example Games

This is a barebones FMOD adaptation of EZPlatformer from the HaxeFlixel demos repo (found [here](https://github.com/HaxeFlixel/flixel-demos/tree/dev/Platformers/EZPlatformer)) and has been built in each supported engine.

Move with the arrow keys or A and D. Jump with Space, Up or W. Collect every coin and then reach the exit.

- The game's music is played via `FmodManager.PlaySong`.
- The jump sound is played via `FmodManager.PlayOneShot`.
- When coins are collected, they set a decaying value on the song event called `FadeArpIn` using `FmodManager.SetSongParameter`. This value slowly fades to zero as you stop collecting coins.
- Clicking outside the game window pauses it and activates a high-pass filter (setting `HighPass` on the song event using the same `FmodManager.SetSongParameter`) to muffle the song until you click back into the game window again.

=== "HaxeFlixel"

    <div class="example-game" data-game="haxeflixel" data-title="EZPlatformer, the HaxeFlixel example game"></div>

    [HaxeFlixel source code](https://github.com/Tanz0rz/haxe-fmod/blob/master/example-project/EZPlatformer/source/PlayableState.hx)

=== "Heaps"

    <div class="example-game" data-game="heaps" data-title="HeapsPlatformer, the Heaps example game"></div>

    [Heaps source code](https://github.com/Tanz0rz/haxe-fmod/blob/master/example-project/HeapsPlatformer/src/PlayableScene.hx)

=== "Kha"

    <div class="example-game" data-game="kha" data-title="KhaPlatformer, the Kha example game"></div>

    [Kha source code](https://github.com/Tanz0rz/haxe-fmod/blob/master/example-project/KhaPlatformer/src/PlayableScene.hx)
