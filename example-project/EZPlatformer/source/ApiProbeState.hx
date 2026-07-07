package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.studio.Bus;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI probe for the haxefmod.studio binding surface.
 *
 * Exercises every Bus binding and logs one "API_PROBE:" line per check so
 * CI can assert coverage from the game log. On HTML5 this is the source of
 * truth for which functions FMOD's Emscripten API actually supports:
 * gating checks log pass=true/false, informational checks log info=... and
 * never fail the probe (e.g. CPU/memory profiling, which can legitimately
 * report FMOD_ERR_UNSUPPORTED).
 *
 * Select via HAXEFMOD_TEST_STATE=api-probe (native) or ?test=api-probe (HTML5).
 */
class ApiProbeState extends FlxState {
    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _done:Bool = false;
    var _framesWaited:Int = 0;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (pass) _passCount++ else _failCount++;
        log('API_PROBE: $name pass=$pass $detail');
    }

    function info(name:String, detail:String):Void {
        log('API_PROBE: $name info=$detail');
    }

    override public function create():Void {
        super.create();

        var label = new FlxText(0, 0, FlxG.width, "API_PROBE running");
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);

        log("API_PROBE: Starting");

        var handlesBefore = StudioSystem.liveHandleCount();
        info("live_handle_count_before", Std.string(handlesBefore));

        // Lookup
        var master = StudioSystem.getBus("bus:/");
        check("sys_get_bus", !master.isNull(), 'handle=${(master : Int)}');
        check("bus_is_valid", master.isValid(), "");

        var missing = StudioSystem.getBus("bus:/DoesNotExist");
        check("sys_get_bus_missing", missing.isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');

        // Path and GUID
        var path = master.getPath();
        check("bus_get_path", path == "bus:/", 'value=$path');

        var guid = master.getID();
        // "{8-4-4-4-12}" formatted GUID is exactly 38 chars
        check("bus_get_id", guid.length == 38 && StringTools.startsWith(guid, "{"), 'value=$guid');

        // Volume round trip
        var setResult:FmodResult = master.setVolume(0.5);
        check("bus_set_volume", setResult.isOk(), 'result=${setResult.toString()}');
        var volume = master.getVolume();
        check("bus_get_volume", Math.abs(volume - 0.5) < 0.001, 'value=$volume');
        info("bus_get_final_volume", Std.string(master.getFinalVolume()));
        master.setVolume(1.0);

        // Pause round trip
        var pauseResult = master.setPaused(true);
        check("bus_set_paused", pauseResult.isOk(), 'result=${pauseResult.toString()}');
        check("bus_get_paused", master.getPaused(), "");
        master.setPaused(false);
        check("bus_get_paused_cleared", !master.getPaused(), "");

        // Mute round trip
        var muteResult = master.setMute(true);
        check("bus_set_mute", muteResult.isOk(), 'result=${muteResult.toString()}');
        check("bus_get_mute", master.getMute(), "");
        master.setMute(false);
        check("bus_get_mute_cleared", !master.getMute(), "");

        // Stop all events (no events playing - just verify the call succeeds)
        var stopResult = master.stopAllEvents(FmodStopMode.IMMEDIATE);
        check("bus_stop_all_events", stopResult.isOk(), 'result=${stopResult.toString()}');

        // Profiling - informational only (needs profiling enabled; may be
        // unsupported on some targets, especially HTML5)
        var cpu = master.getCpuUsage();
        info("bus_get_cpu_usage", cpu == null
            ? 'unavailable result=${StudioSystem.lastResult().toString()}'
            : 'exclusive=${cpu.exclusive} inclusive=${cpu.inclusive}');
        var memory = master.getMemoryUsage();
        info("bus_get_memory_usage", memory == null
            ? 'unavailable result=${StudioSystem.lastResult().toString()}'
            : 'exclusive=${memory.exclusive} inclusive=${memory.inclusive} sampledata=${memory.sampledata}');

        // Cached lookups must not allocate new handles
        var again = StudioSystem.getBus("bus:/");
        check("bus_lookup_cached", (again : Int) == (master : Int), "");
        info("live_handle_count_after", Std.string(StudioSystem.liveHandleCount()));

        log('API_PROBE: COMPLETE passed=$_passCount failed=$_failCount');
        label.text = 'API_PROBE complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (!_done) return;

        // Give the renderer a few frames so the result text is visible, then exit
        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
