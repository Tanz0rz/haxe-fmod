package haxefmod.studio;

/**
 * Shared types for the FMOD Studio bindings.
 * Values are pinned to FMOD 2.03.12 headers.
 */

/** FMOD_STUDIO_STOP_MODE */
enum abstract FmodStopMode(Int) from Int to Int {
    var ALLOWFADEOUT = 0;
    var IMMEDIATE = 1;
}

/** FMOD_STUDIO_PLAYBACK_STATE */
enum abstract FmodPlaybackState(Int) from Int to Int {
    var PLAYING = 0;
    var SUSTAINING = 1;
    var STOPPED = 2;
    var STARTING = 3;
    var STOPPING = 4;
}

/** FMOD_STUDIO_LOADING_STATE */
enum abstract FmodLoadingState(Int) from Int to Int {
    var UNLOADING = 0;
    var UNLOADED = 1;
    var LOADING = 2;
    var LOADED = 3;
    var ERROR = 4;
}

/** FMOD_STUDIO_EVENT_PROPERTY */
enum abstract FmodEventProperty(Int) from Int to Int {
    var CHANNELPRIORITY = 0;
    var SCHEDULE_DELAY = 1;
    var SCHEDULE_LOOKAHEAD = 2;
    var MINIMUM_DISTANCE = 3;
    var MAXIMUM_DISTANCE = 4;
    var COOLDOWN = 5;
    var MAX = 6;
}

/** FMOD_STUDIO_PARAMETER_TYPE */
enum abstract FmodParameterType(Int) from Int to Int {
    var GAME_CONTROLLED = 0;
    var AUTOMATIC_DISTANCE = 1;
    var AUTOMATIC_EVENT_CONE_ANGLE = 2;
    var AUTOMATIC_EVENT_ORIENTATION = 3;
    var AUTOMATIC_DIRECTION = 4;
    var AUTOMATIC_ELEVATION = 5;
    var AUTOMATIC_LISTENER_ORIENTATION = 6;
    var AUTOMATIC_SPEED = 7;
    var AUTOMATIC_SPEED_ABSOLUTE = 8;
    var AUTOMATIC_DISTANCE_NORMALIZED = 9;
    var MAX = 10;
}

/** FMOD_STUDIO_PARAMETER_FLAGS bits */
enum abstract FmodParameterFlags(Int) from Int to Int {
    var READONLY = 0x00000001;
    var AUTOMATIC = 0x00000002;
    var GLOBAL = 0x00000004;
    var DISCRETE = 0x00000008;
    var LABELED = 0x00000010;
}

/** FMOD_STUDIO_USER_PROPERTY_TYPE */
enum abstract FmodUserPropertyType(Int) from Int to Int {
    var INTEGER = 0;
    var BOOLEAN = 1;
    var FLOAT = 2;
    var STRING = 3;
}

/** FMOD_STUDIO_PARAMETER_ID (two opaque ints) */
typedef FmodParameterId = {
    var data1:Int;
    var data2:Int;
}

/** FMOD_STUDIO_PARAMETER_DESCRIPTION */
typedef FmodParameterDescription = {
    var name:String;
    var id:FmodParameterId;
    var minimum:Float;
    var maximum:Float;
    var defaultValue:Float;
    var type:FmodParameterType;
    var flags:Int;
    /** The parameter's GUID in FMOD Studio's text form, the same form lookupID returns. */
    var guid:String;
}

/** A 3D vector (FMOD_VECTOR) */
typedef FmodVector = {
    var x:Float;
    var y:Float;
    var z:Float;
}

/** FMOD_3D_ATTRIBUTES - position/velocity in game units, forward/up unit vectors */
typedef Fmod3DAttributes = {
    var position:FmodVector;
    var velocity:FmodVector;
    var forward:FmodVector;
    var up:FmodVector;
}

/** FMOD_DSP_PARAMETER_3DATTRIBUTES, the payload of a 3D data parameter: the emitter in the listener's space and in world space. */
typedef FmodDspParameter3DAttributes = {
    var relative:Fmod3DAttributes;
    var absolute:Fmod3DAttributes;
}

/** FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI, the same payload for several listeners, one relative entry and one weight per listener. */
typedef FmodDspParameter3DAttributesMulti = {
    var numListeners:Int;
    var relative:Array<Fmod3DAttributes>;
    var weight:Array<Float>;
    var absolute:Fmod3DAttributes;
}

/** FMOD_DSP_PARAMETER_OVERALLGAIN, the gain a unit reports for FMOD's virtual voice ranking. */
typedef FmodDspParameterOverallGain = {
    var linearGain:Float;
    var linearGainAdditive:Float;
}

/** FMOD_DSP_LOUDNESS_METER_INFO_TYPE, the readback of a loudness meter unit. Loudness values are in LUFS, the histogram has 66 bins. */
typedef FmodDspLoudnessMeterInfo = {
    var momentaryLoudness:Float;
    var shortTermLoudness:Float;
    var integratedLoudness:Float;
    var loudness10thPercentile:Float;
    var loudness95thPercentile:Float;
    var loudnessHistogram:Array<Float>;
    var maxTruePeak:Float;
    var maxMomentaryLoudness:Float;
}

/** FMOD_DSP_PARAMETER_FFT, the spectrum of an FFT unit with one magnitude array per channel. */
typedef FmodDspParameterFft = {
    var length:Int;
    var numChannels:Int;
    var spectrum:Array<Array<Float>>;
}

/**
 * What StudioSystem.getListenerAttributes returns: the listener's 3D
 * attributes plus the point FMOD attenuates from. The attenuation position
 * equals the listener position unless setListenerAttributes was given a
 * separate one. Usable anywhere an Fmod3DAttributes is expected.
 */
typedef FmodListenerAttributes = {
    > Fmod3DAttributes,
    var attenuationPosition:FmodVector;
}

/**
 * FMOD_STUDIO_SOUND_INFO, what StudioSystem.getSoundInfo reports for an
 * audio table key. name is the file FMOD would open (the bank path for a
 * bank loaded from disk, "" for a bank held in memory), mode the
 * ChannelMode flags it would open it with, and the exinfo fields say where
 * the sample sits in that file: length in bytes, fileOffset in bytes,
 * initialSubsound, and numSubsounds. subSoundIndex is the subsound inside
 * the loaded sound that plays the key.
 */
typedef FmodSoundInfo = {
    var name:String;
    var mode:Int;
    var length:Int;
    var fileOffset:Int;
    var initialSubsound:Int;
    var numSubsounds:Int;
    var subSoundIndex:Int;
}

/** CPU usage in microseconds (FMOD_Studio_Bus_GetCPUUsage) */
typedef FmodCpuUsage = {
    var exclusive:Int;
    var inclusive:Int;
}

/** Memory usage in bytes (FMOD_STUDIO_MEMORY_USAGE) */
typedef FmodMemoryUsage = {
    var exclusive:Int;
    var inclusive:Int;
    var sampledata:Int;
}

/** System-wide CPU usage in percent of one core (FMOD_STUDIO_CPU_USAGE + FMOD_CPU_USAGE) */
typedef FmodSystemCpuUsage = {
    var studioUpdate:Float;
    var dsp:Float;
    var stream:Float;
    var geometry:Float;
    var update:Float;
    var convolution1:Float;
    var convolution2:Float;
}

/** One internal buffer's usage (FMOD_STUDIO_BUFFER_INFO) */
typedef FmodBufferInfo = {
    var currentUsage:Int;
    var peakUsage:Int;
    var capacity:Int;
    var stallCount:Int;
    var stallTime:Float;
}

/** FMOD_STUDIO_BUFFER_USAGE */
typedef FmodBufferUsage = {
    var studioCommandQueue:FmodBufferInfo;
    var studioHandle:FmodBufferInfo;
}

/** A user property authored on an event in FMOD Studio */
typedef FmodUserProperty = {
    var name:String;
    var type:FmodUserPropertyType;
    /** Numeric value (int/bool coerced). 0 for string properties. */
    var floatValue:Float;
    /** String value. "" for non-string properties. */
    var stringValue:String;
}

/** FMOD_STUDIO_LOAD_BANK_FLAGS bits, the flags StudioSystem.loadBankFile and loadBankMemory take. */
enum abstract FmodLoadBankFlags(Int) from Int to Int {
    var NORMAL = 0;
    var NONBLOCKING = 1;
    var DECOMPRESS_SAMPLES = 2;
    var UNENCRYPTED = 4;
}
/** One command in a loaded capture (FMOD_STUDIO_COMMAND_INFO) */
typedef FmodCommandInfo = {
    var commandName:String;
    var parentCommandIndex:Int;
    var frameNumber:Int;
    var frameTime:Float;
    var instanceType:FmodStudioInstanceType;
    var outputType:FmodStudioInstanceType;
    var instanceHandle:Int;
    var outputHandle:Int;
}

/** FMOD_PLUGINTYPE, the plugin categories StudioSystem.getPluginCount enumerates */
enum abstract FmodPluginType(Int) from Int to Int {
    var OUTPUT = 0;
    var CODEC = 1;
    var DSP = 2;
    var MAX = 3;
}

/** Core advanced settings as FMOD holds them (FMOD_ADVANCEDSETTINGS, the fields haxefmod exposes). */
typedef FmodAdvancedSettings = {
    var maxMPEGCodecs:Int;
    var maxVorbisCodecs:Int;
    var maxFADPCMCodecs:Int;
    var vol0VirtualVol:Float;
    var defaultDecodeBufferSize:Int;
    var profilePort:Int;
    var geometryMaxFadeTime:Int;
    var distanceFilterCenterFreq:Float;
    var randomSeed:Int;
    var resamplerMethod:FmodDspResampler;
}

/** Studio advanced settings as FMOD holds them (FMOD_STUDIO_ADVANCEDSETTINGS without the key). */
typedef FmodStudioAdvancedSettings = {
    var commandQueueSize:Int;
    var handleInitialSize:Int;
    var studioUpdatePeriod:Int;
    var idleSampleDataPoolSize:Int;
    var streamingScheduleDelay:Int;
}

/** FMOD_TAGTYPE, where a tag came from. */
enum abstract FmodTagType(Int) from Int to Int {
    var UNKNOWN = 0;
    var ID3V1 = 1;
    var ID3V2 = 2;
    var VORBISCOMMENT = 3;
    var SHOUTCAST = 4;
    var ICECAST = 5;
    var ASF = 6;
    var MIDI = 7;
    var PLAYLIST = 8;
    var FMOD = 9;
    var USER = 10;
    var MAX = 11;
}

/** FMOD_TAGDATATYPE, what a tag's payload holds. */
enum abstract FmodTagDataType(Int) from Int to Int {
    var BINARY = 0;
    var INT = 1;
    var FLOAT = 2;
    var STRING = 3;
    var STRING_UTF16 = 4;
    var STRING_UTF16BE = 5;
    var STRING_UTF8 = 6;
    var MAX = 7;
}

/** One metadata tag of a sound (FMOD_TAG) */
typedef FmodTag = {
    var name:String;
    var type:FmodTagType;
    var dataType:FmodTagDataType;
    /** True until the tag has been read once through getTag. */
    var updated:Bool;
    /** Payload size in bytes, reported for every data type. */
    var length:Int;
    /** The payload of an INT tag. 0 otherwise. */
    var intValue:Int;
    /** The payload of a FLOAT tag. 0 otherwise. */
    var floatValue:Float;
    /** The payload of a STRING or STRING_UTF8 tag. "" otherwise, UTF16 and binary payloads are not copied. */
    var stringValue:String;
}

/** FMOD_SPEAKER, the output speaker index CoreSystem.setSpeakerPosition takes. */
enum abstract FmodSpeaker(Int) from Int to Int {
    var NONE = -1;
    var FRONT_LEFT = 0;
    var FRONT_RIGHT = 1;
    var FRONT_CENTER = 2;
    var LOW_FREQUENCY = 3;
    var SURROUND_LEFT = 4;
    var SURROUND_RIGHT = 5;
    var BACK_LEFT = 6;
    var BACK_RIGHT = 7;
    var TOP_FRONT_LEFT = 8;
    var TOP_FRONT_RIGHT = 9;
    var TOP_BACK_LEFT = 10;
    var TOP_BACK_RIGHT = 11;
    var MAX = 12;
}

/** FMOD_SPEAKERMODE, the mixer's speaker layout (FmodSettings.speakerMode, CoreSystem.getSoftwareFormat). */
enum abstract FmodSpeakerMode(Int) from Int to Int {
    var DEFAULT = 0;
    var RAW = 1;
    var MONO = 2;
    var STEREO = 3;
    var QUAD = 4;
    var SURROUND = 5;
    var _5POINT1 = 6;
    var _7POINT1 = 7;
    var _7POINT1POINT4 = 8;
    var MAX = 9;
}

/** FMOD_OUTPUTTYPE, the output backend FmodSettings.output picks and CoreSystem.getOutput reports. */
enum abstract FmodOutputType(Int) from Int to Int {
    var AUTODETECT = 0;
    var UNKNOWN = 1;
    var NOSOUND = 2;
    var WAVWRITER = 3;
    var NOSOUND_NRT = 4;
    var WAVWRITER_NRT = 5;
    var WASAPI = 6;
    var ASIO = 7;
    var PULSEAUDIO = 8;
    var ALSA = 9;
    var COREAUDIO = 10;
    var AUDIOTRACK = 11;
    var OPENSL = 12;
    var AUDIOOUT = 13;
    var AUDIO3D = 14;
    var WEBAUDIO = 15;
    var NNAUDIO = 16;
    var WINSONIC = 17;
    var AAUDIO = 18;
    var AUDIOWORKLET = 19;
    var PHASE = 20;
    var OHAUDIO = 21;
    var MAX = 22;
}

/** FMOD_DRIVER_STATE bits, the state field of StudioSystem.getRecordDriverInfo. */
enum abstract FmodDriverState(Int) from Int to Int {
    var CONNECTED = 0x00000001;
    var DEFAULT = 0x00000002;
}

/** FMOD_CHANNELMASK bits, the channel mask Dsp.setChannelFormat takes. */
enum abstract FmodChannelMask(Int) from Int to Int {
    var FRONT_LEFT = 0x00000001;
    var FRONT_RIGHT = 0x00000002;
    var FRONT_CENTER = 0x00000004;
    var LOW_FREQUENCY = 0x00000008;
    var SURROUND_LEFT = 0x00000010;
    var SURROUND_RIGHT = 0x00000020;
    var BACK_LEFT = 0x00000040;
    var BACK_RIGHT = 0x00000080;
    var BACK_CENTER = 0x00000100;
    var MONO = 0x00000001;
    var STEREO = 0x00000003;
    var LRC = 0x00000007;
    var QUAD = 0x00000033;
    var SURROUND = 0x00000037;
    var _5POINT1 = 0x0000003F;
    var _5POINT1_REARS = 0x000000CF;
    var _7POINT0 = 0x000000F7;
    var _7POINT1 = 0x000000FF;
}

/**
 * FMOD_TIMEUNIT bits. The length, loop point, sync point, and position
 * calls on Sound and Channel take one as an optional trailing parameter
 * and default to MS. Stream buffer sizes are always RAWBYTES.
 */
enum abstract FmodTimeUnit(Int) from Int to Int {
    var MS = 0x00000001;
    var PCM = 0x00000002;
    var PCMBYTES = 0x00000004;
    var RAWBYTES = 0x00000008;
    var PCMFRACTION = 0x00000010;
    var MODORDER = 0x00000100;
    var MODROW = 0x00000200;
    var MODPATTERN = 0x00000400;
}

/** FMOD_OPENSTATE, what Sound.getOpenState and getOpenStateInfo report while a sound loads or streams. */
enum abstract FmodOpenState(Int) from Int to Int {
    var READY = 0;
    var LOADING = 1;
    var ERROR = 2;
    var CONNECTING = 3;
    var BUFFERING = 4;
    var SEEKING = 5;
    var PLAYING = 6;
    var SETPOSITION = 7;
    var MAX = 8;
}

/** FMOD_SOUND_TYPE, the container formats FMOD decodes. Sound.create takes any of them the target supports, and Sound.getFormat reports which one a loaded sound has. */
enum abstract FmodSoundType(Int) from Int to Int {
    var UNKNOWN = 0;
    var AIFF = 1;
    var ASF = 2;
    var DLS = 3;
    var FLAC = 4;
    var FSB = 5;
    var IT = 6;
    var MIDI = 7;
    var MOD = 8;
    var MPEG = 9;
    var OGGVORBIS = 10;
    var PLAYLIST = 11;
    var RAW = 12;
    var S3M = 13;
    var USER = 14;
    var WAV = 15;
    var XM = 16;
    var XMA = 17;
    var AUDIOQUEUE = 18;
    var AT9 = 19;
    var VORBIS = 20;
    var MEDIA_FOUNDATION = 21;
    var MEDIACODEC = 22;
    var FADPCM = 23;
    var OPUS = 24;
    var MAX = 25;
}

/** FMOD_SOUND_FORMAT, the sample formats. Sound.fromPcm always builds PCM16, and Sound.getFormat reports the format of a loaded sound. */
enum abstract FmodSoundFormat(Int) from Int to Int {
    var NONE = 0;
    var PCM8 = 1;
    var PCM16 = 2;
    var PCM24 = 3;
    var PCM32 = 4;
    var PCMFLOAT = 5;
    var BITSTREAM = 6;
    var MAX = 7;
}

/** FMOD_STUDIO_INSTANCETYPE, the object kind in FmodCommandInfo.instanceType and outputType. */
enum abstract FmodStudioInstanceType(Int) from Int to Int {
    var NONE = 0;
    var SYSTEM = 1;
    var EVENTDESCRIPTION = 2;
    var EVENTINSTANCE = 3;
    var PARAMETERINSTANCE = 4;
    var BUS = 5;
    var VCA = 6;
    var BANK = 7;
    var COMMANDREPLAY = 8;
}

/** FMOD_DSPCONNECTION_TYPE, how a connection made by Dsp.addInput carries signal. DspConnection.TYPE_* are the same values. */
enum abstract DspConnectionType(Int) from Int to Int {
    var STANDARD = 0;
    var SIDECHAIN = 1;
    var SEND = 2;
    var SEND_SIDECHAIN = 3;
    var PREALLOCATED = 4;
    var MAX = 5;
}

/** FMOD_SOUNDGROUP_BEHAVIOR, what a group does past its audible cap (SoundGroup.setMaxAudibleBehavior). SoundGroup.BEHAVIOR_* are the same values. */
enum abstract SoundGroupBehavior(Int) from Int to Int {
    var FAIL = 0;
    var MUTE = 1;
    var STEALLOWEST = 2;
    var MAX = 3;
}

/** FMOD_CHANNELCONTROL_DSP_INDEX, the named chain positions addDsp and getDsp accept next to a plain index. ChannelGroup.DSP_* are the same values. */
enum abstract ChannelControlDspIndex(Int) from Int to Int {
    var HEAD = -1;
    var FADER = -2;
    var TAIL = -3;
}

/** FMOD_CHANNELCONTROL_TYPE, which kind of object a channel control is. Channel and ChannelGroup are separate handle types in Haxe, so no call takes it. */
enum abstract FmodChannelControlType(Int) from Int to Int {
    var CHANNEL = 0;
    var CHANNELGROUP = 1;
    var MAX = 2;
}

/** FMOD_CHANNELCONTROL_CALLBACK_TYPE, the channel callback kinds. Channel.setCallback delivers all four as ChannelEvent values, ChannelGroup.setCallback delivers OCCLUSION. */
enum abstract FmodChannelControlCallbackType(Int) from Int to Int {
    var END = 0;
    var VIRTUALVOICE = 1;
    var SYNCPOINT = 2;
    var OCCLUSION = 3;
    var MAX = 4;
}

/** FMOD_CHANNELORDER, the interleaving of multichannel PCM. Sound.create and Sound.fromPcm use DEFAULT, no call takes it. */
enum abstract FmodChannelOrder(Int) from Int to Int {
    var DEFAULT = 0;
    var WAVEFORMAT = 1;
    var PROTOOLS = 2;
    var ALLMONO = 3;
    var ALLSTEREO = 4;
    var ALSA = 5;
    var MAX = 6;
}

/** FMOD_DEBUG_FLAGS bits. The library composes the LEVEL_ bits from FmodSettings.logLevel, and FmodSettings.logFlags adds the TYPE_ and DISPLAY_ bits on native targets. */
enum abstract FmodDebugFlags(Int) from Int to Int {
    var LEVEL_NONE = 0x00000000;
    var LEVEL_ERROR = 0x00000001;
    var LEVEL_WARNING = 0x00000002;
    var LEVEL_LOG = 0x00000004;
    var TYPE_MEMORY = 0x00000100;
    var TYPE_FILE = 0x00000200;
    var TYPE_CODEC = 0x00000400;
    var TYPE_TRACE = 0x00000800;
    var TYPE_VIRTUAL = 0x00001000;
    var DISPLAY_TIMESTAMPS = 0x00010000;
    var DISPLAY_LINENUMBERS = 0x00020000;
    var DISPLAY_THREAD = 0x00040000;
}

/** FMOD_DEBUG_MODE, where FMOD's log goes. The library uses TTY, or FILE when FmodSettings.logFile names a path on a native target, and takes the level from FmodSettings.logLevel. */
enum abstract FmodDebugMode(Int) from Int to Int {
    var TTY = 0;
    var FILE = 1;
    var CALLBACK = 2;
}

/** FMOD_INITFLAGS bits. The library composes them from FmodSettings at init, no call takes them. */
enum abstract FmodInitFlags(Int) from Int to Int {
    var NORMAL = 0x00000000;
    var STREAM_FROM_UPDATE = 0x00000001;
    var MIX_FROM_UPDATE = 0x00000002;
    var _3D_RIGHTHANDED = 0x00000004;
    var CLIP_OUTPUT = 0x00000008;
    var CHANNEL_LOWPASS = 0x00000100;
    var CHANNEL_DISTANCEFILTER = 0x00000200;
    var PROFILE_ENABLE = 0x00010000;
    var VOL0_BECOMES_VIRTUAL = 0x00020000;
    var GEOMETRY_USECLOSEST = 0x00040000;
    var PREFER_DOLBY_DOWNMIX = 0x00080000;
    var THREAD_UNSAFE = 0x00100000;
    var PROFILE_METER_ALL = 0x00200000;
    var MEMORY_TRACKING = 0x00400000;
}

/** FMOD_STUDIO_INITFLAGS bits. The library composes them from FmodSettings at init (liveUpdate sets LIVEUPDATE, memoryTracking sets MEMORY_TRACKING), no call takes them. */
enum abstract FmodStudioInitFlags(Int) from Int to Int {
    var NORMAL = 0x00000000;
    var LIVEUPDATE = 0x00000001;
    var ALLOW_MISSING_PLUGINS = 0x00000002;
    var SYNCHRONOUS_UPDATE = 0x00000004;
    var DEFERRED_CALLBACKS = 0x00000008;
    var LOAD_FROM_UPDATE = 0x00000010;
    var MEMORY_TRACKING = 0x00000020;
}

/** FMOD_STUDIO_LOAD_MEMORY_MODE. StudioSystem.loadBankMemory always copies (MEMORY), a Haxe buffer cannot be pinned for the bank's lifetime. */
enum abstract FmodLoadMemoryMode(Int) from Int to Int {
    var MEMORY = 0;
    var MEMORY_POINT = 1;
}

/** FMOD_STUDIO_COMMANDCAPTURE_FLAGS bits, the flags StudioSystem.startCommandCapture takes. */
enum abstract FmodCommandCaptureFlags(Int) from Int to Int {
    var NORMAL = 0x00000000;
    var FILEFLUSH = 0x00000001;
    var SKIP_INITIAL_STATE = 0x00000002;
}

/** FMOD_STUDIO_COMMANDREPLAY_FLAGS bits, the flags StudioSystem.loadCommandReplay takes. */
enum abstract FmodCommandReplayFlags(Int) from Int to Int {
    var NORMAL = 0x00000000;
    var SKIP_CLEANUP = 0x00000001;
    var FAST_FORWARD = 0x00000002;
    var SKIP_BANK_LOAD = 0x00000004;
}

/** FMOD_MEMORY_TYPE bits, the categories FMOD's allocator hooks see. The hooks are not exposed, totals come from StudioSystem.getMemoryStats. */
enum abstract FmodMemoryType(Int) from Int to Int {
    var NORMAL = 0x00000000;
    var STREAM_FILE = 0x00000001;
    var STREAM_DECODE = 0x00000002;
    var SAMPLEDATA = 0x00000004;
    var DSP_BUFFER = 0x00000008;
    var PLUGIN = 0x00000010;
    var PERSISTENT = 0x00200000;
    var ALL = 0xFFFFFFFF;
}

/** FMOD_THREAD_TYPE, FMOD's worker threads. The type field of FmodThreadAttributes in FmodSettings.threadAttributes. */
enum abstract FmodThreadType(Int) from Int to Int {
    var MIXER = 0;
    var FEEDER = 1;
    var STREAM = 2;
    var FILE = 3;
    var NONBLOCKING = 4;
    var RECORD = 5;
    var GEOMETRY = 6;
    var PROFILER = 7;
    var STUDIO_UPDATE = 8;
    var STUDIO_LOAD_BANK = 9;
    var STUDIO_LOAD_SAMPLE = 10;
    var CONVOLUTION1 = 11;
    var CONVOLUTION2 = 12;
    var MAX = 13;
}

/** FMOD_THREAD_PRIORITY, the priority of a worker thread. The priority field of FmodThreadAttributes, DEFAULT keeps FMOD's own value for that thread. */
enum abstract FmodThreadPriority(Int) from Int to Int {
    var PLATFORM_MIN = -32768;
    var PLATFORM_MAX = 32768;
    var DEFAULT = -32769;
    var LOW = -32770;
    var MEDIUM = -32771;
    var HIGH = -32772;
    var VERY_HIGH = -32773;
    var EXTREME = -32774;
    var CRITICAL = -32775;
    var MIXER = -32774;
    var FEEDER = -32775;
    var STREAM = -32773;
    var FILE = -32772;
    var NONBLOCKING = -32772;
    var RECORD = -32772;
    var GEOMETRY = -32770;
    var PROFILER = -32771;
    var STUDIO_UPDATE = -32771;
    var STUDIO_LOAD_BANK = -32771;
    var STUDIO_LOAD_SAMPLE = -32771;
    var CONVOLUTION1 = -32773;
    var CONVOLUTION2 = -32773;
}

/** FMOD_THREAD_STACK_SIZE, the stack of a worker thread in bytes. The stackSize field of FmodThreadAttributes, DEFAULT keeps FMOD's own value for that thread. */
enum abstract FmodThreadStackSize(Int) from Int to Int {
    var DEFAULT = 0;
    var MIXER = 81920;
    var FEEDER = 16384;
    var STREAM = 98304;
    var FILE = 65536;
    var NONBLOCKING = 114688;
    var RECORD = 16384;
    var GEOMETRY = 49152;
    var PROFILER = 131072;
    var STUDIO_UPDATE = 98304;
    var STUDIO_LOAD_BANK = 98304;
    var STUDIO_LOAD_SAMPLE = 98304;
    var CONVOLUTION1 = 16384;
    var CONVOLUTION2 = 16384;
}

/**
 * FMOD_THREAD_AFFINITY as a 32-bit core mask, the affinity field of
 * FmodThreadAttributes. CORE_ALL lets the thread run anywhere, CORE_n bits
 * pin it, and any Int mask of bits 0 to 31 works. FMOD's 64-bit group
 * values (GROUP_DEFAULT, GROUP_A to GROUP_C) do not fit a Haxe Int, so an
 * unset affinity keeps FMOD's default group.
 */
enum abstract FmodThreadAffinity(Int) from Int to Int {
    var CORE_ALL = 0;
    var CORE_0 = 0x00000001;
    var CORE_1 = 0x00000002;
    var CORE_2 = 0x00000004;
    var CORE_3 = 0x00000008;
    var CORE_4 = 0x00000010;
    var CORE_5 = 0x00000020;
    var CORE_6 = 0x00000040;
    var CORE_7 = 0x00000080;
    var CORE_8 = 0x00000100;
    var CORE_9 = 0x00000200;
    var CORE_10 = 0x00000400;
    var CORE_11 = 0x00000800;
    var CORE_12 = 0x00001000;
    var CORE_13 = 0x00002000;
    var CORE_14 = 0x00004000;
    var CORE_15 = 0x00008000;
}

/**
 * One entry of FmodSettings.threadAttributes, applied with
 * FMOD_Thread_SetAttributes before the system is created. An unset
 * priority, stackSize, or affinity keeps FMOD's default for that thread.
 */
typedef FmodThreadAttributes = {
    var type:FmodThreadType;
    @:optional var priority:FmodThreadPriority;
    @:optional var stackSize:FmodThreadStackSize;
    @:optional var affinity:FmodThreadAffinity;
}

//// Named return shapes for the getters that hand back more than one value.
//// FMOD's C# integration returns them as out parameters, Haxe returns one
//// struct with the same words. These are not FMOD header types.

/** What CoreSystem.getChannelsPlaying returns (System::getChannelsPlaying): channels playing including virtual ones, and real voices */
typedef FmodChannelsPlaying = {
    var all:Int;
    var real:Int;
}

/** What CoreSystem.getSoftwareFormat returns (System::getSoftwareFormat) */
typedef FmodSoftwareFormat = {
    var sampleRate:Int;
    var speakerMode:FmodSpeakerMode;
    var rawSpeakers:Int;
}

/** What CoreSystem.get3DSettings returns (System::get3DSettings) */
typedef Fmod3DSettings = {
    var dopplerScale:Float;
    var distanceFactor:Float;
    var rolloffScale:Float;
}

/** What CoreSystem.getDriverInfo returns (System::getDriverInfo), guid in the braced text form */
typedef FmodDriverInfo = {
    var name:String;
    var guid:String;
    var systemRate:Int;
    var speakerMode:FmodSpeakerMode;
    var speakerModeChannels:Int;
}

/** What StudioSystem.getRecordDriverInfo returns (System::getRecordDriverInfo) */
typedef FmodRecordDriverInfo = {
    var name:String;
    var guid:String;
    var systemRate:Int;
    var speakerMode:FmodSpeakerMode;
    var channels:Int;
    var state:FmodDriverState;
}

/** What StudioSystem.getRecordDriverCount returns (System::getRecordNumDrivers): drivers present and drivers connected */
typedef FmodRecordDriverCount = {
    var drivers:Int;
    var connected:Int;
}

/** What CoreSystem.getSpeakerPosition returns (System::getSpeakerPosition) */
typedef FmodSpeakerPosition = {
    var x:Float;
    var y:Float;
    var active:Bool;
}

/** The FMOD_DSP_DESCRIPTION fields CoreSystem.getDspInfoByType and Dsp.getPluginInfo read out of a unit description */
typedef FmodDspDescriptionInfo = {
    var name:String;
    var version:Int;
    var inputBuffers:Int;
    var outputBuffers:Int;
    var parameterCount:Int;
}

/** What Dsp.getInfo returns (DSP::getInfo) */
typedef FmodDspInfo = {
    var name:String;
    var version:Int;
    var channels:Int;
    var configWidth:Int;
    var configHeight:Int;
}

/** What StudioSystem.getPluginInfo returns (System::getPluginInfo) */
typedef FmodPluginInfo = {
    var name:String;
    var type:FmodPluginType;
    var version:Int;
}

/** What StudioSystem.getMemoryStats returns (Memory_GetStats): bytes allocated now and the high water mark */
typedef FmodMemoryStats = {
    var current:Int;
    var maximum:Int;
}

/** What StudioSystem.getFileUsage returns (System::getFileUsage), byte counts as Float since they pass 2^31 */
typedef FmodFileUsage = {
    var sampleBytesRead:Float;
    var streamBytesRead:Float;
    var otherBytesRead:Float;
}

/** What CoreSystem.getDSPBufferSize returns (System::getDSPBufferSize): samples per mixer buffer and buffer count */
typedef FmodDspBufferSize = {
    var bufferLength:Int;
    var numBuffers:Int;
}

/** What CoreSystem.getStreamBufferSize returns (System::getStreamBufferSize): the file buffer size and the unit it is in */
typedef FmodStreamBufferSize = {
    var fileBufferSize:Int;
    var fileBufferSizeType:FmodTimeUnit;
}

/** What Channel.getDspClock and ChannelGroup.getDspClock return (ChannelControl::getDSPClock): own clock and parent clock in samples */
typedef FmodDspClock = {
    var clock:Float;
    var parent:Float;
}

/** What Channel.getDelay and ChannelGroup.getDelay return (ChannelControl::getDelay) */
typedef FmodDelay = {
    var startClock:Float;
    var endClock:Float;
    var stopChannels:Bool;
}

/** What Channel.get3DAttributes and ChannelGroup.get3DAttributes return (ChannelControl::get3DAttributes): position and velocity */
typedef FmodChannel3DAttributes = {
    var posX:Float;
    var posY:Float;
    var posZ:Float;
    var velX:Float;
    var velY:Float;
    var velZ:Float;
}

/** What get3DMinMaxDistance returns on Sound, Channel, and ChannelGroup */
typedef FmodMinMaxDistance = {
    var minDistance:Float;
    var maxDistance:Float;
}

/** What EventDescription.getMinMaxDistance and EventInstance.getMinMaxDistance return */
typedef FmodEventMinMaxDistance = {
    var min:Float;
    var max:Float;
}

/** Direct and reverb occlusion, what get3DOcclusion, Geometry.getOcclusion, and Geometry.getPolygonAttributes report */
typedef FmodOcclusion = {
    var direct:Float;
    var reverb:Float;
}

/** What get3DDistanceFilter returns on Channel and ChannelGroup (ChannelControl::get3DDistanceFilter) */
typedef FmodDistanceFilter = {
    var custom:Bool;
    var customLevel:Float;
    var centerFreq:Float;
}

/** What get3DConeSettings returns on Sound, Channel, and ChannelGroup */
typedef FmodConeSettings = {
    var insideAngle:Float;
    var outsideAngle:Float;
    var outsideVolume:Float;
}

/** What getMixMatrix returns on Channel, ChannelGroup, and DspConnection: the flat row-major matrix with the channel counts FMOD reports */
typedef FmodMixMatrix = {
    var matrix:Array<Float>;
    var outChannels:Int;
    var inChannels:Int;
}

/** One scheduled fade point, what getFadePoints lists (ChannelControl::getFadePoints) */
typedef FmodFadePoint = {
    var clock:Float;
    var volume:Float;
}

/** What Dsp.getWetDryMix returns (DSP::getWetDryMix) */
typedef FmodWetDryMix = {
    var prewet:Float;
    var postwet:Float;
    var dry:Float;
}

/** What Dsp.getMeteringEnabled returns (DSP::getMeteringEnabled) */
typedef FmodMeteringEnabled = {
    var input:Bool;
    var output:Bool;
}

/** What Dsp.getChannelFormat and getOutputChannelFormat return (DSP::getChannelFormat) */
typedef FmodChannelFormat = {
    var channelMask:FmodChannelMask;
    var channels:Int;
    var speakerMode:FmodSpeakerMode;
}

/** What Sound.getDefaults returns (Sound::getDefaults) */
typedef FmodSoundDefaults = {
    var frequency:Float;
    var priority:Int;
}

/** What Sound.getFormat returns (Sound::getFormat) */
typedef FmodSoundFormatInfo = {
    var type:FmodSoundType;
    var format:FmodSoundFormat;
    var channels:Int;
    var bits:Int;
}

/** What Sound.getOpenStateInfo returns (Sound::getOpenState) */
typedef FmodOpenStateInfo = {
    var state:FmodOpenState;
    var percentBuffered:Int;
    var starving:Bool;
    var diskBusy:Bool;
}

/** What Reverb3D.get3DAttributes returns (Reverb3D::get3DAttributes): the zone position and its distance range */
typedef FmodReverb3DAttributes = {
    var x:Float;
    var y:Float;
    var z:Float;
    var minDistance:Float;
    var maxDistance:Float;
}

/** What Geometry.getMaxPolygons returns (Geometry::getMaxPolygons) */
typedef FmodGeometryMaxPolygons = {
    var polygons:Int;
    var vertices:Int;
}

/** What Geometry.getPolygonAttributes returns (Geometry::getPolygonAttributes) */
typedef FmodPolygonAttributes = {
    > FmodOcclusion,
    var doubleSided:Bool;
}

/** What Geometry.getRotation returns (Geometry::getRotation) */
typedef FmodGeometryRotation = {
    var forward:FmodVector;
    var up:FmodVector;
}

/** What CommandReplay.getCurrentCommand returns (Studio::CommandReplay::getCurrentCommand): the command index and the time in seconds */
typedef FmodReplayCommand = {
    var index:Int;
    var time:Float;
}

/** What Bank.getStringInfo returns (Studio::Bank::getStringInfo): a string table entry's GUID in the braced text form and its path */
typedef FmodBankStringInfo = {
    var id:String;
    var path:String;
}

/**
 * FMOD_PORT_INDEX, the port slot CoreSystem.attachChannelGroupToPort
 * takes. FMOD's NONE is the 64-bit all-ones value, which crosses as -1.
 */
enum abstract FmodPortIndex(Int) from Int to Int {
    var NONE = -1;
}

/**
 * The FMOD_MAX_* limits from fmod_common.h and fmod_studio_common.h.
 * tests/native/test_faxe_enums.c pins each one to the header.
 */
class FmodLimits {
    /** FMOD_MAX_CHANNEL_WIDTH, the widest mix matrix and channel format. */
    public static inline var MAX_CHANNEL_WIDTH = 32;
    /** FMOD_MAX_SYSTEMS, how many FMOD systems one process may create. haxefmod creates one. */
    public static inline var MAX_SYSTEMS = 8;
    /** FMOD_MAX_LISTENERS, the cap on StudioSystem.setNumListeners. */
    public static inline var MAX_LISTENERS = 8;
    /** FMOD_REVERB_MAXINSTANCES, the number of reverb instance slots. */
    public static inline var REVERB_MAXINSTANCES = 4;
    /** FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT, the alignment loadBankMemory needs in point mode. */
    public static inline var STUDIO_LOAD_MEMORY_ALIGNMENT = 32;
}

/** FMOD_DSP_RESAMPLER, the interpolation the mixer uses when a sound plays at another rate. FmodSettings.resamplerMethod picks it. */
enum abstract FmodDspResampler(Int) from Int to Int {
    var DEFAULT = 0;
    var NOINTERP = 1;
    var LINEAR = 2;
    var CUBIC = 3;
    var SPLINE = 4;
    var MAX = 5;
}

/** FMOD_DSP_PARAMETER_TYPE, the type field of Dsp.getParameterInfo. Dsp.PARAMETER_* are the same values. */
enum abstract FmodDspParameterType(Int) from Int to Int {
    var FLOAT = 0;
    var INT = 1;
    var BOOL = 2;
    var DATA = 3;
    var MAX = 4;
}

/** FMOD_DSP_PARAMETER_DATA_TYPE, the data parameter kinds Dsp.getDataParameterIndex looks up. USER and above are the plugin's own formats. */
enum abstract FmodDspParameterDataType(Int) from Int to Int {
    var USER = 0;
    var OVERALLGAIN = -1;
    var _3DATTRIBUTES = -2;
    var SIDECHAIN = -3;
    var FFT = -4;
    var _3DATTRIBUTES_MULTI = -5;
    var ATTENUATION_RANGE = -6;
    var DYNAMIC_RESPONSE = -7;
    var FINITE_LENGTH = -8;
}

/** FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE, how a plugin maps a float parameter's range. Plugin authoring is C, declared for reference. */
enum abstract FmodDspParameterFloatMappingType(Int) from Int to Int {
    var LINEAR = 0;
    var AUTO = 1;
    var PIECEWISE_LINEAR = 2;
}

/** FMOD_DSP_PROCESS_OPERATION, the two questions a plugin's process callback answers. Plugin authoring is C, declared for reference. */
enum abstract FmodDspProcessOperation(Int) from Int to Int {
    var PERFORM = 0;
    var QUERY = 1;
}

/** FMOD_DSP_CALLBACK_TYPE, the DSP callback kinds. The callbacks are not exposed, Dsp.setParameterData copies its bytes so nothing needs releasing. */
enum abstract FmodDspCallbackType(Int) from Int to Int {
    var DATAPARAMETERRELEASE = 0;
    var MAX = 1;
}

/** FMOD_DSP_PAN_SURROUND_FLAGS, the flags of a plugin's surround panning helper. Plugin authoring is C, declared for reference. */
enum abstract FmodDspPanSurroundFlags(Int) from Int to Int {
    var DEFAULT = 0;
    var ROTATION_NOT_BIASED = 1;
}

/** FMOD_ERRORCALLBACK_INSTANCETYPE, the object kind an FMOD error callback names. Error callbacks are not exposed, every call returns its FmodResult. */
enum abstract FmodErrorCallbackInstanceType(Int) from Int to Int {
    var NONE = 0;
    var SYSTEM = 1;
    var CHANNEL = 2;
    var CHANNELGROUP = 3;
    var CHANNELCONTROL = 4;
    var SOUND = 5;
    var SOUNDGROUP = 6;
    var DSP = 7;
    var DSPCONNECTION = 8;
    var GEOMETRY = 9;
    var REVERB3D = 10;
    var STUDIO_SYSTEM = 11;
    var STUDIO_EVENTDESCRIPTION = 12;
    var STUDIO_EVENTINSTANCE = 13;
    var STUDIO_PARAMETERINSTANCE = 14;
    var STUDIO_BUS = 15;
    var STUDIO_VCA = 16;
    var STUDIO_BANK = 17;
    var STUDIO_COMMANDREPLAY = 18;
}

/** FMOD_PORT_TYPE, the port kinds CoreSystem.attachChannelGroupToPort takes. Desktop and web builds have no ports and report FMOD_ERR_UNSUPPORTED. */
enum abstract FmodPortType(Int) from Int to Int {
    var MUSIC = 0;
    var COPYRIGHT_MUSIC = 1;
    var VOICE = 2;
    var CONTROLLER = 3;
    var PERSONAL = 4;
    var VIBRATION = 5;
    var AUX = 6;
    var PASSTHROUGH = 7;
    var VR_VIBRATION = 8;
    var MAX = 9;
}

/** FMOD_OUTPUT_METHOD, how an output plugin pulls the mix. Plugin authoring is C, declared for reference. */
enum abstract FmodOutputMethod(Int) from Int to Int {
    var MIX_DIRECT = 0;
    var MIX_BUFFERED = 1;
}

/** FMOD_SYSTEM_CALLBACK_TYPE bits, the core system callback mask. StudioSystem.setSystemCallback delivers DEVICELISTCHANGED and DEVICELOST as SystemEvent, the rest are not delivered. */
enum abstract FmodSystemCallbackType(Int) from Int to Int {
    var DEVICELISTCHANGED = 0x00000001;
    var DEVICELOST = 0x00000002;
    var MEMORYALLOCATIONFAILED = 0x00000004;
    var THREADCREATED = 0x00000008;
    var BADDSPCONNECTION = 0x00000010;
    var PREMIX = 0x00000020;
    var POSTMIX = 0x00000040;
    var ERROR = 0x00000080;
    var THREADDESTROYED = 0x00000100;
    var PREUPDATE = 0x00000200;
    var POSTUPDATE = 0x00000400;
    var RECORDLISTCHANGED = 0x00000800;
    var BUFFEREDNOMIX = 0x00001000;
    var DEVICEREINITIALIZE = 0x00002000;
    var OUTPUTUNDERRUN = 0x00004000;
    var RECORDPOSITIONCHANGED = 0x00008000;
    var ALL = 0xFFFFFFFF;
}

/** FMOD_STUDIO_SYSTEM_CALLBACK_TYPE bits, the studio system callback mask. StudioSystem.setSystemCallback delivers every one of them as SystemEvent. */
enum abstract FmodStudioSystemCallbackType(Int) from Int to Int {
    var PREUPDATE = 0x00000001;
    var POSTUPDATE = 0x00000002;
    var BANK_UNLOAD = 0x00000004;
    var LIVEUPDATE_CONNECTED = 0x00000008;
    var LIVEUPDATE_DISCONNECTED = 0x00000010;
    var ALL = 0xFFFFFFFF;
}
