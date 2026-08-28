package haxefmod.core;

import haxefmod.studio.Types;
import haxefmod.studio.FmodResult;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to an FMOD DSP effect unit.
 *
 * Create with a DspType, set its parameters by index (parameter indices for
 * each effect are in the FMOD DSP effect reference), then attach it to a
 * Channel or ChannelGroup. Handles are plain ints under the hood. A stale
 * or invalid handle makes every call a safe no-op (getters return defaults,
 * setters return FMOD_ERR_INVALID_HANDLE).
 */
abstract Dsp(Int) from Int to Int {
    public static inline var NULL:Dsp = cast 0;

    /** Creates an effect unit. Returns Dsp.NULL on failure. */
    public static inline function create(type:DspType):Dsp {
        return NativeStudio.dsp_create_by_type(type);
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /**
     * Plays this DSP as a sound source (e.g. an OSCILLATOR). Returns
     * Channel.NULL on failure. group routes the new channel into a
     * ChannelGroup from the first sample, null means the master group.
     */
    public inline function play(startPaused:Bool = false, ?group:ChannelGroup):Channel {
        return NativeStudio.sys_play_dsp(this, group == null ? 0 : (group : Int), startPaused);
    }

    public inline function setParameter(index:Int, value:Float):FmodResult {
        return NativeStudio.dsp_set_param_float(this, index, value);
    }

    public inline function getParameter(index:Int):Float {
        return NativeStudio.dsp_get_param_float(this, index);
    }

    /** The same float write as setParameter under FMOD's name. */
    public inline function setParameterFloat(index:Int, value:Float):FmodResult {
        return NativeStudio.dsp_set_param_float(this, index, value);
    }

    /** The same float read as getParameter under FMOD's name. */
    public inline function getParameterFloat(index:Int):Float {
        return NativeStudio.dsp_get_param_float(this, index);
    }

    public inline function setParameterInt(index:Int, value:Int):FmodResult {
        return NativeStudio.dsp_set_param_int(this, index, value);
    }

    public inline function getParameterInt(index:Int):Int {
        return NativeStudio.dsp_get_param_int(this, index);
    }

    public inline function setParameterBool(index:Int, value:Bool):FmodResult {
        return NativeStudio.dsp_set_param_bool(this, index, value);
    }

    public inline function getParameterBool(index:Int):Bool {
        return NativeStudio.dsp_get_param_bool(this, index);
    }

    public inline function getParameterCount():Int {
        return NativeStudio.dsp_get_num_params(this);
    }

    /** The same count as getParameterCount under FMOD's name. */
    public inline function getNumParameters():Int {
        return NativeStudio.dsp_get_num_params(this);
    }

    public inline function getType():DspType {
        return NativeStudio.dsp_get_type(this);
    }

    /** A bypassed effect passes audio through unprocessed. */
    public inline function setBypass(bypass:Bool):FmodResult {
        return NativeStudio.dsp_set_bypass(this, bypass);
    }

    public inline function getBypass():Bool {
        return NativeStudio.dsp_get_bypass(this);
    }

    /** Scales the pre-effect signal, the processed signal, and the dry signal (each 0..1). */
    public inline function setWetDryMix(prewet:Float, postwet:Float, dry:Float):FmodResult {
        return NativeStudio.dsp_set_wet_dry_mix(this, prewet, postwet, dry);
    }

    public inline function setActive(active:Bool):FmodResult {
        return NativeStudio.dsp_set_active(this, active);
    }

    /** Clears the effect's internal state (delay lines, envelopes). */
    public inline function reset():FmodResult {
        return NativeStudio.dsp_reset(this);
    }

    /** Metering must be enabled before getMetering returns data. */
    public inline function setMeteringEnabled(input:Bool, output:Bool):FmodResult {
        return NativeStudio.dsp_set_metering_enabled(this, input, output);
    }

    /**
     * The FMOD_DSP_METERING_INFO of the output side, or of the input side
     * with input set: peakLevel and rmsLevel per channel (linear 0..1),
     * numChannels, and numSamples, the sample count the meter averaged.
     * Null when unavailable (metering disabled for that side, no signal
     * yet, or a stale handle).
     */
    public function getMetering(input:Bool = false):Null<FmodDspMeteringInfo> {
        var channels = NativeStudio.dsp_get_metering_info(this, input);
        if (channels <= 0) return null;
        var peak = [for (i in 0...channels) Scratch.readF(i)];
        var rms = [for (i in 0...channels) Scratch.readF(channels + i)];
        return {numSamples: Scratch.readI(0), peakLevel: peak, rmsLevel: rms, numChannels: Scratch.readI(1)};
    }

    /** The input side of the meter, the signal before this unit processes it. */
    public inline function getInputMetering():Null<FmodDspMeteringInfo> {
        return getMetering(true);
    }

    /**
     * Spectrum magnitudes from an FFT effect (create with DspType.FFT and
     * attach where you want to analyze). Returns null when no data is
     * available yet. maxBins is capped at 512.
     */
    public function getFftSpectrum(maxBins:Int = 512):Null<Array<Float>> {
        if (maxBins > 512) maxBins = 512;
        var bins = NativeStudio.dsp_fft_get_spectrum(this, maxBins);
        if (bins <= 0) return null;
        return [for (i in 0...bins) Scratch.readF(i)];
    }

    /**
     * The whole FFT payload: the bin count, the channel count, and one
     * magnitude array per channel, each capped at maxBins (512 at most).
     * Null when no data is available yet.
     */
    public function getFftSpectrumInfo(maxBins:Int = 512):Null<FmodDspParameterFft> {
        if (maxBins > 512) maxBins = 512;
        var bins = NativeStudio.dsp_fft_get_spectrum_channel(this, 0, maxBins);
        var numChannels = Scratch.readI(0);
        var length = Scratch.readI(1);
        if (bins <= 0 || numChannels <= 0) return null;
        var spectrum = [[for (i in 0...bins) Scratch.readF(i)]];
        for (channel in 1...numChannels) {
            var count = NativeStudio.dsp_fft_get_spectrum_channel(this, channel, maxBins);
            spectrum.push([for (i in 0...count) Scratch.readF(i)]);
        }
        return {length: length, numChannels: numChannels, spectrum: spectrum};
    }

    /**
     * Wires another DSP's output into this one, building custom mixer
     * topologies. Returns the connection (DspConnection.NULL on failure).
     * Any later graph change invalidates all connection handles.
     */
    public inline function addInput(input:Dsp, connectionType:DspConnectionType = DspConnectionType.STANDARD):DspConnection {
        return NativeStudio.dsp_add_input(this, input, connectionType);
    }

    /**
     * Removes the link from `input` into this unit. With no connection
     * given, every connection between the two goes. A connection narrows
     * it to that one link, and a stale connection handle reports
     * FMOD_ERR_INVALID_HANDLE. Any graph change invalidates every
     * connection handle.
     */
    public inline function disconnectFrom(input:Dsp, connection:DspConnection = DspConnection.NULL):FmodResult {
        return NativeStudio.dsp_disconnect_from(this, input, connection);
    }

    public inline function disconnectAll(inputs:Bool = true, outputs:Bool = true):FmodResult {
        return NativeStudio.dsp_disconnect_all(this, inputs, outputs);
    }

    public inline function getInputCount():Int {
        return NativeStudio.dsp_get_num_inputs(this);
    }

    public inline function getOutputCount():Int {
        return NativeStudio.dsp_get_num_outputs(this);
    }

    /** The same count as getInputCount under FMOD's name. */
    public inline function getNumInputs():Int {
        return NativeStudio.dsp_get_num_inputs(this);
    }

    /** The same count as getOutputCount under FMOD's name. */
    public inline function getNumOutputs():Int {
        return NativeStudio.dsp_get_num_outputs(this);
    }

    /** The DSP feeding input slot `index` (a known DSP returns its existing handle). */
    public inline function getInput(index:Int):Dsp {
        return NativeStudio.dsp_get_input_dsp(this, index);
    }

    public inline function getInputConnection(index:Int):DspConnection {
        return NativeStudio.dsp_get_input_connection(this, index);
    }

    public function getWetDryMix():Null<FmodWetDryMix> {
        var result:FmodResult = NativeStudio.dsp_get_wet_dry_mix(this);
        if (!result.isOk()) return null;
        return {prewet: Scratch.readF(0), postwet: Scratch.readF(1), dry: Scratch.readF(2)};
    }

    public inline function getActive():Bool {
        return NativeStudio.dsp_get_active(this);
    }

    public function getMeteringEnabled():Null<FmodMeteringEnabled> {
        var result:FmodResult = NativeStudio.dsp_get_metering_enabled(this);
        if (!result.isOk()) return null;
        return {input: Scratch.readI(0) != 0, output: Scratch.readI(1) != 0};
    }

    /**
     * Uploads a data parameter payload (byte layout per the effect's
     * contract, e.g. a convolution impulse response: 16-bit samples with
     * the channel count as the first value).
     */
    public inline function setParameterData(index:Int, data:haxe.io.Bytes):FmodResult {
        return NativeStudio.dsp_set_param_data(this, index, data, data.length);
    }

    /** True when no signal has flowed through the unit recently. */
    public inline function isIdle():Bool {
        return NativeStudio.dsp_get_idle(this);
    }

    /** The effect's display name (e.g. "FMOD Convolution Reverb"). */
    public inline function getName():String {
        return NativeStudio.dsp_get_info_name(this);
    }

    /** The DSP fed by output slot `index` (a known DSP returns its existing handle). */
    public inline function getOutput(index:Int):Dsp {
        return NativeStudio.dsp_get_output_dsp(this, index);
    }

    public inline function getOutputConnection(index:Int):DspConnection {
        return NativeStudio.dsp_get_output_connection(this, index);
    }

    /** Microseconds spent in this DSP per mix, or null (needs profiling enabled at init). */
    public function getCpuUsage():Null<FmodCpuUsage> {
        var result:FmodResult = NativeStudio.dsp_get_cpu_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1)};
    }

    /** The parameter types getParameterInfo reports, the same values as FmodDspParameterType. */
    public static inline var PARAMETER_FLOAT:FmodDspParameterType = FmodDspParameterType.FLOAT;
    public static inline var PARAMETER_INT:FmodDspParameterType = FmodDspParameterType.INT;
    public static inline var PARAMETER_BOOL:FmodDspParameterType = FmodDspParameterType.BOOL;
    public static inline var PARAMETER_DATA:FmodDspParameterType = FmodDspParameterType.DATA;

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The FMOD_DSP_PARAMETER_DESC of the parameter at index (unsupported
     * in HTML5, null there): type, name, label, description, and the
     * union member matching type. floatDesc carries the range, default,
     * and mapping of a float parameter, intDesc the range, default,
     * goesToInf, and valueNames of an int parameter, boolDesc the
     * default and valueNames of a bool parameter, dataDesc the dataType
     * of a data parameter. The other three members are null. valueNames
     * is null when the unit names no values. Null on failure.
     */
    public macro function getParameterInfo(self:haxe.macro.Expr, index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Dsp.getParameterInfo", "FMOD's web glue cannot marshal the parameter descriptor");
    }
    #else
    /**
     * The FMOD_DSP_PARAMETER_DESC of the parameter at index (unsupported
     * in HTML5, null there): type, name, label, description, and the
     * union member matching type. floatDesc carries the range, default,
     * and mapping of a float parameter, intDesc the range, default,
     * goesToInf, and valueNames of an int parameter, boolDesc the
     * default and valueNames of a bool parameter, dataDesc the dataType
     * of a data parameter. The other three members are null. valueNames
     * is null when the unit names no values. Null on failure.
     */
    public function getParameterInfo(index:Int):Null<FmodDspParameterDesc> {
        var name = NativeStudio.dsp_get_parameter_info(this, index);
        var result:FmodResult = haxefmod.studio.StudioSystem.lastResult();
        if (!result.isOk()) return null;
        var type:FmodDspParameterType = Scratch.readI(0);
        var mappingType:FmodDspParameterFloatMappingType = Scratch.readI(1);
        var goesToInf = Scratch.readI(2) != 0;
        var dataType:FmodDspParameterDataType = Scratch.readI(3);
        var points = Scratch.readI(4);
        var min = Scratch.readF(0);
        var max = Scratch.readF(1);
        var defaultVal = Scratch.readF(2);
        var pointParamValues = [for (i in 0...points) Scratch.readF(3 + i)];
        var pointPositions = [for (i in 0...points) Scratch.readF(3 + points + i)];
        var label = NativeStudio.dsp_get_parameter_text(this, index, 0);
        var description = NativeStudio.dsp_get_parameter_text(this, index, 1);
        var valueNames = null;
        var nameCount = type == FmodDspParameterType.INT ? Std.int(max - min) + 1 : (type == FmodDspParameterType.BOOL ? 2 : 0);
        if (nameCount > 0 && nameCount <= 256) {
            var first = NativeStudio.dsp_get_parameter_text(this, index, 2);
            if (first != "") {
                valueNames = [first];
                for (i in 1...nameCount) valueNames.push(NativeStudio.dsp_get_parameter_text(this, index, 2 + i));
            }
        }
        var desc:FmodDspParameterDesc = {type: type, name: name, label: label, description: description,
            floatDesc: null, intDesc: null, boolDesc: null, dataDesc: null};
        switch (type) {
            case FmodDspParameterType.FLOAT:
                desc.floatDesc = {min: min, max: max, defaultVal: defaultVal, mapping: {type: mappingType,
                    piecewiseLinearMapping: {numPoints: points, pointParamValues: pointParamValues, pointPositions: pointPositions}}};
            case FmodDspParameterType.INT:
                desc.intDesc = {min: Std.int(min), max: Std.int(max), defaultVal: Std.int(defaultVal), goesToInf: goesToInf, valueNames: valueNames};
            case FmodDspParameterType.BOOL:
                desc.boolDesc = {defaultVal: defaultVal != 0, valueNames: valueNames};
            case FmodDspParameterType.DATA:
                desc.dataDesc = {dataType: dataType};
            default:
        }
        return desc;
    }
    #end

    /**
     * The index of the data parameter carrying the given
     * FmodDspParameterDataType (negative values are FMOD's own types, 0
     * and up are user data), -1 when the effect has none or on failure.
     */
    public inline function getDataParameterIndex(dataType:FmodDspParameterDataType):Int {
        return NativeStudio.dsp_get_data_parameter_index(this, dataType);
    }

    /**
     * Fixes the unit's input format to the given channel mask, channel
     * count, and speaker mode. 0 channels goes back to inheriting the
     * format from the input.
     */
    public inline function setChannelFormat(channelMask:FmodChannelMask, channels:Int, speakerMode:FmodSpeakerMode):FmodResult {
        return NativeStudio.dsp_set_channel_format(this, channelMask, channels, speakerMode);
    }

    public function getChannelFormat():Null<FmodChannelFormat> {
        var result:FmodResult = NativeStudio.dsp_get_channel_format(this);
        if (!result.isOk()) return null;
        return {channelMask: Scratch.readI(0), channels: Scratch.readI(1), speakerMode: Scratch.readI(2)};
    }

    /** The format the unit would emit when fed the given input format, or null on failure. */
    public function getOutputChannelFormat(inMask:FmodChannelMask, inChannels:Int, inSpeakerMode:FmodSpeakerMode):Null<FmodChannelFormat> {
        var result:FmodResult = NativeStudio.dsp_get_output_channel_format(this, inMask, inChannels, inSpeakerMode);
        if (!result.isOk()) return null;
        return {channelMask: Scratch.readI(0), channels: Scratch.readI(1), speakerMode: Scratch.readI(2)};
    }

    /** Releases the effect and invalidates this handle. Detach it first. */
    public inline function release():FmodResult {
        UserData.clear(UserDataKind.Dsp, this);
        return NativeStudio.dsp_release(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.Dsp, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.Dsp, this);
    }
    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Creates an effect unit from a plugin loaded with
     * StudioSystem.loadPlugin (unsupported in HTML5, returns Dsp.NULL
     * there). Returns Dsp.NULL on failure. Release it before unloading
     * the plugin.
     */
    public static macro function createByPlugin(pluginHandle:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Dsp.createByPlugin", "the web build has no plugin host");
    }
    #else
    /**
     * Creates an effect unit from a plugin loaded with
     * StudioSystem.loadPlugin (unsupported in HTML5, returns Dsp.NULL
     * there). Returns Dsp.NULL on failure. Release it before unloading
     * the plugin.
     */
    public static inline function createByPlugin(pluginHandle:Int):Dsp {
        return NativeStudio.dsp_create_by_plugin(pluginHandle);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The description a DSP plugin registered, its name, version, buffer
     * counts and parameter count (unsupported in HTML5, null there). Null
     * for a handle that is not a DSP plugin.
     */
    public static macro function getPluginInfo(pluginHandle:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Dsp.getPluginInfo", "the web build has no plugin host");
    }
    #else
    /**
     * The description a DSP plugin registered, its name, version, buffer
     * counts and parameter count (unsupported in HTML5, null there). Null
     * for a handle that is not a DSP plugin.
     */
    public static function getPluginInfo(pluginHandle:Int):Null<FmodDspDescriptionInfo> {
        var name = NativeStudio.dsp_get_info_by_plugin(pluginHandle);
        var result:FmodResult = NativeStudio.sys_last_result();
        if (!result.isOk()) return null;
        return {name: name, version: Scratch.readI(0), inputBuffers: Scratch.readI(1),
            outputBuffers: Scratch.readI(2), parameterCount: Scratch.readI(3)};
    }
    #end
    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Wires another DSP's output into this one through a connection FMOD
     * reserved ahead of time, so the mixer allocates nothing on the way in
     * (unsupported in HTML5, returns DspConnection.NULL there). Returns
     * the connection (DspConnection.NULL on failure). FMOD only accepts a
     * connection it reserved itself, so with the connections this library
     * can hand over it reports FMOD_ERR_INVALID_PARAM, and a NULL or stale
     * connection reports FMOD_ERR_INVALID_HANDLE without reaching FMOD.
     */
    public macro function addInputPreallocated(self:haxe.macro.Expr, input:haxe.macro.Expr, connection:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Dsp.addInputPreallocated", "the web build has no addInputPreallocated");
    }
    #else
    /**
     * Wires another DSP's output into this one through a connection FMOD
     * reserved ahead of time, so the mixer allocates nothing on the way in
     * (unsupported in HTML5, returns DspConnection.NULL there). Returns
     * the connection (DspConnection.NULL on failure). FMOD only accepts a
     * connection it reserved itself, so with the connections this library
     * can hand over it reports FMOD_ERR_INVALID_PARAM, and a NULL or stale
     * connection reports FMOD_ERR_INVALID_HANDLE without reaching FMOD.
     */
    public inline function addInputPreallocated(input:Dsp, connection:DspConnection):DspConnection {
        return NativeStudio.dsp_add_input_preallocated(this, input, connection);
    }
    #end

    /**
     * The unit's description: display name, plugin version (BCD, 0x10000
     * is 1.0), channel count (0 when the unit takes any), and the config
     * dialog size a plugin declares. Null on failure.
     */
    public function getInfo():Null<FmodDspInfo> {
        var name = NativeStudio.dsp_get_info(this);
        var result:FmodResult = haxefmod.studio.StudioSystem.lastResult();
        if (!result.isOk()) return null;
        return {name: name, version: Scratch.readI(0), channels: Scratch.readI(1), configWidth: Scratch.readI(2), configHeight: Scratch.readI(3)};
    }

    /**
     * A copy of the data block behind a data parameter, laid out as the
     * effect's C struct (little endian, read it with haxe.io.Bytes
     * getFloat and getInt32). The length is the one FMOD reports.
     * Pointer fields inside a block, such as the FFT spectrum arrays,
     * carry nothing useful in the copy, getFftSpectrumInfo reads those.
     * Null when the parameter has no data yet or on failure. On HTML5
     * the web glue types the block instead of exposing its bytes, so
     * only overall gain, FFT, dynamic response, and attenuation range
     * payloads come back and the rest report FMOD_ERR_UNSUPPORTED.
     */
    public function getParameterData(index:Int):Null<haxe.io.Bytes> {
        var length = NativeStudio.dsp_get_param_data(this, index, null, 0);
        if (length <= 0) return null;
        var bytes = haxe.io.Bytes.alloc(length);
        var copied = NativeStudio.dsp_get_param_data(this, index, bytes, length);
        if (copied < 0) return null;
        return bytes;
    }

    /**
     * The FMOD_DSP_PARAMETER_OVERALLGAIN payload of the unit, the gain it
     * reports for FMOD's virtual voice ranking. index defaults to the
     * unit's own overall gain parameter (getDataParameterIndex). Null
     * when the unit has none or on failure.
     */
    public function getOverallGain(index:Int = -1):Null<FmodDspParameterOverallGain> {
        if (index < 0) index = getDataParameterIndex(FmodDspParameterDataType.OVERALLGAIN);
        if (index < 0) return null;
        var bytes = getParameterData(index);
        if (bytes == null || bytes.length < 8) return null;
        return {linearGain: bytes.getFloat(0), linearGainAdditive: bytes.getFloat(4)};
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The readback of a DspType.LOUDNESS_METER unit, its
     * FMOD_DSP_LOUDNESS_METER_INFO_TYPE payload (unsupported in HTML5,
     * null there). Loudness values are in LUFS. Null before the meter
     * has measured anything or on failure.
     */
    public macro function getLoudnessMeterInfo(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Dsp.getLoudnessMeterInfo", "FMOD's web glue returns the loudness payload without its fields");
    }
    #else
    /**
     * The readback of a DspType.LOUDNESS_METER unit, its
     * FMOD_DSP_LOUDNESS_METER_INFO_TYPE payload (unsupported in HTML5,
     * null there). Loudness values are in LUFS. Null before the meter
     * has measured anything or on failure.
     */
    public function getLoudnessMeterInfo():Null<FmodDspLoudnessMeterInfo> {
        var bytes = getParameterData(haxefmod.core.DspParameters.DspLoudnessMeter.INFO);
        if (bytes == null || bytes.length < LOUDNESS_INFO_BYTES) return null;
        return {
            momentaryLoudness: bytes.getFloat(0),
            shortTermLoudness: bytes.getFloat(4),
            integratedLoudness: bytes.getFloat(8),
            loudness10thPercentile: bytes.getFloat(12),
            loudness95thPercentile: bytes.getFloat(16),
            loudnessHistogram: [for (i in 0...LOUDNESS_HISTOGRAM_BINS) bytes.getFloat(20 + i * 4)],
            maxTruePeak: bytes.getFloat(20 + LOUDNESS_HISTOGRAM_BINS * 4),
            maxMomentaryLoudness: bytes.getFloat(24 + LOUDNESS_HISTOGRAM_BINS * 4)
        };
    }
    #end

    /** FMOD_DSP_LOUDNESS_METER_HISTOGRAM_SAMPLES and the byte size of the loudness payload. */
    public static inline var LOUDNESS_HISTOGRAM_BINS:Int = 66;
    public static inline var LOUDNESS_INFO_BYTES:Int = (5 + LOUDNESS_HISTOGRAM_BINS + 2) * 4;

    /** The listener count FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI holds at most (FMOD_MAX_LISTENERS). */
    public static inline var MAX_LISTENERS:Int = 8;

    static function writeAttributes(at:Int, attributes:Fmod3DAttributes):Void {
        Scratch.writeF(at, attributes.position.x); Scratch.writeF(at + 1, attributes.position.y); Scratch.writeF(at + 2, attributes.position.z);
        Scratch.writeF(at + 3, attributes.velocity.x); Scratch.writeF(at + 4, attributes.velocity.y); Scratch.writeF(at + 5, attributes.velocity.z);
        Scratch.writeF(at + 6, attributes.forward.x); Scratch.writeF(at + 7, attributes.forward.y); Scratch.writeF(at + 8, attributes.forward.z);
        Scratch.writeF(at + 9, attributes.up.x); Scratch.writeF(at + 10, attributes.up.y); Scratch.writeF(at + 11, attributes.up.z);
    }

    /**
     * Sets a data parameter of type FmodDspParameterDataType._3DATTRIBUTES
     * (FMOD_DSP_PARAMETER_3DATTRIBUTES). absolute is the emitter in world
     * space, relative the emitter in the listener's space. relative
     * defaults to absolute, which holds while the listener sits at the
     * origin facing along its forward vector. The shim packs the struct.
     */
    public function setParameter3DAttributes(index:Int, absolute:Fmod3DAttributes, ?relative:Fmod3DAttributes):FmodResult {
        if (absolute == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        writeAttributes(0, relative == null ? absolute : relative);
        writeAttributes(12, absolute);
        return NativeStudio.dsp_set_param_3d_attributes(this, index);
    }

    /**
     * Sets a data parameter of type
     * FmodDspParameterDataType._3DATTRIBUTES_MULTI
     * (FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI), the position of an
     * object panner or pan unit for every listener. relative holds the
     * emitter in each listener's space, one entry per listener (1 to
     * MAX_LISTENERS), weights the per listener blend (1 each when
     * omitted), absolute the emitter in world space. The shim packs the
     * struct. FMOD_ERR_INVALID_PARAM for an empty or oversized list.
     */
    public function setParameter3DAttributesMulti(index:Int, absolute:Fmod3DAttributes, relative:Array<Fmod3DAttributes>, ?weights:Array<Float>):FmodResult {
        if (absolute == null || relative == null || relative.length < 1 || relative.length > MAX_LISTENERS) {
            return FmodResult.FMOD_ERR_INVALID_PARAM;
        }
        for (i in 0...relative.length) {
            writeAttributes(i * 12, relative[i]);
            Scratch.writeF(MAX_LISTENERS * 12 + i, weights != null && i < weights.length ? weights[i] : 1.0);
        }
        writeAttributes(MAX_LISTENERS * 12 + MAX_LISTENERS, absolute);
        return NativeStudio.dsp_set_param_3d_attributes_multi(this, index, relative.length);
    }

    /** The kinds dsp_set_param_typed and dsp_get_param_typed pack, the same numbers as native/shared/faxe_dspdata.h. */
    static inline var KIND_SIDECHAIN:Int = 1;
    static inline var KIND_FINITE_LENGTH:Int = 2;
    static inline var KIND_ATTENUATION_RANGE:Int = 3;
    static inline var KIND_DYNAMIC_RESPONSE:Int = 4;
    static inline var KIND_LOUDNESS_WEIGHTING:Int = 5;

    /** The channel slots FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE and FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE hold. */
    public static inline var MAX_CHANNEL_SLOTS:Int = 32;

    /**
     * Sets a data parameter of type FmodDspParameterDataType.SIDECHAIN
     * (FMOD_DSP_PARAMETER_SIDECHAIN), for example
     * DspCompressor.USESIDECHAIN. The shim packs the struct.
     */
    public function setParameterSidechain(index:Int, props:FmodDspParameterSidechain):FmodResult {
        if (props == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        Scratch.writeF(0, props.sidechainEnable ? 1 : 0);
        return NativeStudio.dsp_set_param_typed(this, index, KIND_SIDECHAIN);
    }

    /** Reads a FmodDspParameterDataType.SIDECHAIN data parameter back. Null on failure. */
    public function getParameterSidechain(index:Int):Null<FmodDspParameterSidechain> {
        var result:FmodResult = NativeStudio.dsp_get_param_typed(this, index, KIND_SIDECHAIN);
        if (!result.isOk()) return null;
        return {sidechainEnable: Scratch.readF(0) != 0};
    }

    /**
     * Sets a data parameter of type FmodDspParameterDataType.FINITE_LENGTH
     * (FMOD_DSP_PARAMETER_FINITE_LENGTH). The shim packs the struct.
     */
    public function setParameterFiniteLength(index:Int, props:FmodDspParameterFiniteLength):FmodResult {
        if (props == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        Scratch.writeF(0, props.finite ? 1 : 0);
        return NativeStudio.dsp_set_param_typed(this, index, KIND_FINITE_LENGTH);
    }

    /** Reads a FmodDspParameterDataType.FINITE_LENGTH data parameter back. Null on failure. */
    public function getParameterFiniteLength(index:Int):Null<FmodDspParameterFiniteLength> {
        var result:FmodResult = NativeStudio.dsp_get_param_typed(this, index, KIND_FINITE_LENGTH);
        if (!result.isOk()) return null;
        return {finite: Scratch.readF(0) != 0};
    }

    /**
     * Sets a data parameter of type
     * FmodDspParameterDataType.ATTENUATION_RANGE
     * (FMOD_DSP_PARAMETER_ATTENUATION_RANGE), the distance range of a
     * pan or object pan unit. The shim packs the struct.
     */
    public function setParameterAttenuationRange(index:Int, props:FmodDspParameterAttenuationRange):FmodResult {
        if (props == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        Scratch.writeF(0, props.min);
        Scratch.writeF(1, props.max);
        return NativeStudio.dsp_set_param_typed(this, index, KIND_ATTENUATION_RANGE);
    }

    /**
     * Reads a FmodDspParameterDataType.ATTENUATION_RANGE data parameter
     * back. Null on failure, which the built-in pan units report because
     * they only take the range.
     */
    public function getParameterAttenuationRange(index:Int):Null<FmodDspParameterAttenuationRange> {
        var result:FmodResult = NativeStudio.dsp_get_param_typed(this, index, KIND_ATTENUATION_RANGE);
        if (!result.isOk()) return null;
        return {min: Scratch.readF(0), max: Scratch.readF(1)};
    }

    /**
     * Reads a FmodDspParameterDataType.DYNAMIC_RESPONSE data parameter
     * (FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE), the RMS level per channel a
     * dynamics plugin reports. Null on failure.
     */
    public function getParameterDynamicResponse(index:Int):Null<FmodDspParameterDynamicResponse> {
        var result:FmodResult = NativeStudio.dsp_get_param_typed(this, index, KIND_DYNAMIC_RESPONSE);
        if (!result.isOk()) return null;
        var channels = Scratch.readI(0);
        if (channels < 0) channels = 0;
        if (channels > MAX_CHANNEL_SLOTS) channels = MAX_CHANNEL_SLOTS;
        return {numChannels: channels, rms: [for (i in 0...channels) Scratch.readF(i)]};
    }

    /**
     * Sets the FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE of a
     * DspType.LOUDNESS_METER unit, its DspLoudnessMeter.WEIGHTING data
     * parameter. channelWeight holds up to MAX_CHANNEL_SLOTS weights,
     * the rest are 0. The shim packs the struct.
     */
    public function setLoudnessMeterWeighting(weighting:FmodDspLoudnessMeterWeightingType):FmodResult {
        if (weighting == null || weighting.channelWeight == null || weighting.channelWeight.length > MAX_CHANNEL_SLOTS) {
            return FmodResult.FMOD_ERR_INVALID_PARAM;
        }
        for (i in 0...MAX_CHANNEL_SLOTS) Scratch.writeF(i, i < weighting.channelWeight.length ? weighting.channelWeight[i] : 0);
        return NativeStudio.dsp_set_param_typed(this, haxefmod.core.DspParameters.DspLoudnessMeter.WEIGHTING, KIND_LOUDNESS_WEIGHTING);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Reads the FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE of a
     * DspType.LOUDNESS_METER unit back, all MAX_CHANNEL_SLOTS weights
     * (unsupported in HTML5, null there). Null on failure.
     */
    public macro function getLoudnessMeterWeighting(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Dsp.getLoudnessMeterWeighting", "FMOD's web glue returns the weighting payload without its fields");
    }
    #else
    /**
     * Reads the FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE of a
     * DspType.LOUDNESS_METER unit back, all MAX_CHANNEL_SLOTS weights
     * (unsupported in HTML5, null there). Null on failure.
     */
    public function getLoudnessMeterWeighting():Null<FmodDspLoudnessMeterWeightingType> {
        var result:FmodResult = NativeStudio.dsp_get_param_typed(this, haxefmod.core.DspParameters.DspLoudnessMeter.WEIGHTING, KIND_LOUDNESS_WEIGHTING);
        if (!result.isOk()) return null;
        return {channelWeight: [for (i in 0...MAX_CHANNEL_SLOTS) Scratch.readF(i)]};
    }
    #end
}
