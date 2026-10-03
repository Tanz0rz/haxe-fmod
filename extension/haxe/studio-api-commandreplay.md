# studio-api-commandreplay

## FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK
verdict: cannot FMOD invokes it from its Studio update thread while the replay plays, and no Haxe target can run code there. The replay creates the instances itself, and CommandReplay.getCommandInfo reads each command from the game thread.

## FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK
verdict: cannot FMOD invokes it from its Studio update thread while the replay plays, and no Haxe target can run code there. Poll CommandReplay.getCurrentCommand from the game thread for the index and time the replay is on.

## FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK
verdict: cannot FMOD invokes it from its Studio update thread while the replay plays, and no Haxe target can run code there. The replay loads the captured banks itself, and CommandReplay.setBankPath redirects where it reads them from.

## FMOD_STUDIO_COMMAND_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodCommandInfo

## FMOD_STUDIO_INSTANCETYPE
verdict: bound
Type: haxefmod.studio.Types.FmodStudioInstanceType
