# using-dsp-effects-in-the-core-api

## Add a DSP effect to a Channel
kind: example
index: 0
heading: Add a DSP effect to a Channel

### text
```text
FMOD::Channel *channel;
FMOD::DSP *dsp_echo;
result = system->playSound(sound, 0, false, &channel);
result = system->createDSPByType(FMOD_DSP_TYPE_ECHO, &dsp_echo);
result = channel->addDSP(0, dsp_echo);
```

## Add a DSP effect to a Channel#2
kind: example
index: 1
heading: Add a DSP effect to a Channel

### text
```text
result = channel->setDSPIndex(dsp_echo, 1);
```

## Add a DSP effect to a Channel#3
kind: example
index: 2
heading: Add a DSP effect to a Channel

### text
```text
result = system->createChannelGroup("my channelgroup", &channelgroup);
result = channel->setChannelGroup(channelgroup);
```

## Add an effect to the ChannelGroup
kind: example
index: 3
heading: Add an effect to the ChannelGroup

### text
```text
FMOD::DSP *dsp_lowpass;
result = system->createDSPByType(FMOD_DSP_TYPE_LOWPASS, &dsp_lowpass);
result = channelgroup->addDSP(1, dsp_lowpass);
```

## Creating an effect and making all Channels send to it.
kind: example
index: 4
heading: Creating an effect and making all Channels send to it.

### text
```text
FMOD::DSP *dsp_reverb;
FMOD::DSP *dsp_tail;
FMOD::ChannelGroup *channelgroup_master;
result = system->createDSPByType(FMOD_DSP_TYPE_SFXREVERB, &dsp_reverb);             /* Create the reverb DSP */
result = system->getMasterChannelGroup(&channelgroup_master);                       /* Grab the master ChannelGroup / master bus */
result = channelgroup_master->getDSP(FMOD_CHANNELCONTROL_DSP_TAIL, &dsp_tail);      /* Grab the 'tail' unit for the master ChannelGroup.  This is the last DSP unit for the ChannelGroup, in case it has other effects already in it. */
result = dsp_tail->addInput(dsp_reverb);
```

## Creating an effect and making all Channels send to it.#2
kind: example
index: 5
heading: Creating an effect and making all Channels send to it.

### text
```text
result = dsp_reverb->setActive(true);
```

## Creating an effect and making all Channels send to it.#3
kind: example
index: 6
heading: Creating an effect and making all Channels send to it.

### text
```text
FMOD::DSP *channel_dsp_head;
result = system->playSound(sound, channelgroup, true, &gChannel[0]);                /* Play the sound.  Play it paused so we dont hear the sound play before it is connected to the reverb. */
result = channel->getDSP(FMOD_CHANNELCONTROL_DSP_HEAD, &channel_dsp_head);          /* Grab the 'head' unit for the Channel */
result = dsp_reverb->addInput(channel_dsp_head);                                    /* Manually add a connection from the Channel DSP head to the reverb. */
result = channel->setPaused(false);                                                 /* Unpause the channel and let it be audible. */
```

## Controlling mix level and pan matrices for DSPConnections
kind: example
index: 7
heading: Controlling mix level and pan matrices for DSPConnections

### text
```text
FMOD::DSP *channel_dsp_head;
FMOD::DSPConnection *dsp_connection;
result = system->playSound(sound, channelgroup, true, &gChannel[0]);                /* Play the sound.  Play it paused so we dont hear the sound play before it is connected to the reverb. */
result = channel->getDSP(FMOD_CHANNELCONTROL_DSP_HEAD, &channel_dsp_head);          /* Grab the 'head' unit for the Channel */
result = dsp_reverb->addInput(channel_dsp_head, &dsp_connection);                   /* Manually add a connection from the Channel DSP head to the reverb. */
result = channel->setPaused(false);                                                 /* Unpause the channel and let it be audible. */
```

## Controlling mix level and pan matrices for DSPConnections#2
kind: example
index: 8
heading: Controlling mix level and pan matrices for DSPConnections

### text
```text
result = dsp_connection->setMix(0.0f);
```

## Set the output format of a DSP unit, and control the pan matrix for its output signal
kind: example
index: 9
heading: Set the output format of a DSP unit, and control the pan matrix for its output signal

### text
```text
result = channel_dsp_head->setChannelFormat(0, 0, FMOD_SPEAKER_QUAD);
```

## Set the output format of a DSP unit, and control the pan matrix for its output signal#2
kind: example
index: 10
heading: Set the output format of a DSP unit, and control the pan matrix for its output signal

### text
```text
FMOD::DSPConnection *channel_dsp_head_output_connection;
float matrix[4][4] =
{   /*                                    FL FR SL SR <- Input signal (columns) */
    /* row 0 = front left  out    <- */ { 0, 0, 0, 0 },     
    /* row 1 = front right out    <- */ { 0, 0, 0, 0 },     
    /* row 2 = surround left out  <- */ { 1, 0, 0, 0 },     
    /* row 3 = surround right out <- */ { 0, 1, 0, 0 }      
};
result = channel_dsp_head->getOutput(0, 0, &channel_dsp_head_output_connection);
result = channel_dsp_head_output_connection->setMixMatrix(&matrix[0][0], 4, 4);
```

## Bypass an effect / disable it.
kind: example
index: 11
heading: Bypass an effect / disable it.

### text
```text
result = dsp_reverb->setBypass(true);
```

## 7.2 Plug-in DSP Effects
kind: example
index: 12
heading: 7.2 Plug-in DSP Effects

### text
```text
FMOD_RESULT FMOD::Studio::System::registerPlugin(const FMOD_DSP_DESCRIPTION* description);
FMOD_RESULT FMOD::System::registerDSP(const FMOD_DSP_DESCRIPTION *description, unsigned int *handle);
```

## 7.2 Plug-in DSP Effects#2
kind: example
index: 13
heading: 7.2 Plug-in DSP Effects

### text
```text
FMOD_RESULT FMOD::System::loadPlugin(const char *filename, unsigned int *handle, unsigned int priority = 0)
```

## 7.2 Plug-in DSP Effects#3
kind: example
index: 14
heading: 7.2 Plug-in DSP Effects

### text
```text
FMOD_RESULT FMOD::System::setPluginPath(const char *path)
```

## 7.2 Plug-in DSP Effects#4
kind: example
index: 15
heading: 7.2 Plug-in DSP Effects

### text
```text
FMOD_RESULT FMOD::Studio::System::unregisterPlugin(const char* name)
FMOD_RESULT FMOD::System::unloadPlugin(unsigned int handle)
```

## 7.2.1 The Plug-in Descriptor
kind: example
index: 16
heading: 7.2.1 The Plug-in Descriptor

### text
```text
FMOD_DSP_DESCRIPTION FMOD_Gain_Desc =
{
    FMOD_PLUGIN_SDK_VERSION,
    "FMOD Gain",    // name
    0x00010000,     // plug-in version
    1,              // number of input buffers to process
    1,              // number of output buffers to process
    ...
};
```

## 7.2.4 Multiple plug-ins within one file
kind: example
index: 17
heading: 7.2.4 Multiple plug-ins within one file

### text
```text
FMOD_DSP_DESCRIPTION My_Gain_Desc = { .. };
FMOD_DSP_DESCRIPTION My_Panner_Desc = { .. };
FMOD_OUTPUT_DESCRIPTION My_Output_Desc = { .. };

static FMOD_PLUGINLIST My_Plugin_List[] =
{
    { FMOD_PLUGINTYPE_DSP, &My_Gain_Desc },
    { FMOD_PLUGINTYPE_DSP, &My_Panner_Desc },
    { FMOD_PLUGINTYPE_OUTPUT, &My_Output_Desc },
    { FMOD_PLUGINTYPE_MAX, NULL }
};

extern "C"
{

F_EXPORT FMOD_PLUGINLIST* F_CALL FMODGetPluginDescriptionList()
{
    return &My_Plugin_List;
}

} // end extern "C"
```

## 7.2.4 Multiple plug-ins within one file#2
kind: example
index: 18
heading: 7.2.4 Multiple plug-ins within one file

### text
```text
unsigned int baseHandle;
ERRCHECK(system->loadPlugin("plugin_name.dll", &baseHandle));
int count;
ERRCHECK(system->getNumNestedPlugins(baseHandle, &count));
for (int index=0; index<count; ++index)
{
    unsigned int handle;
    ERRCHECK(system->getNestedPlugin(baseHandle, index, &handle));        
    FMOD_PLUGINTYPE type;
    ERRCHECK(system->getPluginInfo(handle, &type, 0, 0, 0));
    // We have an output plug-in, a DSP plug-in, or a codec plug-in here.
}
```

