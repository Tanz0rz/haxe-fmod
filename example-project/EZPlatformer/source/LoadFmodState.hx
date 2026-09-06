package;

import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxState;
import haxefmod.studio.Types;

/**
 * @author Tanner Moore
 * For games that are deployed to html5, the FMOD audio engine must be loaded before starting the game.
 */
class LoadFmodState extends FlxState {
    override public function create():Void {
        #if audio_test_manual_update
        // The manual-update CI variant: every probe state then runs on
        // FmodManager.Update's manual sys_update pushes instead of the
        // native auto-update thread
        // This variant also runs FMOD from a fixed memory pool
        FmodManager.Initialize({autoUpdate: false, profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC, memoryPoolSize: 96 * 1024 * 1024,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE, affinity: FmodThreadAffinity.CORE_ALL}]});
        #elseif audio_test
        // The test builds turn on profiling and the distance filter so the
        // api-probe can see both work, and pin the buffer settings so the
        // init path with every argument set runs on every CI target
        // The advanced settings are nondefault so the api-probe can read
        // them back through getAdvancedSettings
        // Memory tracking, the resampler, and one thread attribute entry
        // (FMOD's own defaults for the studio update thread) run on every
        // target so the api-probe can see them land
        FmodManager.Initialize({profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE}]});
        #else
        FmodManager.Initialize();
        #end

        var loadingText = new FlxText(0, 0, "Loading...");
        loadingText.setFormat(null, 20, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        loadingText.x = (FlxG.width/2) - loadingText.width/2;
        loadingText.y = (FlxG.height/2) - loadingText.height/2;
        add(loadingText);
    }
    override public function update(elapsed:Float):Void {
        if(FmodManager.IsInitialized()){
            #if audio_test
            // A test build with no state requested is the plain game, so CI
            // builds one variant for every leg
            switch (TestConfig.requestedState()) {
                case null:
                    FlxG.switchState(PlayState.new);
                case "api-probe":
                    FlxG.switchState(ApiProbeState.new);
                case "cb-test":
                    FlxG.switchState(BeatTestState.new);
                case "ps-test":
                    FlxG.switchState(ProgrammerSoundTestState.new);
                case "bank-test":
                    FlxG.switchState(BankLifecycleTestState.new);
                case "pan-test":
                    FlxG.switchState(EmitterPanTestState.new);
                case "stress-test":
                    FlxG.switchState(StressTestState.new);
                case "synth-test":
                    FlxG.switchState(SynthTestState.new);
                default:
                    FlxG.switchState(VolumeTestState.new);
            }
            #else
            FlxG.switchState(PlayState.new);
            #end
        }
    }
}
