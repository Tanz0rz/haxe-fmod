# Coverage

Every FMOD function the native layer calls, with the haxefmod methods that reach it. Generated from the sources by `ci/haxe-bindings.py` for haxefmod 2.0.0 against FMOD 2.03.12. Functions absent from this list are not exposed, see [Limitations](limitations.md).

518 FMOD functions are reached.

The same table powers the browser extension that adds a Haxe tab to the [fmod.com API reference](https://www.fmod.com/docs/2.03/api/welcome.html). In the HTML5 column, "compile error" marks a call a js build refuses unless the project sets `-D haxefmod_html5_allow_unsupported`, after which it returns `FMOD_ERR_UNSUPPORTED` at runtime, and "limited" marks a call the web build only partly supports.

## Channel

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Channel_AddDSP` | `Channel.addDsp` |  |
| `FMOD_Channel_AddFadePoint` | `Channel.addFadePoint` |  |
| `FMOD_Channel_Get3DAttributes` | `Channel.get3DAttributes` |  |
| `FMOD_Channel_Get3DConeOrientation` | `Channel.get3DConeOrientation` |  |
| `FMOD_Channel_Get3DConeSettings` | `Channel.get3DConeSettings` |  |
| `FMOD_Channel_Get3DCustomRolloff` | `Channel.get3DCustomRolloff` | compile error |
| `FMOD_Channel_Get3DDistanceFilter` | `Channel.get3DDistanceFilter` |  |
| `FMOD_Channel_Get3DDopplerLevel` | `Channel.get3DDopplerLevel` |  |
| `FMOD_Channel_Get3DLevel` | `Channel.get3DLevel` |  |
| `FMOD_Channel_Get3DMinMaxDistance` | `Channel.get3DMinMaxDistance` |  |
| `FMOD_Channel_Get3DOcclusion` | `Channel.get3DOcclusion` |  |
| `FMOD_Channel_Get3DSpread` | `Channel.get3DSpread` |  |
| `FMOD_Channel_GetAudibility` | `Channel.getAudibility` |  |
| `FMOD_Channel_GetChannelGroup` | `Channel.getChannelGroup` |  |
| `FMOD_Channel_GetCurrentSound` | `Channel.getCurrentSound` |  |
| `FMOD_Channel_GetDSP` | `Channel.getDsp` |  |
| `FMOD_Channel_GetDSPClock` | `Channel.getDspClock` |  |
| `FMOD_Channel_GetDSPIndex` | `Channel.getDspIndex` |  |
| `FMOD_Channel_GetDelay` | `Channel.getDelay` |  |
| `FMOD_Channel_GetFadePoints` | `Channel.getFadePoints` | compile error |
| `FMOD_Channel_GetFrequency` | `Channel.getFrequency` |  |
| `FMOD_Channel_GetIndex` | `Channel.getIndex` |  |
| `FMOD_Channel_GetLoopCount` | `Channel.getLoopCount` |  |
| `FMOD_Channel_GetLoopPoints` | `Channel.getLoopPoints` |  |
| `FMOD_Channel_GetLowPassGain` | `Channel.getLowPassGain` |  |
| `FMOD_Channel_GetMixMatrix` | `Channel.getMixMatrix` | compile error |
| `FMOD_Channel_GetMode` | `Channel.getMode` |  |
| `FMOD_Channel_GetMute` | `Channel.getMute` |  |
| `FMOD_Channel_GetNumDSPs` | `Channel.getDspCount` |  |
| `FMOD_Channel_GetPaused` | `Channel.getPaused` |  |
| `FMOD_Channel_GetPitch` | `Channel.getPitch` |  |
| `FMOD_Channel_GetPosition` | `Channel.getPosition` |  |
| `FMOD_Channel_GetPriority` | `Channel.getPriority` |  |
| `FMOD_Channel_GetReverbProperties` | `Channel.getReverbWet` |  |
| `FMOD_Channel_GetUserData` | `Channel.getUserData` |  |
| `FMOD_Channel_GetVolume` | `Channel.getVolume` |  |
| `FMOD_Channel_GetVolumeRamp` | `Channel.getVolumeRamp` |  |
| `FMOD_Channel_IsPlaying` | `Channel.isPlaying` |  |
| `FMOD_Channel_IsVirtual` | `Channel.isVirtual` |  |
| `FMOD_Channel_RemoveDSP` | `Channel.removeDsp` |  |
| `FMOD_Channel_RemoveFadePoints` | `Channel.removeFadePoints` |  |
| `FMOD_Channel_Set3DAttributes` | `Channel.set3DAttributes` |  |
| `FMOD_Channel_Set3DConeOrientation` | `Channel.set3DConeOrientation` |  |
| `FMOD_Channel_Set3DConeSettings` | `Channel.set3DConeSettings` |  |
| `FMOD_Channel_Set3DCustomRolloff` | `Channel.set3DCustomRolloff` | compile error |
| `FMOD_Channel_Set3DDistanceFilter` | `Channel.set3DDistanceFilter` |  |
| `FMOD_Channel_Set3DDopplerLevel` | `Channel.set3DDopplerLevel` |  |
| `FMOD_Channel_Set3DLevel` | `Channel.set3DLevel` |  |
| `FMOD_Channel_Set3DMinMaxDistance` | `Channel.set3DMinMaxDistance` |  |
| `FMOD_Channel_Set3DOcclusion` | `Channel.set3DOcclusion` |  |
| `FMOD_Channel_Set3DSpread` | `Channel.set3DSpread` |  |
| `FMOD_Channel_SetCallback` | `Channel.setCallback`<br>`Channel.clearCallback` |  |
| `FMOD_Channel_SetChannelGroup` | `Channel.setChannelGroup` |  |
| `FMOD_Channel_SetDSPIndex` | `Channel.setDspIndex` |  |
| `FMOD_Channel_SetDelay` | `Channel.setDelay` |  |
| `FMOD_Channel_SetFadePointRamp` | `Channel.setFadePointRamp` |  |
| `FMOD_Channel_SetFrequency` | `Channel.setFrequency` |  |
| `FMOD_Channel_SetLoopCount` | `Channel.setLoopCount` |  |
| `FMOD_Channel_SetLoopPoints` | `Channel.setLoopPoints` |  |
| `FMOD_Channel_SetLowPassGain` | `Channel.setLowPassGain` |  |
| `FMOD_Channel_SetMixLevelsInput` | `Channel.setMixLevelsInput` |  |
| `FMOD_Channel_SetMixLevelsOutput` | `Channel.setMixLevelsOutput` |  |
| `FMOD_Channel_SetMixMatrix` | `Channel.setMixMatrix` |  |
| `FMOD_Channel_SetMode` | `Channel.setMode` |  |
| `FMOD_Channel_SetMute` | `Channel.setMute` |  |
| `FMOD_Channel_SetPan` | `Channel.setPan` |  |
| `FMOD_Channel_SetPaused` | `Channel.setPaused` |  |
| `FMOD_Channel_SetPitch` | `Channel.setPitch` |  |
| `FMOD_Channel_SetPosition` | `Channel.setPosition` |  |
| `FMOD_Channel_SetPriority` | `Channel.setPriority` |  |
| `FMOD_Channel_SetReverbProperties` | `Channel.setReverbWet` |  |
| `FMOD_Channel_SetUserData` | `Channel.setUserData` |  |
| `FMOD_Channel_SetVolume` | `Channel.setVolume` |  |
| `FMOD_Channel_SetVolumeRamp` | `Channel.setVolumeRamp` |  |
| `FMOD_Channel_Stop` | `Channel.stop`<br>`Dsp.play`<br>`PcmStream.play`<br>`Sound.play` |  |

## ChannelGroup

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_ChannelGroup_AddDSP` | `ChannelGroup.addDsp` |  |
| `FMOD_ChannelGroup_AddFadePoint` | `ChannelGroup.addFadePoint` |  |
| `FMOD_ChannelGroup_AddGroup` | `ChannelGroup.addGroup`<br>`ChannelGroup.addGroupConnection` |  |
| `FMOD_ChannelGroup_Get3DAttributes` | `ChannelGroup.get3DAttributes` |  |
| `FMOD_ChannelGroup_Get3DConeOrientation` | `ChannelGroup.get3DConeOrientation` |  |
| `FMOD_ChannelGroup_Get3DConeSettings` | `ChannelGroup.get3DConeSettings` |  |
| `FMOD_ChannelGroup_Get3DCustomRolloff` | `ChannelGroup.get3DCustomRolloff` | compile error |
| `FMOD_ChannelGroup_Get3DDistanceFilter` | `ChannelGroup.get3DDistanceFilter` |  |
| `FMOD_ChannelGroup_Get3DDopplerLevel` | `ChannelGroup.get3DDopplerLevel` |  |
| `FMOD_ChannelGroup_Get3DLevel` | `ChannelGroup.get3DLevel` |  |
| `FMOD_ChannelGroup_Get3DMinMaxDistance` | `ChannelGroup.get3DMinMaxDistance` |  |
| `FMOD_ChannelGroup_Get3DOcclusion` | `ChannelGroup.get3DOcclusion` |  |
| `FMOD_ChannelGroup_Get3DSpread` | `ChannelGroup.get3DSpread` |  |
| `FMOD_ChannelGroup_GetAudibility` | `ChannelGroup.getAudibility` |  |
| `FMOD_ChannelGroup_GetChannel` | `ChannelGroup.getChannel` |  |
| `FMOD_ChannelGroup_GetDSP` | `ChannelGroup.getDsp` |  |
| `FMOD_ChannelGroup_GetDSPClock` | `ChannelGroup.getDspClock` |  |
| `FMOD_ChannelGroup_GetDSPIndex` | `ChannelGroup.getDspIndex` |  |
| `FMOD_ChannelGroup_GetDelay` | `ChannelGroup.getDelay` |  |
| `FMOD_ChannelGroup_GetFadePoints` | `ChannelGroup.getFadePoints` | compile error |
| `FMOD_ChannelGroup_GetGroup` | `ChannelGroup.getGroup` |  |
| `FMOD_ChannelGroup_GetLowPassGain` | `ChannelGroup.getLowPassGain` |  |
| `FMOD_ChannelGroup_GetMixMatrix` | `ChannelGroup.getMixMatrix` | compile error |
| `FMOD_ChannelGroup_GetMode` | `ChannelGroup.getMode` |  |
| `FMOD_ChannelGroup_GetMute` | `ChannelGroup.getMute` |  |
| `FMOD_ChannelGroup_GetName` | `ChannelGroup.getName` |  |
| `FMOD_ChannelGroup_GetNumChannels` | `ChannelGroup.getChannelCount` |  |
| `FMOD_ChannelGroup_GetNumDSPs` | `ChannelGroup.getDspCount` |  |
| `FMOD_ChannelGroup_GetNumGroups` | `ChannelGroup.getGroupCount` |  |
| `FMOD_ChannelGroup_GetParentGroup` | `ChannelGroup.getParentGroup` |  |
| `FMOD_ChannelGroup_GetPaused` | `ChannelGroup.getPaused` |  |
| `FMOD_ChannelGroup_GetPitch` | `ChannelGroup.getPitch` |  |
| `FMOD_ChannelGroup_GetReverbProperties` | `ChannelGroup.getReverbWet` |  |
| `FMOD_ChannelGroup_GetUserData` | `ChannelGroup.getUserData` |  |
| `FMOD_ChannelGroup_GetVolume` | `ChannelGroup.getVolume` |  |
| `FMOD_ChannelGroup_GetVolumeRamp` | `ChannelGroup.getVolumeRamp` |  |
| `FMOD_ChannelGroup_IsPlaying` | `ChannelGroup.isPlaying` |  |
| `FMOD_ChannelGroup_Release` | `ChannelGroup.release`<br>`ChannelGroup.create` |  |
| `FMOD_ChannelGroup_RemoveDSP` | `ChannelGroup.removeDsp` |  |
| `FMOD_ChannelGroup_RemoveFadePoints` | `ChannelGroup.removeFadePoints` |  |
| `FMOD_ChannelGroup_Set3DAttributes` | `ChannelGroup.set3DAttributes` |  |
| `FMOD_ChannelGroup_Set3DConeOrientation` | `ChannelGroup.set3DConeOrientation` |  |
| `FMOD_ChannelGroup_Set3DConeSettings` | `ChannelGroup.set3DConeSettings` |  |
| `FMOD_ChannelGroup_Set3DCustomRolloff` | `ChannelGroup.set3DCustomRolloff` | compile error |
| `FMOD_ChannelGroup_Set3DDistanceFilter` | `ChannelGroup.set3DDistanceFilter` |  |
| `FMOD_ChannelGroup_Set3DDopplerLevel` | `ChannelGroup.set3DDopplerLevel` |  |
| `FMOD_ChannelGroup_Set3DLevel` | `ChannelGroup.set3DLevel` |  |
| `FMOD_ChannelGroup_Set3DMinMaxDistance` | `ChannelGroup.set3DMinMaxDistance` |  |
| `FMOD_ChannelGroup_Set3DOcclusion` | `ChannelGroup.set3DOcclusion` |  |
| `FMOD_ChannelGroup_Set3DSpread` | `ChannelGroup.set3DSpread` |  |
| `FMOD_ChannelGroup_SetCallback` | `ChannelGroup.setCallback`<br>`ChannelGroup.clearCallback` |  |
| `FMOD_ChannelGroup_SetDSPIndex` | `ChannelGroup.setDspIndex` |  |
| `FMOD_ChannelGroup_SetDelay` | `ChannelGroup.setDelay` |  |
| `FMOD_ChannelGroup_SetFadePointRamp` | `ChannelGroup.setFadePointRamp` |  |
| `FMOD_ChannelGroup_SetLowPassGain` | `ChannelGroup.setLowPassGain` |  |
| `FMOD_ChannelGroup_SetMixLevelsInput` | `ChannelGroup.setMixLevelsInput` |  |
| `FMOD_ChannelGroup_SetMixLevelsOutput` | `ChannelGroup.setMixLevelsOutput` |  |
| `FMOD_ChannelGroup_SetMixMatrix` | `ChannelGroup.setMixMatrix` |  |
| `FMOD_ChannelGroup_SetMode` | `ChannelGroup.setMode` |  |
| `FMOD_ChannelGroup_SetMute` | `ChannelGroup.setMute` |  |
| `FMOD_ChannelGroup_SetPan` | `ChannelGroup.setPan` |  |
| `FMOD_ChannelGroup_SetPaused` | `ChannelGroup.setPaused` |  |
| `FMOD_ChannelGroup_SetPitch` | `ChannelGroup.setPitch` |  |
| `FMOD_ChannelGroup_SetReverbProperties` | `ChannelGroup.setReverbWet` |  |
| `FMOD_ChannelGroup_SetUserData` | `ChannelGroup.setUserData` |  |
| `FMOD_ChannelGroup_SetVolume` | `ChannelGroup.setVolume` |  |
| `FMOD_ChannelGroup_SetVolumeRamp` | `ChannelGroup.setVolumeRamp` |  |
| `FMOD_ChannelGroup_Stop` | `ChannelGroup.stop` |  |

## DSP

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_DSP_AddInput` | `Dsp.addInput` |  |
| `FMOD_DSP_AddInputPreallocated` | `Dsp.addInputPreallocated` | compile error |
| `FMOD_DSP_DisconnectAll` | `Dsp.disconnectAll` |  |
| `FMOD_DSP_DisconnectFrom` | `Dsp.disconnectFrom` |  |
| `FMOD_DSP_GetActive` | `Dsp.getActive` |  |
| `FMOD_DSP_GetBypass` | `Dsp.getBypass` |  |
| `FMOD_DSP_GetCPUUsage` | `Dsp.getCpuUsage` |  |
| `FMOD_DSP_GetChannelFormat` | `Dsp.getChannelFormat` |  |
| `FMOD_DSP_GetDataParameterIndex` | `Dsp.getDataParameterIndex` |  |
| `FMOD_DSP_GetIdle` | `Dsp.isIdle` |  |
| `FMOD_DSP_GetInfo` | `Dsp.getName` |  |
| `FMOD_DSP_GetInput` | `Dsp.getInput`<br>`Dsp.getInputConnection` |  |
| `FMOD_DSP_GetMeteringEnabled` | `Dsp.getMeteringEnabled` |  |
| `FMOD_DSP_GetMeteringInfo` | `Dsp.getMetering` |  |
| `FMOD_DSP_GetNumInputs` | `Dsp.getInputCount` |  |
| `FMOD_DSP_GetNumOutputs` | `Dsp.getOutputCount` |  |
| `FMOD_DSP_GetNumParameters` | `Dsp.getParameterCount` |  |
| `FMOD_DSP_GetOutput` | `Dsp.getOutput`<br>`Dsp.getOutputConnection` |  |
| `FMOD_DSP_GetOutputChannelFormat` | `Dsp.getOutputChannelFormat` |  |
| `FMOD_DSP_GetParameterBool` | `Dsp.getParameterBool` |  |
| `FMOD_DSP_GetParameterData` | `Dsp.getFftSpectrum` |  |
| `FMOD_DSP_GetParameterFloat` | `Dsp.getParameter` |  |
| `FMOD_DSP_GetParameterInfo` | `Dsp.getParameterInfo` | compile error |
| `FMOD_DSP_GetParameterInt` | `Dsp.getParameterInt` |  |
| `FMOD_DSP_GetType` | `Dsp.getType` |  |
| `FMOD_DSP_GetUserData` | `Dsp.getUserData` |  |
| `FMOD_DSP_GetWetDryMix` | `Dsp.getWetDryMix` |  |
| `FMOD_DSP_Release` | `Dsp.release`<br>`Dsp.create`<br>`Dsp.createByPlugin` | compile error |
| `FMOD_DSP_Reset` | `Dsp.reset` |  |
| `FMOD_DSP_SetActive` | `Dsp.setActive` |  |
| `FMOD_DSP_SetBypass` | `Dsp.setBypass` |  |
| `FMOD_DSP_SetChannelFormat` | `Dsp.setChannelFormat` |  |
| `FMOD_DSP_SetMeteringEnabled` | `Dsp.setMeteringEnabled` |  |
| `FMOD_DSP_SetParameterBool` | `Dsp.setParameterBool` |  |
| `FMOD_DSP_SetParameterData` | `Dsp.setParameterData` |  |
| `FMOD_DSP_SetParameterFloat` | `Dsp.setParameter` |  |
| `FMOD_DSP_SetParameterInt` | `Dsp.setParameterInt` |  |
| `FMOD_DSP_SetUserData` | `Dsp.setUserData` |  |
| `FMOD_DSP_SetWetDryMix` | `Dsp.setWetDryMix` |  |

## DSPConnection

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_DSPConnection_GetInput` | `DspConnection.getInputDsp` |  |
| `FMOD_DSPConnection_GetMix` | `DspConnection.getMix` |  |
| `FMOD_DSPConnection_GetMixMatrix` | `DspConnection.getMixMatrix` | compile error |
| `FMOD_DSPConnection_GetOutput` | `DspConnection.getOutputDsp` |  |
| `FMOD_DSPConnection_GetType` | `DspConnection.getType` |  |
| `FMOD_DSPConnection_GetUserData` | `DspConnection.getUserData` |  |
| `FMOD_DSPConnection_SetMix` | `DspConnection.setMix` |  |
| `FMOD_DSPConnection_SetMixMatrix` | `DspConnection.setMixMatrix` |  |
| `FMOD_DSPConnection_SetUserData` | `DspConnection.setUserData` |  |

## Debug

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Debug_Initialize` | `FmodManager.Initialize`<br>`FmodManager.EnableDebugMessages`<br>`FmodRuntime.init` | limited |

## Geometry

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Geometry_AddPolygon` | `Geometry.addPolygon` | compile error |
| `FMOD_Geometry_GetActive` | `Geometry.getActive` | compile error |
| `FMOD_Geometry_GetMaxPolygons` | `Geometry.getMaxPolygons` | compile error |
| `FMOD_Geometry_GetNumPolygons` | `Geometry.getNumPolygons` | compile error |
| `FMOD_Geometry_GetPolygonAttributes` | `Geometry.getPolygonAttributes` | compile error |
| `FMOD_Geometry_GetPolygonNumVertices` | `Geometry.getPolygonNumVertices` | compile error |
| `FMOD_Geometry_GetPolygonVertex` | `Geometry.getPolygonVertex` | compile error |
| `FMOD_Geometry_GetPosition` | `Geometry.getPosition` | compile error |
| `FMOD_Geometry_GetRotation` | `Geometry.getRotation` | compile error |
| `FMOD_Geometry_GetScale` | `Geometry.getScale` | compile error |
| `FMOD_Geometry_GetUserData` | `Geometry.getUserData` |  |
| `FMOD_Geometry_Release` | `Geometry.release`<br>`Geometry.create`<br>`Geometry.load` | compile error |
| `FMOD_Geometry_Save` | `Geometry.save` | compile error |
| `FMOD_Geometry_SetActive` | `Geometry.setActive` | compile error |
| `FMOD_Geometry_SetPolygonAttributes` | `Geometry.setPolygonAttributes` | compile error |
| `FMOD_Geometry_SetPolygonVertex` | `Geometry.setPolygonVertex` | compile error |
| `FMOD_Geometry_SetPosition` | `Geometry.setPosition` | compile error |
| `FMOD_Geometry_SetRotation` | `Geometry.setRotation` | compile error |
| `FMOD_Geometry_SetScale` | `Geometry.setScale` | compile error |
| `FMOD_Geometry_SetUserData` | `Geometry.setUserData` |  |

## Memory

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Memory_GetStats` | `StudioSystem.getMemoryStats` |  |

## Reverb3D

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Reverb3D_Get3DAttributes` | `Reverb3D.get3DAttributes` |  |
| `FMOD_Reverb3D_GetActive` | `Reverb3D.getActive` |  |
| `FMOD_Reverb3D_GetProperties` | `Reverb3D.getProperties` |  |
| `FMOD_Reverb3D_GetUserData` | `Reverb3D.getUserData` |  |
| `FMOD_Reverb3D_Release` | `Reverb3D.release`<br>`Reverb3D.create` |  |
| `FMOD_Reverb3D_Set3DAttributes` | `Reverb3D.set3DAttributes` |  |
| `FMOD_Reverb3D_SetActive` | `Reverb3D.setActive` |  |
| `FMOD_Reverb3D_SetProperties` | `Reverb3D.setProperties` |  |
| `FMOD_Reverb3D_SetUserData` | `Reverb3D.setUserData` |  |

## Sound

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Sound_AddSyncPoint` | `Sound.addSyncPoint` |  |
| `FMOD_Sound_DeleteSyncPoint` | `Sound.deleteSyncPoint` |  |
| `FMOD_Sound_Get3DConeSettings` | `Sound.get3DConeSettings` |  |
| `FMOD_Sound_Get3DCustomRolloff` | `Sound.get3DCustomRolloff` | compile error |
| `FMOD_Sound_Get3DMinMaxDistance` | `Sound.get3DMinMaxDistance` |  |
| `FMOD_Sound_GetDefaults` | `Sound.getDefaults` |  |
| `FMOD_Sound_GetFormat` | `Sound.getFormat` |  |
| `FMOD_Sound_GetLength` | `Sound.getLength` |  |
| `FMOD_Sound_GetLoopCount` | `Sound.getLoopCount` |  |
| `FMOD_Sound_GetLoopPoints` | `Sound.getLoopPoints` |  |
| `FMOD_Sound_GetMode` | `Sound.getMode` |  |
| `FMOD_Sound_GetMusicChannelVolume` | `Sound.getMusicChannelVolume` | compile error |
| `FMOD_Sound_GetMusicNumChannels` | `Sound.getMusicNumChannels` | compile error |
| `FMOD_Sound_GetMusicSpeed` | `Sound.getMusicSpeed` | compile error |
| `FMOD_Sound_GetName` | `Sound.getName` |  |
| `FMOD_Sound_GetNumSubSounds` | `Sound.getNumSubSounds` |  |
| `FMOD_Sound_GetNumSyncPoints` | `Sound.getSyncPointCount` |  |
| `FMOD_Sound_GetNumTags` | `Sound.getNumTags`<br>`Sound.getNumTagsUpdated` |  |
| `FMOD_Sound_GetOpenState` | `Sound.getOpenState` |  |
| `FMOD_Sound_GetSoundGroup` | `Sound.getSoundGroup` |  |
| `FMOD_Sound_GetSubSound` | `Sound.getSubSound` |  |
| `FMOD_Sound_GetSubSoundParent` | `Sound.getSubSoundParent`<br>`Sound.release` |  |
| `FMOD_Sound_GetSyncPoint` | `Sound.deleteSyncPoint`<br>`Sound.getSyncPointName`<br>`Sound.getSyncPointOffset` |  |
| `FMOD_Sound_GetSyncPointInfo` | `Sound.getSyncPointName`<br>`Sound.getSyncPointOffset` |  |
| `FMOD_Sound_GetTag` | `Sound.getTag` | compile error |
| `FMOD_Sound_GetUserData` | `PcmStream.getUserData`<br>`Sound.getUserData` |  |
| `FMOD_Sound_ReadData` | `Sound.readData` | compile error |
| `FMOD_Sound_Release` | `PcmStream.release`<br>`Sound.release`<br>`PcmStream.create`<br>`PcmStream.create3d`<br>`Sound.create`<br>`Sound.createRecordBuffer`<br>`Sound.fromPcm` | compile error |
| `FMOD_Sound_SeekData` | `Sound.seekData` | compile error |
| `FMOD_Sound_Set3DConeSettings` | `Sound.set3DConeSettings` |  |
| `FMOD_Sound_Set3DCustomRolloff` | `Sound.set3DCustomRolloff` | compile error |
| `FMOD_Sound_Set3DMinMaxDistance` | `Sound.set3DMinMaxDistance` |  |
| `FMOD_Sound_SetDefaults` | `Sound.setDefaults` |  |
| `FMOD_Sound_SetLoopCount` | `Sound.setLoopCount` |  |
| `FMOD_Sound_SetLoopPoints` | `Sound.setLoopPoints` |  |
| `FMOD_Sound_SetMode` | `Sound.setMode` |  |
| `FMOD_Sound_SetMusicChannelVolume` | `Sound.setMusicChannelVolume` | compile error |
| `FMOD_Sound_SetMusicSpeed` | `Sound.setMusicSpeed` | compile error |
| `FMOD_Sound_SetSoundGroup` | `Sound.setSoundGroup` |  |
| `FMOD_Sound_SetUserData` | `PcmStream.setUserData`<br>`Sound.setUserData` |  |

## SoundGroup

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_SoundGroup_GetMaxAudible` | `SoundGroup.getMaxAudible` |  |
| `FMOD_SoundGroup_GetMaxAudibleBehavior` | `SoundGroup.getMaxAudibleBehavior` |  |
| `FMOD_SoundGroup_GetMuteFadeSpeed` | `SoundGroup.getMuteFadeSpeed` |  |
| `FMOD_SoundGroup_GetName` | `SoundGroup.getName` |  |
| `FMOD_SoundGroup_GetNumPlaying` | `SoundGroup.getPlayingCount` |  |
| `FMOD_SoundGroup_GetNumSounds` | `SoundGroup.getSoundCount` |  |
| `FMOD_SoundGroup_GetSound` | `SoundGroup.getSound` |  |
| `FMOD_SoundGroup_GetUserData` | `SoundGroup.getUserData` |  |
| `FMOD_SoundGroup_GetVolume` | `SoundGroup.getVolume` |  |
| `FMOD_SoundGroup_Release` | `SoundGroup.release`<br>`SoundGroup.create` |  |
| `FMOD_SoundGroup_SetMaxAudible` | `SoundGroup.setMaxAudible` |  |
| `FMOD_SoundGroup_SetMaxAudibleBehavior` | `SoundGroup.setMaxAudibleBehavior` |  |
| `FMOD_SoundGroup_SetMuteFadeSpeed` | `SoundGroup.setMuteFadeSpeed` |  |
| `FMOD_SoundGroup_SetUserData` | `SoundGroup.setUserData` |  |
| `FMOD_SoundGroup_SetVolume` | `SoundGroup.setVolume` |  |
| `FMOD_SoundGroup_Stop` | `SoundGroup.stop` |  |

## Studio::Bank

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_Bank_GetBusCount` | `Bank.getBusCount` |  |
| `FMOD_Studio_Bank_GetBusList` | `Bank.getBusList` |  |
| `FMOD_Studio_Bank_GetEventCount` | `Bank.getEventCount` |  |
| `FMOD_Studio_Bank_GetEventList` | `Bank.getEventList` |  |
| `FMOD_Studio_Bank_GetID` | `Bank.getID` | limited |
| `FMOD_Studio_Bank_GetLoadingState` | `Bank.getLoadingState` |  |
| `FMOD_Studio_Bank_GetPath` | `Bank.getPath`<br>`Bank.unload`<br>`StudioSystem.unloadAll` |  |
| `FMOD_Studio_Bank_GetSampleLoadingState` | `Bank.getSampleLoadingState` |  |
| `FMOD_Studio_Bank_GetStringCount` | `Bank.getStringCount` |  |
| `FMOD_Studio_Bank_GetStringInfo` | `Bank.getStringGuid`<br>`Bank.getStringPath` |  |
| `FMOD_Studio_Bank_GetUserData` | `Bank.getUserData` |  |
| `FMOD_Studio_Bank_GetVCACount` | `Bank.getVCACount` |  |
| `FMOD_Studio_Bank_GetVCAList` | `Bank.getVCAList` |  |
| `FMOD_Studio_Bank_IsValid` | `Bank.isValid` |  |
| `FMOD_Studio_Bank_LoadSampleData` | `Bank.loadSampleData` |  |
| `FMOD_Studio_Bank_SetUserData` | `Bank.setUserData` |  |
| `FMOD_Studio_Bank_Unload` | `Bank.unload` |  |
| `FMOD_Studio_Bank_UnloadSampleData` | `Bank.unloadSampleData` |  |

## Studio::Bus

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_Bus_GetCPUUsage` | `Bus.getCpuUsage` | compile error |
| `FMOD_Studio_Bus_GetChannelGroup` | `Bus.getChannelGroup` |  |
| `FMOD_Studio_Bus_GetID` | `Bus.getID` | limited |
| `FMOD_Studio_Bus_GetMemoryUsage` | `Bus.getMemoryUsage` | compile error |
| `FMOD_Studio_Bus_GetMute` | `Bus.getMute` |  |
| `FMOD_Studio_Bus_GetPath` | `Bus.getPath` |  |
| `FMOD_Studio_Bus_GetPaused` | `Bus.getPaused` |  |
| `FMOD_Studio_Bus_GetVolume` | `Bus.getVolume`<br>`Bus.getFinalVolume` |  |
| `FMOD_Studio_Bus_IsValid` | `Bus.isValid` |  |
| `FMOD_Studio_Bus_LockChannelGroup` | `Bus.lockChannelGroup` |  |
| `FMOD_Studio_Bus_SetMute` | `Bus.setMute` |  |
| `FMOD_Studio_Bus_SetPaused` | `Bus.setPaused` |  |
| `FMOD_Studio_Bus_SetVolume` | `Bus.setVolume` |  |
| `FMOD_Studio_Bus_StopAllEvents` | `Bus.stopAllEvents` |  |
| `FMOD_Studio_Bus_UnlockChannelGroup` | `Bus.unlockChannelGroup` |  |

## Studio::CommandReplay

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_CommandReplay_GetCommandAtTime` | `CommandReplay.getCommandAtTime` |  |
| `FMOD_Studio_CommandReplay_GetCommandCount` | `CommandReplay.getCommandCount` |  |
| `FMOD_Studio_CommandReplay_GetCommandInfo` | `CommandReplay.getCommandInfo` |  |
| `FMOD_Studio_CommandReplay_GetCommandString` | `CommandReplay.getCommandString` |  |
| `FMOD_Studio_CommandReplay_GetCurrentCommand` | `CommandReplay.getCurrentCommand` |  |
| `FMOD_Studio_CommandReplay_GetLength` | `CommandReplay.getLength` |  |
| `FMOD_Studio_CommandReplay_GetPaused` | `CommandReplay.getPaused` |  |
| `FMOD_Studio_CommandReplay_GetPlaybackState` | `CommandReplay.getPlaybackState` |  |
| `FMOD_Studio_CommandReplay_GetUserData` | `CommandReplay.getUserData` |  |
| `FMOD_Studio_CommandReplay_IsValid` | `CommandReplay.isValid` |  |
| `FMOD_Studio_CommandReplay_Release` | `CommandReplay.release`<br>`StudioSystem.loadCommandReplay` |  |
| `FMOD_Studio_CommandReplay_SeekToCommand` | `CommandReplay.seekToCommand` |  |
| `FMOD_Studio_CommandReplay_SeekToTime` | `CommandReplay.seekToTime` |  |
| `FMOD_Studio_CommandReplay_SetBankPath` | `CommandReplay.setBankPath` |  |
| `FMOD_Studio_CommandReplay_SetPaused` | `CommandReplay.setPaused` |  |
| `FMOD_Studio_CommandReplay_SetUserData` | `CommandReplay.setUserData` |  |
| `FMOD_Studio_CommandReplay_Start` | `CommandReplay.start` |  |
| `FMOD_Studio_CommandReplay_Stop` | `CommandReplay.stop` |  |

## Studio::EventDescription

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_EventDescription_CreateInstance` | `EventDescription.createInstance` |  |
| `FMOD_Studio_EventDescription_GetID` | `EventDescription.getID` | limited |
| `FMOD_Studio_EventDescription_GetInstanceCount` | `EventDescription.getInstanceCount` |  |
| `FMOD_Studio_EventDescription_GetInstanceList` | `EventDescription.getInstanceList` |  |
| `FMOD_Studio_EventDescription_GetLength` | `EventDescription.getLength` |  |
| `FMOD_Studio_EventDescription_GetMinMaxDistance` | `EventDescription.getMinMaxDistance` |  |
| `FMOD_Studio_EventDescription_GetParameterDescriptionByIndex` | `EventDescription.getParameterDescriptionByIndex` |  |
| `FMOD_Studio_EventDescription_GetParameterDescriptionByName` | `EventDescription.getParameterDescriptionByName` |  |
| `FMOD_Studio_EventDescription_GetParameterDescriptionCount` | `EventDescription.getParameterDescriptionCount` |  |
| `FMOD_Studio_EventDescription_GetParameterLabelByName` | `EventDescription.getParameterLabel` |  |
| `FMOD_Studio_EventDescription_GetPath` | `EventDescription.getPath` |  |
| `FMOD_Studio_EventDescription_GetSampleLoadingState` | `EventDescription.getSampleLoadingState` |  |
| `FMOD_Studio_EventDescription_GetSoundSize` | `EventDescription.getSoundSize` |  |
| `FMOD_Studio_EventDescription_GetUserData` | `EventDescription.getUserData` |  |
| `FMOD_Studio_EventDescription_GetUserPropertyByIndex` | `EventDescription.getUserProperty` |  |
| `FMOD_Studio_EventDescription_GetUserPropertyCount` | `EventDescription.getUserPropertyCount` |  |
| `FMOD_Studio_EventDescription_HasSustainPoint` | `EventDescription.hasSustainPoint` |  |
| `FMOD_Studio_EventDescription_Is3D` | `EventDescription.is3D` |  |
| `FMOD_Studio_EventDescription_IsDopplerEnabled` | `EventDescription.isDopplerEnabled` |  |
| `FMOD_Studio_EventDescription_IsOneshot` | `EventDescription.isOneshot` |  |
| `FMOD_Studio_EventDescription_IsSnapshot` | `EventDescription.isSnapshot` |  |
| `FMOD_Studio_EventDescription_IsStream` | `EventDescription.isStream` |  |
| `FMOD_Studio_EventDescription_IsValid` | `EventDescription.isValid` |  |
| `FMOD_Studio_EventDescription_LoadSampleData` | `EventDescription.loadSampleData` |  |
| `FMOD_Studio_EventDescription_ReleaseAllInstances` | `EventDescription.releaseAllInstances` |  |
| `FMOD_Studio_EventDescription_SetUserData` | `EventDescription.setUserData` |  |
| `FMOD_Studio_EventDescription_UnloadSampleData` | `EventDescription.unloadSampleData` |  |

## Studio::EventInstance

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_EventInstance_Get3DAttributes` | `EventInstance.get3DAttributes` |  |
| `FMOD_Studio_EventInstance_GetCPUUsage` | `EventInstance.getCpuUsage` | compile error |
| `FMOD_Studio_EventInstance_GetChannelGroup` | `EventInstance.getChannelGroup` |  |
| `FMOD_Studio_EventInstance_GetDescription` | `EventInstance.getDescription` |  |
| `FMOD_Studio_EventInstance_GetListenerMask` | `EventInstance.getListenerMask` |  |
| `FMOD_Studio_EventInstance_GetMemoryUsage` | `EventInstance.getMemoryUsage` | compile error |
| `FMOD_Studio_EventInstance_GetMinMaxDistance` | `EventInstance.getMinMaxDistance` |  |
| `FMOD_Studio_EventInstance_GetParameterByID` | `EventInstance.getParameterByID`<br>`EventInstance.getParameterByIDFinal` |  |
| `FMOD_Studio_EventInstance_GetParameterByName` | `EventInstance.getParameter`<br>`EventInstance.getParameterFinal` |  |
| `FMOD_Studio_EventInstance_GetPaused` | `EventInstance.getPaused` |  |
| `FMOD_Studio_EventInstance_GetPitch` | `EventInstance.getPitch`<br>`EventInstance.getFinalPitch` |  |
| `FMOD_Studio_EventInstance_GetPlaybackState` | `EventInstance.getPlaybackState` |  |
| `FMOD_Studio_EventInstance_GetProperty` | `EventInstance.getProperty` |  |
| `FMOD_Studio_EventInstance_GetReverbLevel` | `EventInstance.getReverbLevel` |  |
| `FMOD_Studio_EventInstance_GetTimelinePosition` | `EventInstance.getTimelinePosition` |  |
| `FMOD_Studio_EventInstance_GetUserData` | `EventInstance.getUserData` |  |
| `FMOD_Studio_EventInstance_GetVolume` | `EventInstance.getVolume`<br>`EventInstance.getFinalVolume` |  |
| `FMOD_Studio_EventInstance_IsValid` | `EventInstance.isValid` |  |
| `FMOD_Studio_EventInstance_IsVirtual` | `EventInstance.isVirtual` |  |
| `FMOD_Studio_EventInstance_KeyOff` | `EventInstance.keyOff` |  |
| `FMOD_Studio_EventInstance_Release` | `EventInstance.release`<br>`EventDescription.createInstance` |  |
| `FMOD_Studio_EventInstance_Set3DAttributes` | `EventInstance.set3DAttributes`<br>`EventInstance.setPosition2D` |  |
| `FMOD_Studio_EventInstance_SetCallback` | `EventInstance.setCallback`<br>`EventDescription.createInstance`<br>`EventDescription.getInstanceList`<br>`EventInstance.assignProgrammerSound`<br>`EventInstance.clearProgrammerSound` | compile error |
| `FMOD_Studio_EventInstance_SetListenerMask` | `EventInstance.setListenerMask` |  |
| `FMOD_Studio_EventInstance_SetParameterByID` | `EventInstance.setParameterByID` |  |
| `FMOD_Studio_EventInstance_SetParameterByIDWithLabel` | `EventInstance.setParameterByIDWithLabel` |  |
| `FMOD_Studio_EventInstance_SetParameterByName` | `EventInstance.setParameter` |  |
| `FMOD_Studio_EventInstance_SetParameterByNameWithLabel` | `EventInstance.setParameterWithLabel` |  |
| `FMOD_Studio_EventInstance_SetPaused` | `EventInstance.setPaused` |  |
| `FMOD_Studio_EventInstance_SetPitch` | `EventInstance.setPitch` |  |
| `FMOD_Studio_EventInstance_SetProperty` | `EventInstance.setProperty` |  |
| `FMOD_Studio_EventInstance_SetReverbLevel` | `EventInstance.setReverbLevel` |  |
| `FMOD_Studio_EventInstance_SetTimelinePosition` | `EventInstance.setTimelinePosition` |  |
| `FMOD_Studio_EventInstance_SetUserData` | `EventInstance.setUserData` |  |
| `FMOD_Studio_EventInstance_SetVolume` | `EventInstance.setVolume` |  |
| `FMOD_Studio_EventInstance_Start` | `EventInstance.start` |  |
| `FMOD_Studio_EventInstance_Stop` | `EventInstance.stop` |  |

## Studio::System

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_System_Create` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_Studio_System_FlushCommands` | `StudioSystem.flushCommands`<br>`Bank.unload`<br>`Bus.lockChannelGroup`<br>`Bus.unlockChannelGroup`<br>`StudioSystem.unloadAll` |  |
| `FMOD_Studio_System_FlushSampleLoading` | `StudioSystem.flushSampleLoading` |  |
| `FMOD_Studio_System_GetAdvancedSettings` | `StudioSystem.getStudioAdvancedSettings`<br>`FmodManager.Initialize`<br>`FmodRuntime.init` | compile error |
| `FMOD_Studio_System_GetBank` | `StudioSystem.getBank` |  |
| `FMOD_Studio_System_GetBankByID` | `StudioSystem.getBankByID` |  |
| `FMOD_Studio_System_GetBankCount` | `StudioSystem.getBankCount` |  |
| `FMOD_Studio_System_GetBankList` | `StudioSystem.getBankList`<br>`StudioSystem.unloadAll` |  |
| `FMOD_Studio_System_GetBufferUsage` | `StudioSystem.getBufferUsage` |  |
| `FMOD_Studio_System_GetBus` | `StudioSystem.getBus`<br>`FmodManager.GetBusMute`<br>`FmodManager.GetBusVolume`<br>`FmodManager.SetBusMute`<br>`FmodManager.SetBusVolume`<br>`FmodManager.StopAllSounds`<br>`FmodRuntime.muteAll`<br>`FmodRuntime.pauseAll` |  |
| `FMOD_Studio_System_GetBusByID` | `StudioSystem.getBusByID` |  |
| `FMOD_Studio_System_GetCPUUsage` | `StudioSystem.getCpuUsage` |  |
| `FMOD_Studio_System_GetCoreSystem` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_Studio_System_GetEvent` | `StudioSystem.getEvent`<br>`FmodRuntime.createInstance` |  |
| `FMOD_Studio_System_GetEventByID` | `StudioSystem.getEventByID` |  |
| `FMOD_Studio_System_GetListenerAttributes` | `StudioSystem.getListenerAttributes`<br>`FmodFlxEmitter.update` |  |
| `FMOD_Studio_System_GetListenerWeight` | `StudioSystem.getListenerWeight` |  |
| `FMOD_Studio_System_GetMemoryUsage` | `StudioSystem.getMemoryUsage` | compile error |
| `FMOD_Studio_System_GetNumListeners` | `StudioSystem.getNumListeners` |  |
| `FMOD_Studio_System_GetParameterByID` | `StudioSystem.getParameterByID`<br>`StudioSystem.getParameterByIDFinal` |  |
| `FMOD_Studio_System_GetParameterByName` | `StudioSystem.getParameter`<br>`StudioSystem.getParameterFinal` |  |
| `FMOD_Studio_System_GetParameterDescriptionByName` | `StudioSystem.getParameterDescriptionByName` |  |
| `FMOD_Studio_System_GetParameterDescriptionCount` | `StudioSystem.getParameterDescriptionCount` |  |
| `FMOD_Studio_System_GetParameterDescriptionList` | `StudioSystem.getParameterDescriptionByIndex` |  |
| `FMOD_Studio_System_GetParameterLabelByName` | `StudioSystem.getParameterLabel` |  |
| `FMOD_Studio_System_GetSoundInfo` | `StudioSystem.getSoundInfo` |  |
| `FMOD_Studio_System_GetUserData` | `StudioSystem.getUserData` |  |
| `FMOD_Studio_System_GetVCA` | `StudioSystem.getVCA` |  |
| `FMOD_Studio_System_GetVCAByID` | `StudioSystem.getVCAByID` |  |
| `FMOD_Studio_System_Initialize` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_Studio_System_LoadBankFile` | `StudioSystem.loadBankFile` |  |
| `FMOD_Studio_System_LoadBankMemory` | `StudioSystem.loadBankMemory` |  |
| `FMOD_Studio_System_LoadCommandReplay` | `StudioSystem.loadCommandReplay` |  |
| `FMOD_Studio_System_LookupID` | `StudioSystem.lookupID` |  |
| `FMOD_Studio_System_LookupPath` | `StudioSystem.lookupPath` |  |
| `FMOD_Studio_System_Release` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_Studio_System_ResetBufferUsage` | `StudioSystem.resetBufferUsage` |  |
| `FMOD_Studio_System_SetAdvancedSettings` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_Studio_System_SetCallback` | `StudioSystem.clearSystemCallback`<br>`StudioSystem.setSystemCallback`<br>`SystemCallbacks.clear`<br>`SystemCallbacks.set`<br>`FmodManager.ClearAllCallbacks` |  |
| `FMOD_Studio_System_SetListenerAttributes` | `StudioSystem.setListenerAttributes`<br>`StudioSystem.setListenerPosition2D`<br>`FmodFlxListener.update`<br>`FmodRuntime.setListenerPosition` |  |
| `FMOD_Studio_System_SetListenerWeight` | `StudioSystem.setListenerWeight` |  |
| `FMOD_Studio_System_SetNumListeners` | `StudioSystem.setNumListeners` |  |
| `FMOD_Studio_System_SetParameterByID` | `StudioSystem.setParameterByID` |  |
| `FMOD_Studio_System_SetParameterByIDWithLabel` | `StudioSystem.setParameterByIDWithLabel` |  |
| `FMOD_Studio_System_SetParameterByName` | `StudioSystem.setParameter` |  |
| `FMOD_Studio_System_SetParameterByNameWithLabel` | `StudioSystem.setParameterWithLabel` |  |
| `FMOD_Studio_System_SetUserData` | `StudioSystem.setUserData` |  |
| `FMOD_Studio_System_StartCommandCapture` | `StudioSystem.startCommandCapture` |  |
| `FMOD_Studio_System_StopCommandCapture` | `StudioSystem.stopCommandCapture` |  |
| `FMOD_Studio_System_UnloadAll` | `StudioSystem.unloadAll` |  |
| `FMOD_Studio_System_Update` | `FmodManager.Update`<br>`FmodRuntime.update`<br>`FmodManager.PauseSong` |  |

## Studio::VCA

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_Studio_VCA_GetID` | `Vca.getID` | limited |
| `FMOD_Studio_VCA_GetPath` | `Vca.getPath` |  |
| `FMOD_Studio_VCA_GetVolume` | `Vca.getVolume`<br>`Vca.getFinalVolume` |  |
| `FMOD_Studio_VCA_IsValid` | `Vca.isValid` |  |
| `FMOD_Studio_VCA_SetVolume` | `Vca.setVolume` |  |

## System

| FMOD | haxefmod | HTML5 |
|---|---|---|
| `FMOD_System_CreateChannelGroup` | `ChannelGroup.create` |  |
| `FMOD_System_CreateDSPByPlugin` | `Dsp.createByPlugin` | compile error |
| `FMOD_System_CreateDSPByType` | `Dsp.create` |  |
| `FMOD_System_CreateGeometry` | `Geometry.create` | compile error |
| `FMOD_System_CreateReverb3D` | `Reverb3D.create` |  |
| `FMOD_System_CreateSound` | `PcmStream.create`<br>`PcmStream.create3d`<br>`Sound.create`<br>`Sound.createRecordBuffer`<br>`Sound.fromPcm` | compile error |
| `FMOD_System_CreateSoundGroup` | `SoundGroup.create` |  |
| `FMOD_System_Get3DSettings` | `CoreSystem.get3DSettings` |  |
| `FMOD_System_GetAdvancedSettings` | `StudioSystem.getAdvancedSettings`<br>`FmodManager.Initialize`<br>`FmodRuntime.init` | compile error |
| `FMOD_System_GetChannel` | `CoreSystem.getChannel` |  |
| `FMOD_System_GetChannelsPlaying` | `CoreSystem.getChannelsPlaying` |  |
| `FMOD_System_GetDSPInfoByPlugin` | `Dsp.getPluginInfo` | compile error |
| `FMOD_System_GetDSPInfoByType` | `CoreSystem.getDspInfoByType` | compile error |
| `FMOD_System_GetDefaultMixMatrix` | `CoreSystem.getDefaultMixMatrix` | compile error |
| `FMOD_System_GetDriver` | `CoreSystem.getDriver` |  |
| `FMOD_System_GetDriverInfo` | `CoreSystem.getDriverName` |  |
| `FMOD_System_GetFileUsage` | `StudioSystem.getFileUsage` |  |
| `FMOD_System_GetGeometryOcclusion` | `Geometry.getOcclusion` | compile error |
| `FMOD_System_GetGeometrySettings` | `Geometry.getWorldSize` | compile error |
| `FMOD_System_GetMasterChannelGroup` | `ChannelGroup.master` |  |
| `FMOD_System_GetMasterSoundGroup` | `SoundGroup.master` |  |
| `FMOD_System_GetNestedPlugin` | `StudioSystem.getNestedPlugin` | compile error |
| `FMOD_System_GetNetworkProxy` | `CoreSystem.getNetworkProxy` |  |
| `FMOD_System_GetNetworkTimeout` | `CoreSystem.getNetworkTimeout` |  |
| `FMOD_System_GetNumDrivers` | `CoreSystem.getDriverCount` |  |
| `FMOD_System_GetNumNestedPlugins` | `StudioSystem.getNestedPluginCount` | compile error |
| `FMOD_System_GetNumPlugins` | `StudioSystem.getPluginCount` | compile error |
| `FMOD_System_GetOutput` | `CoreSystem.getOutput` |  |
| `FMOD_System_GetOutputByPlugin` | `CoreSystem.getOutputByPlugin` |  |
| `FMOD_System_GetPluginHandle` | `StudioSystem.getPluginHandle` | compile error |
| `FMOD_System_GetPluginInfo` | `StudioSystem.getPluginInfo` | compile error |
| `FMOD_System_GetRecordDriverInfo` | `StudioSystem.getRecordDriverInfo` | compile error |
| `FMOD_System_GetRecordNumDrivers` | `StudioSystem.getRecordDriverCount` | compile error |
| `FMOD_System_GetRecordPosition` | `StudioSystem.getRecordPosition` | compile error |
| `FMOD_System_GetReverbProperties` | `Reverb.get` |  |
| `FMOD_System_GetSoftwareFormat` | `CoreSystem.getSoftwareFormat` |  |
| `FMOD_System_GetSpeakerModeChannels` | `CoreSystem.getSpeakerModeChannels`<br>`CoreSystem.getDefaultMixMatrix` | compile error |
| `FMOD_System_GetSpeakerPosition` | `CoreSystem.getSpeakerPosition` |  |
| `FMOD_System_GetUserData` | `StudioSystem.getUserData` |  |
| `FMOD_System_GetVersion` | `StudioSystem.getVersion` | limited |
| `FMOD_System_IsRecording` | `StudioSystem.isRecording` | compile error |
| `FMOD_System_LoadGeometry` | `Geometry.load` | compile error |
| `FMOD_System_LoadPlugin` | `StudioSystem.loadPlugin` | compile error |
| `FMOD_System_LockDSP` | `StudioSystem.lockDsp` |  |
| `FMOD_System_MixerResume` | `CoreSystem.mixerResume` |  |
| `FMOD_System_MixerSuspend` | `CoreSystem.mixerSuspend` |  |
| `FMOD_System_PlayDSP` | `Dsp.play` |  |
| `FMOD_System_PlaySound` | `PcmStream.play`<br>`Sound.play` |  |
| `FMOD_System_RecordStart` | `StudioSystem.recordStart` | compile error |
| `FMOD_System_RecordStop` | `StudioSystem.recordStop` | compile error |
| `FMOD_System_Set3DSettings` | `CoreSystem.set3DSettings` |  |
| `FMOD_System_SetAdvancedSettings` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_System_SetCallback` | `StudioSystem.clearSystemCallback`<br>`StudioSystem.setSystemCallback`<br>`SystemCallbacks.clear`<br>`SystemCallbacks.set`<br>`FmodManager.ClearAllCallbacks` |  |
| `FMOD_System_SetDSPBufferSize` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_System_SetDriver` | `CoreSystem.setDriver` |  |
| `FMOD_System_SetGeometrySettings` | `Geometry.setWorldSize` | compile error |
| `FMOD_System_SetNetworkProxy` | `CoreSystem.setNetworkProxy` |  |
| `FMOD_System_SetNetworkTimeout` | `CoreSystem.setNetworkTimeout` |  |
| `FMOD_System_SetOutput` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_System_SetOutputByPlugin` | `CoreSystem.setOutputByPlugin` |  |
| `FMOD_System_SetPluginPath` | `StudioSystem.setPluginPath` | compile error |
| `FMOD_System_SetReverbProperties` | `Reverb.set` |  |
| `FMOD_System_SetSoftwareChannels` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_System_SetSoftwareFormat` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_System_SetSpeakerPosition` | `CoreSystem.setSpeakerPosition` |  |
| `FMOD_System_SetStreamBufferSize` | `FmodManager.Initialize`<br>`FmodRuntime.init` |  |
| `FMOD_System_SetUserData` | `StudioSystem.setUserData` |  |
| `FMOD_System_UnloadPlugin` | `StudioSystem.unloadPlugin` | compile error |
| `FMOD_System_UnlockDSP` | `StudioSystem.unlockDsp` |  |

