package;

import kha.Framebuffer;
import haxefmod.kha.FmodKhaSetup;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.Types;
import kha.Scheduler;
import kha.System;

/**
 * Kha port of the EZPlatformer example. The port keeps the same two
 * levels and the same banks and events. Under -D audio_test it runs the
 * same shared scenarios as the flixel and Heaps games. Scenario selection
 * works the same way: HAXEFMOD_TEST_STATE natively, ?test= in the
 * browser.
 */
class Main {
    public static var instance:Main;

    var scene:GameScene;
    var lastStamp:Float = -1;

    static inline var FRAME_SECONDS:Float = 1 / 60;

    static function main() {
        System.start({title: "KhaPlatformer", width: 640, height: 480}, function(_) {
            // Graphics2 draws with shaders that arrive as assets, so
            // nothing renders before this completes
            kha.Assets.loadEverything(function() {
                new Main();
            });
        });
    }

    function new() {
        instance = this;
        #if sys
        mirrorTraceToFile();
        #end


        // The game's own reaction to focus. The FMOD master mute on
        // focus loss is wired separately by FmodKhaSetup.
        System.notifyOnApplicationState(onForeground, onForeground, onBackground, onBackground, null);

        // Kha runs frame tasks in ascending priority order. The game moves
        // things at 0, and FmodKhaUpdater samples them at its higher number.
        Scheduler.addFrameTask(update, 0);
        System.notifyOnFrames(render);
        // The default banks are Kha assets, loaded by loadEverything before
        // this constructor ran. FMOD initializes from them and the first
        // scene starts once it is ready, on HTML5 too.
        FmodKhaSetup.preload(fmodSettings(), startGame, onFmodFailed);
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
        // The test builds enable profiling and the distance filter so the
        // api-probe can confirm both work. The build pins the buffer
        // settings. It sets the advanced settings to nondefault values
        // that the api-probe reads back
        return ({profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE}]});
        #else
        // The plain game keeps audio running while unfocused, so the
        // HighPass filter the play states apply on focus loss is audible
        return ({muteWhenUnfocused: false});
        #end
    }

    function startGame():Void {
        #if audio_test
        // A test build with no state requested is the plain game, so CI
        // builds one variant for every leg
        var state = TestConfig.requestedState();
        if (state != null) {
            switchScene(new TestScene(state));
            return;
        }
        #end
        switchScene(new PlayScene());
    }

    function onFmodFailed():Void {
        // The console named the bank. The game runs without audio.
        trace("FMOD did not initialize, starting without audio");
        startGame();
    }

    function update():Void {
        var now = Scheduler.realTime();
        var dt = lastStamp < 0 ? 0.0 : now - lastStamp;
        lastStamp = now;
        if (scene != null) scene.update(dt);
        #if sys
        // A virtual display has no vsync, so pace the loop by hand. The
        // scenarios count frames and expect roughly 60 per second.
        var wait = FRAME_SECONDS - (Scheduler.realTime() - now);
        if (wait > 0) Sys.sleep(wait);
        // HL/C buffers a redirected stdout until exit, and CI reads the
        // log of a run it kills after 30 seconds
        Sys.stdout().flush();
        #end
    }

    function render(frames:Array<Framebuffer>):Void {
        var g2 = frames[0].g2;
        g2.begin(true, 0xffaaaaaa);
        // The flixel game runs 320x240 doubled into a 640x480 window
        g2.pushTransformation(kha.math.FastMatrix3.scale(2, 2));
        if (scene != null) scene.render(g2);
        g2.popTransformation();
        g2.end();
    }

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
        scene.create();
    }

    function onForeground():Void {
        if (Std.isOfType(scene, PlayScene) || Std.isOfType(scene, PlayScene2)) FmodManager.SetSongParameter("HighPass", 0);
    }

    function onBackground():Void {
        if (Std.isOfType(scene, PlayScene) || Std.isOfType(scene, PlayScene2)) FmodManager.SetSongParameter("HighPass", 1);
    }
}
