# platforms-mac

## Latency
kind: example
index: 0
heading: Latency

### C++
```cpp
AudioUnit audioUnit;
gSystem->getOutputHandle((void **)&audioUnit);

AudioDeviceID audioDeviceID;
UInt32 audioDeviceIDSize = sizeof(audioDeviceID);
AudioUnitGetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &audioDeviceID, &audioDeviceIDSize);

UInt32 bufferFrameSize = 256;
AudioDeviceSetProperty(audioDeviceID, NULL, 0, FALSE, kAudioDevicePropertyBufferFrameSize, sizeof(bufferFrameSize), &bufferFrameSize);
```

