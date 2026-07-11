package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.Channel;
import haxefmod.core.PcmStream;

/**
 * CI test state proving Haxe-generated PCM reaches the audio output.
 *
 * Plays three tone segments through PcmStream so the recording can be
 * frequency-gated by ci/audio-profile.py --synth:
 *   Segment 1: 4s of a 440Hz sine
 *   Segment 2: 4s of an 880Hz sine
 *   Segment 3: 660Hz sine data played at pitch 2.0. It must measure as
 *              1320Hz, proving channel pitch control end to end. Hearing
 *              660Hz here means the pitch never reached FMOD.
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

    // {data frequency, channel pitch} per segment
    static var SEGMENTS:Array<{freq:Float, pitch:Float}> = [
        {freq: 440.0, pitch: 1.0},
        {freq: 880.0, pitch: 1.0},
        {freq: 660.0, pitch: 2.0},
    ];

    var _segment:Int = -1;
    var _stream:PcmStream = PcmStream.NULL;
    var _channel:Channel = Channel.NULL;
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

        // The whole segment goes into the ring before playback starts
        var data = haxe.io.Bytes.alloc(samples * 2);
        for (i in 0...samples) {
            var v = Std.int(Math.sin(2 * Math.PI * seg.freq * i / RATE) * AMPLITUDE);
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
