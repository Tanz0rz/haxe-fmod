package;

import haxefmod.flixel.FmodFlxPreloader;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.Types;

/**
 * The lime preloader. FMOD initializes while lime loads the assets, and
 * the default banks come from those assets, so the first state plays at
 * once on every target. The settings differ per CI variant.
 */
class TestPreloader extends FmodFlxPreloader {
    override function settings():Null<FmodSettings> {
        #if audio_test_manual_update
        // The manual-update CI variant. Every probe state then runs on the
        // manual sys_update pushes of FmodManager.Update, with the native
        // auto-update thread off. This variant also runs FMOD from a fixed
        // memory pool.
        return ({autoUpdate: false, profiling: true, distanceFilter: true,
            dspBufferSize: 1024, dspNumBuffers: 4, softwareChannels: 64, streamBufferSize: 65536,
            vol0VirtualVol: 0.01, randomSeed: 12345, commandQueueSize: 65536,
            memoryTracking: true, resamplerMethod: FmodDspResampler.CUBIC, memoryPoolSize: 96 * 1024 * 1024,
            threadAttributes: [{type: FmodThreadType.STUDIO_UPDATE, priority: FmodThreadPriority.STUDIO_UPDATE,
                stackSize: FmodThreadStackSize.STUDIO_UPDATE, affinity: FmodThreadAffinity.CORE_ALL}]});
        #elseif audio_test
        // The test builds turn on profiling and the distance filter so the
        // api-probe can see both work. They pin the buffer settings too, so
        // the init path with every argument set runs on every CI target.
        // The advanced settings are nondefault so the api-probe can read
        // them back through getAdvancedSettings.
        // Memory tracking, the resampler, and one thread attribute entry
        // run on every target so the api-probe can see them land. That
        // entry holds FMOD's own defaults for the studio update thread.
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
}
