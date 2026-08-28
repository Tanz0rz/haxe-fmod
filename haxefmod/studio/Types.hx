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

/** Flags for StudioSystem.loadBankFile */
enum abstract FmodLoadBankFlags(Int) from Int to Int {
    var NORMAL = 0;
    var NONBLOCKING = 1;
}
/** One command in a loaded capture (FMOD_STUDIO_COMMAND_INFO) */
typedef FmodCommandInfo = {
    var commandName:String;
    var parentCommandIndex:Int;
    var frameNumber:Int;
    var frameTime:Float;
    var instanceType:Int;
    var outputType:Int;
    var instanceHandle:Int;
    var outputHandle:Int;
}

/** FMOD_PLUGINTYPE, the plugin categories StudioSystem.getPluginCount enumerates */
enum abstract FmodPluginType(Int) from Int to Int {
    var OUTPUT = 0;
    var CODEC = 1;
    var DSP = 2;
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
}

/** Studio advanced settings as FMOD holds them (FMOD_STUDIO_ADVANCEDSETTINGS without the key). */
typedef FmodStudioAdvancedSettings = {
    var commandQueueSize:Int;
    var handleInitialSize:Int;
    var studioUpdatePeriod:Int;
    var idleSampleDataPoolSize:Int;
    var streamingScheduleDelay:Int;
}

/** Where a tag came from (FMOD_TAGTYPE) */
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
}

/** What a tag's payload holds (FMOD_TAGDATATYPE) */
enum abstract FmodTagDataType(Int) from Int to Int {
    var BINARY = 0;
    var INT = 1;
    var FLOAT = 2;
    var STRING = 3;
    var STRING_UTF16 = 4;
    var STRING_UTF16BE = 5;
    var STRING_UTF8 = 6;
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
