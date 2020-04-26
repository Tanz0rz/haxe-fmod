# faxe 2.0
An updated version of the faxe FMOD Audio Engine for HaxeFlixel (more general Haxe support will come later)

This library was mostly completed by Aaron Shea and uhrobots. I have updated it to work with Windows FMOD API v2.00.08 on Haxe v4.x.x

Features added: 
- Live Update is now available
- Windows 2.00.08 compatibility

Features started:
- User-friendly client to interact with the FMOD API in a reasonable way

Repo notes:

The `standalone-tests` directory holds some code that can be used to build a simple non-game example executable that reads a bank, plays music from it, and interacts with parameters.

To compile it, `cd` into that directory and run: `haxe --cpp ../build --main MainTest.hx -p ../`

This will create a `build` directory at the root of the repo. For this test executable to do anything, you will need to create a bank using FMOD Studio 2.00.08 and place it in the `build` directory too. For further debugging, there is a boolean inside `link_faxe.cpp` that can be used to get print statements to the console as it runs. Remember to recompile the example every time you change this boolean.

LICENCE : MIT