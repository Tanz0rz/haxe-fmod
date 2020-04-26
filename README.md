# faxe 2.0
An updated version of the faxe FMOD Audio Engine for HaxeFlixel Windows deployments. I plan to decouple this from the flixel package eventually and want to dig into the html5 integration too. 

Note: This library will likely undergo many breaking changes early on

This library was mostly completed by Aaron Shea and uhrobots. I have updated it to work with Windows FMOD API v2.00.08 on Haxe v4.x.x

Tested compatibility:
- Haxe 4.x.x
- FMOD Studio 2.00.08

Features added: 
- Live Update is now available
- HaxeSoundHelper library to abstract away some low-level API calls and support music-fading state transitions

Repo notes:

- Songs should be placed inside a folder titled "Music" in your FMOD Studio project
- Sound effects should be placed inside a folder titled "SFX" in your FMOD Studio project

The FMOD engine needs a constant stream of update calls to function properly. If this is not present in your game, it will seem like the engine is either buggy or simply not working at all. You can manage these update calls by following one of these two patterns:
- Call `add(new FaxeUpdater())` in the create method of every state
- Call `FaxeSoundHelper.GetInstance().Update()` in the update method of every state

When using Live Update, turn the auto-reconnect feature off or your game will not start. Hopefully that can be improved fairly easily.

The `standalone-tests` directory holds some code that can be used to build a simple non-game example executable that reads a bank, plays music from it, and interacts with parameters.

To compile it, `cd` into that directory and run: `haxe --cpp ../build --main MainTest.hx -p ../`

This will create a `build` directory at the root of the repo. For this test executable to do anything, you will need to create a bank using FMOD Studio 2.00.08 and place it in the `build` directory too. For further debugging, there is a boolean inside `link_faxe.cpp` that can be used to get print statements to the console as it runs. Remember to recompile the example every time you change this boolean.

LICENCE : MIT