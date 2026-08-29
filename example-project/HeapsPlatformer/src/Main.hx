package;

import h2d.Scene;
import haxefmod.studio.Types;
import hxd.Event;

/**
 * Heaps port of the EZPlatformer example: the same two levels, the same
 * banks and events, and under -D audio_test the same shared scenarios
 * the flixel game runs, selected the same way (HAXEFMOD_TEST_STATE on
 * HashLink, ?test= in the browser).
 */
class Main extends hxd.App {
    public static var instance:Main;

    var scene:GameScene;

    static function main() {
        new Main();
    }

    override function init() {
        instance = this;
        // The flixel game runs 320x240 doubled into a 640x480 window at
        // 60 fps. The cap matters off-screen too: without vsync a virtual
        // display spins thousands of frames per second and the scenarios'
        // frame-counted waits expire before FMOD can deliver anything.
        s2d.scaleMode = LetterBox(320, 240);
        // No fpsLimit in the browser: Heaps then runs its loop through
        // setTimeout, which Chromium throttles to one call per second when
        // it decides the window is in the background, and requestAnimationFrame
        // caps at the display rate anyway
        engine.backgroundColor = 0xffaaaaaa;

        #if audio_test_manual_update
        // The manual-update CI variant: every scenario then runs on
        // FmodManager.Update's manual sys_update pushes instead of the
        // native auto-update thread. This variant also runs FMOD from a
        // fixed memory pool.
        FmodManager.Initialize({autoUpdate: false, profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC, memoryPoolSize: 96 * 1024 * 1024,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE, affinity: FmodThreadAffinity.CORE_ALL}]});
        #elseif audio_test
        // The test builds turn on profiling and the distance filter so the
        // api-probe can see both work, pin the buffer settings, and set the
        // advanced settings to nondefault values the api-probe reads back
        FmodManager.Initialize({profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE}]});
        #else
        FmodManager.Initialize();
        #end

        hxd.Window.getInstance().addEventTarget(onWindowEvent);
        switchScene(new LoadScene());
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

    public function switchScene(next:GameScene):Void {
        if (scene != null) scene.dispose();
        scene = next;
        scene.create(s2d);
    }

    // The game's own reaction to focus. The FMOD master mute on focus
    // loss is wired separately by FmodHeapsSetup.
    function onWindowEvent(event:Event):Void {
        switch (event.kind) {
            case EFocus: if (Std.isOfType(scene, PlayScene) || Std.isOfType(scene, PlayScene2)) FmodManager.SetEventParameterOnSong("HighPass", 0);
            case EFocusLost: if (Std.isOfType(scene, PlayScene) || Std.isOfType(scene, PlayScene2)) FmodManager.SetEventParameterOnSong("HighPass", 1);
            default:
        }
    }
}
