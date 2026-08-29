# plugin-api-output

## FMOD_OUTPUT_ALLOC_FUNC
verdict: cannot a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it

## FMOD_OUTPUT_CLOSEPORT_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_CLOSE_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_COPYPORT_FUNC
verdict: cannot a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it

## FMOD_OUTPUT_DESCRIPTION
verdict: cannot output plugins are written in C, FMOD initializes the platform's default output and StudioSystem.loadPlugin with CoreSystem.setOutputByPlugin selects a compiled one

## FMOD_OUTPUT_DESCRIPTION#2
verdict: cannot FMODGetOutputDescription is the export of a compiled plugin library, a plugin built this way is loaded with StudioSystem.loadPlugin and selected with CoreSystem.setOutputByPlugin

## FMOD_OUTPUT_DEVICELISTCHANGED_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_FREE_FUNC
verdict: cannot a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it

## FMOD_OUTPUT_GETDRIVERINFO_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_GETHANDLE_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_GETNUMDRIVERS_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_INIT_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_LOG_FUNC
verdict: cannot a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it

## FMOD_OUTPUT_METHOD
verdict: bound
Type: haxefmod.studio.Types.FmodOutputMethod

## FMOD_OUTPUT_MIXER_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_OBJECT3DALLOC_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_OBJECT3DFREE_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_OBJECT3DGETINFO_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_OBJECT3DINFO
verdict: cannot filled by FMOD for an output plugin's object3dupdate callback on the mixer thread, plugin authoring is C only

## FMOD_OUTPUT_OBJECT3DUPDATE_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_OPENPORT_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_PLUGIN_VERSION
verdict: cannot the apiversion a compiled output plugin reports in its C description, no Haxe code writes one

## FMOD_OUTPUT_READFROMMIXER_FUNC
verdict: cannot a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it

## FMOD_OUTPUT_REQUESTRESET_FUNC
verdict: cannot a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it

## FMOD_OUTPUT_START_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_STATE
verdict: cannot the per instance state FMOD passes to an output plugin's C callbacks, plugin authoring is C only

## FMOD_OUTPUT_STOP_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only

## FMOD_OUTPUT_UPDATE_CALLBACK
verdict: cannot runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only
