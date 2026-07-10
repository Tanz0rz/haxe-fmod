package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.flixel.FmodFlxEmitter;
import haxefmod.flixel.FmodFlxListener;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI test state for the flixel attachment components. Logs one "PAN_TEST:"
 * line per check; CI gates on "PAN_TEST: COMPLETE" with no "pass=false".
 *
 * The example bank has no 3D events, so audible stereo panning cannot be
 * validated yet; this state validates the attachment machinery end to end
 * instead: FmodFlxEmitter follows a sprite's midpoint (2D events accept 3D
 * attributes, they just do not pan), detach/release on destroy, and
 * FmodFlxListener driving the listener position.
 *
 * Select via HAXEFMOD_TEST_STATE=pan-test (native) or ?test=pan-test (HTML5).
 */
class EmitterPanTestState extends FlxState {
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
        log('PAN_TEST: $name pass=$pass $detail');
    }

    static inline function approx(a:Float, b:Float):Bool {
        return Math.abs(a - b) < 0.01;
    }

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();

        var label = new FlxText(0, 0, FlxG.width, "PAN_TEST running");
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);

        log("PAN_TEST: Starting");

        // Warm the event description cache (the lookup allocates one
        // persistent deduped handle), then capture the leak baseline: the
        // emitter's instance is the only allocation after this point and
        // destroy() must release it.
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var baseline = StudioSystem.liveHandleCount();

        // Emitter attached to a sprite: play + attach in one call
        var sprite = new FlxSprite(100, 50);
        sprite.width = 16;
        sprite.height = 16;
        var emitter = FmodFlxEmitter.play(FmodEvents.MusicMainLevel, sprite);
        add(emitter);

        check("emitter_instance_created", !emitter.instance.isNull(), "");
        var state = emitter.instance.getPlaybackState();
        check("emitter_instance_playing",
            state == FmodPlaybackState.PLAYING || state == FmodPlaybackState.STARTING,
            'state=$state');

        // Move the sprite; FmodManager.Update drives the attach loop
        sprite.x = 300;
        sprite.y = 220;
        sprite.velocity.x = 40;
        sprite.velocity.y = -20;
        FmodManager.Update();

        var attributes = emitter.instance.get3DAttributes();
        check("emitter_attributes_readable", attributes != null, "");
        if (attributes != null) {
            var midX = sprite.x + sprite.width / 2;
            var midY = sprite.y + sprite.height / 2;
            check("emitter_position_follows_midpoint",
                approx(attributes.position.x, midX) && approx(attributes.position.y, midY),
                'position=(${attributes.position.x}, ${attributes.position.y}) expected=($midX, $midY)');
            check("emitter_velocity_follows_target",
                approx(attributes.velocity.x, 40) && approx(attributes.velocity.y, -20),
                'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');
        }

        check("attached_count_one", FmodRuntime.attachedCount() == 1,
            'count=${FmodRuntime.attachedCount()}');

        // Destroying the emitter detaches and releases the instance
        var handle:EventInstance = emitter.instance;
        emitter.destroy();
        check("attached_count_zero_after_destroy", FmodRuntime.attachedCount() == 0,
            'count=${FmodRuntime.attachedCount()}');
        check("instance_invalid_after_destroy", !handle.isValid(), "");

        // Listener follows the sprite's midpoint
        var listener = new FmodFlxListener(sprite);
        add(listener);
        listener.update(0); // create() runs before the state update loop
        FmodManager.Update();

        var listenerAttributes = StudioSystem.getListenerAttributes(0);
        check("listener_attributes_readable", listenerAttributes != null, "");
        if (listenerAttributes != null) {
            var midX = sprite.x + sprite.width / 2;
            var midY = sprite.y + sprite.height / 2;
            check("listener_position_follows_midpoint",
                approx(listenerAttributes.position.x, midX) && approx(listenerAttributes.position.y, midY),
                'position=(${listenerAttributes.position.x}, ${listenerAttributes.position.y}) expected=($midX, $midY)');
        }

        check("no_handle_leaks", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');

        log('PAN_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        label.text = 'PAN_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
