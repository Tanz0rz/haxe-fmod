# using-dsp-effects-in-the-core-api

## Add a DSP effect to a Channel
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var sound = Sound.create("drumloop.wav");
var channel = sound.play();
var dsp_echo = Dsp.create(DspType.ECHO);
var result = channel.addDsp(0, dsp_echo);
```

## Add a DSP effect to a Channel#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dsp_echo = Dsp.create(DspType.ECHO);
channel.addDsp(0, dsp_echo);
var result = channel.setDspIndex(dsp_echo, 1);
```

## Add a DSP effect to a Channel#3
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;

var channelgroup = ChannelGroup.create("my channelgroup");
var result = channel.setChannelGroup(channelgroup);
```

## Add an effect to the ChannelGroup
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var channelgroup = ChannelGroup.create("my channelgroup");
var dsp_lowpass = Dsp.create(DspType.LOWPASS);
var result = channelgroup.addDsp(1, dsp_lowpass);
```

## Creating an effect and making all Channels send to it.
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dsp_reverb = Dsp.create(DspType.SFXREVERB);                                     /* Create the reverb DSP */
var channelgroup_master = ChannelGroup.master();                                    /* Grab the master ChannelGroup / master bus */
var dsp_tail = channelgroup_master.getDsp(ChannelGroup.DSP_TAIL);                  /* Grab the 'tail' unit for the master ChannelGroup.  This is the last DSP unit for the ChannelGroup, in case it has other effects already in it. */
var connection = dsp_tail.addInput(dsp_reverb);
```

## Creating an effect and making all Channels send to it.#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dsp_reverb = Dsp.create(DspType.SFXREVERB);
var result = dsp_reverb.setActive(true);
```

## Creating an effect and making all Channels send to it.#3
verdict: bound
```haxe
import haxefmod.core.Channel;
import haxefmod.core.Sound;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var sound = Sound.create("drumloop.wav");
var channelgroup = ChannelGroup.create("my channelgroup");
var dsp_reverb = Dsp.create(DspType.SFXREVERB);

var channel = sound.play(true, channelgroup);                                       /* Play the sound.  Play it paused so we dont hear the sound play before it is connected to the reverb. */
var channel_dsp_head = channel.getDsp(Channel.DSP_HEAD);                            /* Grab the 'head' unit for the Channel */
var connection = dsp_reverb.addInput(channel_dsp_head);                             /* Manually add a connection from the Channel DSP head to the reverb. */
var result = channel.setPaused(false);                                              /* Unpause the channel and let it be audible. */
```

## Controlling mix level and pan matrices for DSPConnections
verdict: bound
```haxe
import haxefmod.core.Channel;
import haxefmod.core.Sound;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var sound = Sound.create("drumloop.wav");
var channelgroup = ChannelGroup.create("my channelgroup");
var dsp_reverb = Dsp.create(DspType.SFXREVERB);

var channel = sound.play(true, channelgroup);                                       /* Play the sound.  Play it paused so we dont hear the sound play before it is connected to the reverb. */
var channel_dsp_head = channel.getDsp(Channel.DSP_HEAD);                            /* Grab the 'head' unit for the Channel */
var dsp_connection = dsp_reverb.addInput(channel_dsp_head);                         /* Manually add a connection from the Channel DSP head to the reverb. */
var result = channel.setPaused(false);                                              /* Unpause the channel and let it be audible. */
```

## Controlling mix level and pan matrices for DSPConnections#2
verdict: bound
```haxe
import haxefmod.core.Channel;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dsp_reverb = Dsp.create(DspType.SFXREVERB);
var dsp_connection = dsp_reverb.addInput(channel.getDsp(Channel.DSP_HEAD));
var result = dsp_connection.setMix(0.0);
```

## Set the output format of a DSP unit, and control the pan matrix for its output signal
verdict: bound
```haxe
import haxefmod.core.Channel;
import haxefmod.core.Dsp;
import haxefmod.studio.Types.FmodSpeakerMode;

var channel_dsp_head = channel.getDsp(Channel.DSP_HEAD);
var result = channel_dsp_head.setChannelFormat(0, 0, FmodSpeakerMode.QUAD);
```

## Set the output format of a DSP unit, and control the pan matrix for its output signal#2
verdict: bound
```haxe
import haxefmod.core.Channel;
import haxefmod.core.Dsp;

var channel_dsp_head = channel.getDsp(Channel.DSP_HEAD);
var matrix:Array<Float> =
[   /*                                    FL FR SL SR <- Input signal (columns) */
    /* row 0 = front left  out    <- */    0, 0, 0, 0,
    /* row 1 = front right out    <- */    0, 0, 0, 0,
    /* row 2 = surround left out  <- */    1, 0, 0, 0,
    /* row 3 = surround right out <- */    0, 1, 0, 0
];
var channel_dsp_head_output_connection = channel_dsp_head.getOutputConnection(0);
var result = channel_dsp_head_output_connection.setMixMatrix(matrix, 4, 4);
```

## Bypass an effect / disable it.
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dsp_reverb = Dsp.create(DspType.SFXREVERB);
var result = dsp_reverb.setBypass(true);
```

## 7.2 Plug-in DSP Effects
verdict: cannot registerPlugin and registerDSP take a DSP description whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A plug-in compiled from C loads with StudioSystem.loadPlugin, which registers its effects for Studio events and Dsp.createByPlugin.

## 7.2 Plug-in DSP Effects#2
verdict: bound
```haxe
var handle = StudioSystem.loadPlugin("plugin_name.dll", 0);
```

## 7.2 Plug-in DSP Effects#3
verdict: bound
```haxe
var result = StudioSystem.setPluginPath("plugins");
```

## 7.2 Plug-in DSP Effects#4
verdict: bound
```haxe
var handle = StudioSystem.loadPlugin("plugin_name.dll");
var result = StudioSystem.unloadPlugin(handle);
```

## 7.2.1 The Plug-in Descriptor
verdict: cannot the descriptor is the C struct a plug-in author fills in, and its callbacks run on FMOD's mixer thread where no Haxe target can execute code. A compiled plug-in loads with StudioSystem.loadPlugin and Dsp.getPluginInfo reads back the name, version, and buffer counts it declared.

## 7.2.4 Multiple plug-ins within one file
verdict: cannot the plug-in list and its exported FMODGetPluginDescriptionList are C code compiled into the plug-in binary. A file that exports a list loads as one handle with StudioSystem.loadPlugin, and StudioSystem.getNestedPlugin walks the plug-ins inside it.

## 7.2.4 Multiple plug-ins within one file#2
verdict: bound
```haxe
var baseHandle = StudioSystem.loadPlugin("plugin_name.dll");
if (baseHandle == 0) {
    trace('loadPlugin failed: ${StudioSystem.lastResult()}');
}
var count = StudioSystem.getNestedPluginCount(baseHandle);
for (index in 0...count) {
    var handle = StudioSystem.getNestedPlugin(baseHandle, index);
    var info = StudioSystem.getPluginInfo(handle);
    if (info == null) {
        trace('getPluginInfo failed: ${StudioSystem.lastResult()}');
        continue;
    }
    var type = info.type;
    // We have an output plug-in, a DSP plug-in, or a codec plug-in here.
}
```

