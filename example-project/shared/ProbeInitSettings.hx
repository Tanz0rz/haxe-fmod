package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Probe for the init settings and system info: what the LoadFmodState
 * settings did to the running system (output, resampler, memory
 * tracking, thread attributes), driver info, the console port calls,
 * and the limits. Nothing here changes state that outlives the probe.
 */
class ProbeInitSettings {
    public static function run(state:ApiProbeScenario):Void {
        var baseline = StudioSystem.liveHandleCount();
        var settings = FmodRuntime.settings();

        // The settings LoadFmodState passed are visible in the resolved copy
        @:privateAccess state.check("init_settings_resolved", settings != null && settings.memoryTracking
            && settings.resamplerMethod == FmodDspResampler.CUBIC && settings.threadAttributes.length == 1,
            settings == null ? "null" : 'tracking=${settings.memoryTracking} resampler=${(settings.resamplerMethod : Int)}');

        // Output: the FMOD_WAVWRITER env var wins over the setting on the
        // recording jobs, everything else runs the platform default
        var output = CoreSystem.getOutput();
        #if sys
        var wavWriter = Sys.getEnv("FMOD_WAVWRITER");
        var expectWav = wavWriter != null && wavWriter != "";
        @:privateAccess state.check("init_output_type", expectWav
            ? output == FmodOutputType.WAVWRITER
            : (output != FmodOutputType.WAVWRITER && (output : Int) > 0), 'output=${(output : Int)} wavwriter=$expectWav');
        #else
        @:privateAccess state.check("init_output_type", output == FmodOutputType.WEBAUDIO || output == FmodOutputType.AUDIOWORKLET,
            'output=${(output : Int)}');
        #end

        // Memory tracking on: the getter succeeds on native targets, and
        // the web build has no getter at all. The numbers themselves are
        // only nonzero with the logging FMOD libraries (libfmodstudioL),
        // the release libraries CI ships report zero by design
        #if !js
        var memory = StudioSystem.getMemoryUsage();
        @:privateAccess state.check("init_memory_tracking_reports", memory != null,
            memory == null ? 'result=${StudioSystem.lastResult().toString()}' : 'inclusive=${memory.inclusive} exclusive=${memory.exclusive}');
        var master = StudioSystem.getBus("bus:/");
        var busMemory = master.getMemoryUsage();
        @:privateAccess state.check("init_memory_tracking_bus", busMemory != null && busMemory.inclusive >= 0,
            busMemory == null ? 'result=${StudioSystem.lastResult().toString()}' : 'inclusive=${busMemory.inclusive}');
        var advanced = StudioSystem.getAdvancedSettings();
        @:privateAccess state.check("init_resampler_applied", advanced != null && advanced.resamplerMethod == FmodDspResampler.CUBIC,
            advanced == null ? "null" : 'resampler=${(advanced.resamplerMethod : Int)}');
        #end
        var stats = StudioSystem.getMemoryStats();
        @:privateAccess state.check("init_memory_stats_blocking_default", stats != null && stats.current > 0 && stats.maximum >= stats.current,
            stats == null ? "null" : 'current=${stats.current} maximum=${stats.maximum}');
        if (stats != null) @:privateAccess state.info("init_memory_stats_maximum", Std.string(stats.maximum));

        // Driver info next to the plain name
        var count = CoreSystem.getDriverCount();
        var driver = CoreSystem.getDriverInfo(0);
        @:privateAccess state.check("sys_get_driver_info", count >= 1 && driver != null && driver.name == CoreSystem.getDriverName(0)
            && driver.systemRate > 0 && driver.speakerModeChannels > 0 && (driver.guid : String).length == 38,
            driver == null ? 'result=${StudioSystem.lastResult().toString()}'
            : 'name=${driver.name} guid=${driver.guid} rate=${driver.systemRate} mode=${(driver.speakerMode : Int)} channels=${driver.speakerModeChannels}');
        @:privateAccess state.check("sys_get_driver_info_out_of_range", CoreSystem.getDriverInfo(9999) == null, "");

        // Console ports: desktop and web outputs have none, FMOD says so
        // in the result, and a released group is refused as invalid
        #if !js
        var group = ChannelGroup.create("ports");
        var attach:FmodResult = CoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, group, true);
        @:privateAccess state.check("sys_attach_channel_group_to_port", attach != FmodResult.FMOD_OK && attach != FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${attach.toString()}');
        var detach:FmodResult = CoreSystem.detachChannelGroupFromPort(group);
        @:privateAccess state.check("sys_detach_channel_group_from_port", detach != FmodResult.FMOD_OK && detach != FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${detach.toString()}');
        group.release();
        @:privateAccess state.check("sys_attach_channel_group_to_port_stale",
            CoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, group) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("sys_detach_channel_group_from_port_stale",
            CoreSystem.detachChannelGroupFromPort(group) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        #end

        // The limits match what FMOD enforces
        @:privateAccess state.check("limits_max_listeners", StudioSystem.setNumListeners(FmodLimits.MAX_LISTENERS + 1) != FmodResult.FMOD_OK
            && StudioSystem.setNumListeners(FmodLimits.MAX_LISTENERS).isOk(), "");
        StudioSystem.setNumListeners(1);
        @:privateAccess state.check("limits_max_channel_width", FmodLimits.MAX_CHANNEL_WIDTH == 32 && FmodLimits.REVERB_MAXINSTANCES == 4, "");

        @:privateAccess state.check("no_handle_leaks_init_settings", StudioSystem.liveHandleCount() == baseline,
            'before=$baseline after=${StudioSystem.liveHandleCount()}');
    }
}
