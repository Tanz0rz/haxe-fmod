package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.Channel;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.PcmStream;

/**
 * CI test state proving Haxe-generated PCM reaches the audio output.
 *
 * Plays six tone segments through PcmStream so the recording can be
 * frequency-gated by ci/audio-profile.py --synth:
 *   Segment 1: 4s of a 440Hz sine
 *   Segment 2: 4s of an 880Hz sine
 *   Segment 3: 660Hz sine data played at pitch 2.0. It must measure as
 *              1320Hz, proving channel pitch control end to end. Hearing
 *              660Hz here means the pitch never reached FMOD.
 *   Segment 4: 300Hz and 5kHz mixed, played raw. Both tones must measure.
 *   Segment 5: the same mix with a LOWPASS_SIMPLE at 800Hz on the channel.
 *              300Hz must still measure while 5kHz must be gone, proving a
 *              DSP effect audibly transforms the audio.
 *   Segment 6: 500Hz with fade points scheduled on the mixer clock from
 *              full volume down to near silence across the segment. The
 *              recording must show the ramp, proving sample-accurate
 *              scheduling end to end (fades ride the DSP clock, so this
 *              holds at any mixing speed).
 *
 * Each segment is its own stream with a ring sized to hold the whole
 * segment, prefilled before playback starts. That keeps the recorded
 * segments aligned with the data at any mixing speed (WAVWRITER mixes
 * faster than real time) with no underruns until the data runs out.
 *
 * Audio is recorded externally and validated by ci/validate-synth.sh.
 */
class SynthTestState extends FlxState {
    static inline var RATE:Int = 48000;
    static inline var SEGMENT_SECONDS:Int = 4;
    static inline var AMPLITUDE:Int = 0x5000;

    // {data frequencies (freq2 = 0 for a pure tone), channel pitch,
    //  lowpass = attach LOWPASS_SIMPLE at 800Hz before playing} per segment
    static var SEGMENTS:Array<{freq:Float, freq2:Float, pitch:Float, lowpass:Bool, fade:Bool}> = [
        {freq: 440.0, freq2: 0.0, pitch: 1.0, lowpass: false, fade: false},
        {freq: 880.0, freq2: 0.0, pitch: 1.0, lowpass: false, fade: false},
        {freq: 660.0, freq2: 0.0, pitch: 2.0, lowpass: false, fade: false},
        {freq: 300.0, freq2: 5000.0, pitch: 1.0, lowpass: false, fade: false},
        {freq: 300.0, freq2: 5000.0, pitch: 1.0, lowpass: true, fade: false},
        {freq: 500.0, freq2: 0.0, pitch: 1.0, lowpass: false, fade: true},
    ];

    var _segment:Int = -1;
    var _stream:PcmStream = PcmStream.NULL;
    var _channel:Channel = Channel.NULL;
    var _lowpass:Dsp = Dsp.NULL;
    var _capacity:Int = 0;
    var _complete:Bool = false;
    var _failed:Bool = false;
    var _framesWaited:Int = 0;
    var _status:FlxText;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (!pass) _failed = true;
        log('SYNTH_TEST: $name pass=$pass $detail');
    }

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();

        _status = new FlxText(0, 0, FlxG.width, "SYNTH_TEST running");
        _status.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        _status.y = (FlxG.height / 2) - (_status.height / 2);
        add(_status);

        log("SYNTH_TEST: Starting");
        startSegment(0);
    }

    function startSegment(index:Int):Void {
        _segment = index;
        var seg = SEGMENTS[index];
        var samples = RATE * SEGMENT_SECONDS;

        _stream = PcmStream.create(RATE, 1, samples * 2);
        check('segment${index + 1}_create', !_stream.isNull(), 'handle=${(_stream : Int)}');
        if (_stream.isNull()) {
            finish();
            return;
        }
        _capacity = _stream.space();

        // The whole segment goes into the ring before playback starts.
        // Mixed segments halve each tone's amplitude to stay clear of
        // clipping.
        var data = haxe.io.Bytes.alloc(samples * 2);
        var amplitude = seg.freq2 > 0 ? AMPLITUDE >> 1 : AMPLITUDE;
        for (i in 0...samples) {
            var sample = Math.sin(2 * Math.PI * seg.freq * i / RATE);
            if (seg.freq2 > 0) sample += Math.sin(2 * Math.PI * seg.freq2 * i / RATE);
            var v = Std.int(sample * amplitude);
            data.setUInt16(i * 2, v & 0xFFFF);
        }
        var wrote = _stream.write(data);
        check('segment${index + 1}_prefill', wrote == data.length, 'wrote=$wrote of ${data.length}');

        _channel = _stream.play(true);
        check('segment${index + 1}_play', !_channel.isNull(), 'handle=${(_channel : Int)}');
        if (seg.pitch != 1.0) {
            var result = _channel.setPitch(seg.pitch);
            check('segment${index + 1}_pitch', result.isOk(), 'result=${result.toString()}');
        }
        if (seg.lowpass) {
            _lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
            check('segment${index + 1}_dsp_create', !_lowpass.isNull(), 'handle=${(_lowpass : Int)}');
            var cutoff = _lowpass.setParameter(0, 800);
            check('segment${index + 1}_dsp_cutoff', cutoff.isOk(), 'result=${cutoff.toString()}');
            var attach = _channel.addDsp(0, _lowpass);
            check('segment${index + 1}_dsp_attach', attach.isOk(), 'result=${attach.toString()}');
        }
        if (seg.fade) {
            // Fades schedule on the parent group clock in output samples,
            // so the ramp spans exactly the segment's audio at any speed
            var clocks = _channel.getDspClock();
            check('segment${index + 1}_clock', clocks != null,
                clocks == null ? "" : 'parent=${clocks.parent}');
            if (clocks != null) {
                var full = _channel.addFadePoint(clocks.parent, 1.0);
                var faded = _channel.addFadePoint(clocks.parent + samples, 0.02);
                check('segment${index + 1}_fade_points', full.isOk() && faded.isOk(),
                    'full=${full.toString()} faded=${faded.toString()}');
            }
        }
        _channel.setPaused(false);

        _status.text = 'SYNTH_TEST segment ${index + 1}';
        log('SYNTH_TEST: segment ${index + 1} freq=${seg.freq} pitch=${seg.pitch}');
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (_complete) {
            // Give the renderer a few frames so the result text is visible
            _framesWaited++;
            if (_framesWaited > 30) {
                #if sys
                Sys.exit(_failed ? 1 : 0);
                #end
            }
            return;
        }
        if (_stream.isNull()) return;

        // The segment is done once the mixer has drained the whole ring.
        // Underruns after that are the ring reporting the drained state and
        // carry no signal, so they are not checked.
        if (_stream.space() == _capacity) {
            if (!_lowpass.isNull()) {
                _channel.removeDsp(_lowpass);
                _lowpass.release();
                _lowpass = Dsp.NULL;
            }
            _channel.stop();
            _stream.release();
            _stream = PcmStream.NULL;
            _channel = Channel.NULL;

            if (_segment + 1 < SEGMENTS.length) {
                startSegment(_segment + 1);
            } else {
                finish();
            }
        }
    }

    function finish():Void {
        _complete = true;
        _status.text = _failed ? "SYNTH_TEST failed" : "SYNTH_TEST complete";
        log("SYNTH_TEST: COMPLETE");
    }
}
