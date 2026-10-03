package;

import h2d.Scene;
import haxefmod.heaps.FmodHeapsSetup;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.Types;
import hxd.Event;

/**
 * Heaps port of the EZPlatformer example. It carries the same two levels
 * and the same banks and events. Under -D audio_test it runs the same
 * shared scenarios as the flixel game. Selection takes the same route -
 * HAXEFMOD_TEST_STATE on HashLink, ?test= in the browser.
 */
class Main extends hxd.App {
    public static var instance:Main;

    var scene:GameScene;

    static function main() {
        new Main();
    }

    override function init() {
        instance = this;
        #if sys
        mirrorTraceToFile();
        #end
        // The flixel game runs 320x240 doubled into a 640x480 window at
        // 60 fps. The cap matters off-screen too. Without vsync a virtual
        // display spins thousands of frames per second. The scenarios'
        // frame-counted waits then expire before FMOD can deliver
        // anything.
        s2d.scaleMode = LetterBox(320, 240);
        // No fpsLimit in the browser. Heaps then runs its loop through
        // setTimeout. Chromium throttles setTimeout to one call per second
        // when it decides the window is in the background. The display
        // rate caps requestAnimationFrame anyway
        engine.backgroundColor = 0xffaaaaaa;


        hxd.Window.getInstance().addEventTarget(onWindowEvent);
        // FMOD initializes and the default banks load through Heaps'
        // own binary loader. The first scene starts once both are ready,
        // on HTML5 too, so no loading scene is needed.
        FmodHeapsSetup.preload(fmodSettings(), startGame, onFmodFailed);
    }

    static function fmodSettings():FmodSettings {
        #if audio_test_manual_update
        // The manual-update CI variant: every scenario then runs on
        // FmodManager.Update's manual sys_update pushes instead of the
        // native auto-update thread. This variant also runs FMOD from a
        // fixed memory pool.
        return ({autoUpdate: false, profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC, memoryPoolSize: 96 * 1024 * 1024,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE, affinity: FmodThreadAffinity.CORE_ALL}]});
        #elseif audio_test
        // The test builds turn on profiling and the distance filter so the
        // api-probe can see both work. They also pin the buffer settings.
        // The advanced settings take nondefault values that the api-probe
        // reads back
        return ({profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE}]});
        #else
        // The plain game keeps audio running while unfocused, so the
        // HighPass filter PlayScene applies on focus loss is audible
        return ({muteWhenUnfocused: false});
        #end
    }

    function startGame():Void {
        #if audio_test
        // With no state requested a test build is the plain game, one
        // build variant per CI leg
        var state = TestConfig.requestedState();
        if (state != null) {
            switchScene(new TestScene(state));
            return;
        }
        #end
        switchScene(new PlayScene());
    }

    function onFmodFailed():Void {
        // The runtime traced which bank failed. The game starts without it.
        trace("FMOD did not initialize, starting without audio");
        startGame();
    }

    override function update(dt:Float) {
        #if js
        // Frame counter the test page's heartbeat reports
        untyped window.__frames = (untyped window.__frames || 0) + 1;
        #end
        if (scene != null) scene.update(dt);
        #if hl
        // HashLink has no frame cap of its own and a virtual display has
        // no vsync, so pace the loop by hand
        var wait = FRAME_SECONDS - (haxe.Timer.stamp() - lastFrameStamp);
        if (wait > 0) Sys.sleep(wait);
        lastFrameStamp = haxe.Timer.stamp();
        #end
    }

    static inline var FRAME_SECONDS:Float = 1 / 60;
    var lastFrameStamp:Float = 0;

    #if sys
    /**
     * CI on Windows builds GUI executables whose stdout goes nowhere, so
     * every trace also lands in the file HAXEFMOD_LOG_FILE names.
     */
    static function mirrorTraceToFile():Void {
        var path = Sys.getEnv("HAXEFMOD_LOG_FILE");
        if (path == null || path == "") return;
        var original = haxe.Log.trace;
        haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos) {
            original(v, pos);
            try {
                var out = sys.io.File.append(path, false);
                out.writeString(haxe.Log.formatOutput(v, pos) + "\n");
                out.close();
            } catch (e:Dynamic) {}
        };
    }
    #end

    public function switchScene(next:GameScene):Void {
        if (scene != null) scene.dispose();
        scene = next;
        scene.create(s2d);
    }

    // The game's own reaction to focus. The FMOD master mute on focus
    // loss is wired separately by FmodHeapsSetup.
    function onWindowEvent(event:Event):Void {
        switch (event.kind) {
            case EFocus: if (Std.isOfType(scene, PlayScene) || Std.isOfType(scene, PlayScene2)) FmodManager.SetSongParameter("HighPass", 0);
            case EFocusLost: if (Std.isOfType(scene, PlayScene) || Std.isOfType(scene, PlayScene2)) FmodManager.SetSongParameter("HighPass", 1);
            default:
        }
    }
}
