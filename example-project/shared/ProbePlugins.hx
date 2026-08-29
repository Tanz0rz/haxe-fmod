package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Plugin loading. The Linux CI jobs compile tests/native/test_plugin_gain.c
 * next to the game binary, so the full load, create, unload path runs when
 * that file is present and only the failure paths and the built-in plugin
 * listing run otherwise. HTML5 has no plugin host and every call reports
 * FMOD_ERR_UNSUPPORTED there.
 */
class ProbePlugins {
    static inline var PLUGIN_FILE = "libtest_plugin_gain.so";
    static inline var PLUGIN_NAME = "haxefmod test gain";

    public static function run(state:ApiProbeScenario):Void {
        // The master group is cached, fetching it before the baseline keeps
        // the leak check honest whichever probe ran first
        var master = ChannelGroup.master();
        var baseline = StudioSystem.liveHandleCount();

        #if js
        @:privateAccess state.check("sys_set_plugin_path_unsupported",
            StudioSystem.setPluginPath("plugins") == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_load_plugin_unsupported", StudioSystem.loadPlugin(PLUGIN_FILE) == 0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_unload_plugin_unsupported",
            StudioSystem.unloadPlugin(1) == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_get_num_plugins_unsupported",
            StudioSystem.getPluginCount(FmodPluginType.DSP) == -1
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_get_plugin_handle_unsupported",
            StudioSystem.getPluginHandle(FmodPluginType.DSP, 0) == 0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_get_plugin_info_unsupported", StudioSystem.getPluginInfo(1) == null, "");
        @:privateAccess state.check("sys_get_num_nested_plugins_unsupported",
            StudioSystem.getNestedPluginCount(1) == -1
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_get_nested_plugin_unsupported", StudioSystem.getNestedPlugin(1, 0) == 0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("dsp_create_by_plugin_unsupported", Dsp.createByPlugin(1).isNull()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("dsp_get_info_by_plugin_unsupported", Dsp.getPluginInfo(1) == null, "");
        #else
        var missing = StudioSystem.loadPlugin("does-not-exist-plugin.so");
        @:privateAccess state.check("sys_load_plugin_missing", missing == 0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_FILE_NOTFOUND,
            'handle=$missing lastResult=${StudioSystem.lastResult().toString()}');

        var pathResult = StudioSystem.setPluginPath(Sys.getCwd());
        @:privateAccess state.check("sys_set_plugin_path", pathResult.isOk(), 'result=${pathResult.toString()}');

        // The built-in effects are listed as DSP plugins even with nothing loaded
        var dspCount = StudioSystem.getPluginCount(FmodPluginType.DSP);
        @:privateAccess state.check("sys_get_num_plugins", dspCount > 0, 'value=$dspCount');
        var badType = StudioSystem.getPluginCount(cast 7);
        @:privateAccess state.check("sys_get_num_plugins_bad_type", badType == -1
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM,
            'value=$badType lastResult=${StudioSystem.lastResult().toString()}');
        var builtin = StudioSystem.getPluginHandle(FmodPluginType.DSP, 0);
        @:privateAccess state.check("sys_get_plugin_handle", builtin != 0, 'handle=$builtin');
        @:privateAccess state.check("sys_get_plugin_handle_out_of_range",
            StudioSystem.getPluginHandle(FmodPluginType.DSP, 99999) == 0,
            'lastResult=${StudioSystem.lastResult().toString()}');
        var builtinInfo = StudioSystem.getPluginInfo(builtin);
        @:privateAccess state.check("sys_get_plugin_info_builtin", builtinInfo != null
            && builtinInfo.type == FmodPluginType.DSP && builtinInfo.name != "",
            builtinInfo == null ? 'null lastResult=${StudioSystem.lastResult().toString()}'
                : 'name=${builtinInfo.name} version=${builtinInfo.version}');
        @:privateAccess state.check("sys_get_plugin_info_invalid", StudioSystem.getPluginInfo(0x7fffffff) == null,
            'lastResult=${StudioSystem.lastResult().toString()}');
        // FMOD answers OK for these three on a handle it never issued, so
        // they are recorded rather than gated
        @:privateAccess state.info("sys_get_num_nested_plugins_invalid",
            'value=${StudioSystem.getNestedPluginCount(0x7fffffff)} lastResult=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.info("sys_get_nested_plugin_invalid",
            'handle=${StudioSystem.getNestedPlugin(0x7fffffff, 0)} lastResult=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.info("sys_unload_plugin_invalid",
            'result=${StudioSystem.unloadPlugin(0x7fffffff).toString()}');
        @:privateAccess state.check("dsp_get_info_by_plugin_invalid", Dsp.getPluginInfo(0x7fffffff) == null,
            'lastResult=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("dsp_create_by_plugin_invalid", Dsp.createByPlugin(0x7fffffff).isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');

        if (sys.FileSystem.exists(PLUGIN_FILE)) {
            var handle = StudioSystem.loadPlugin(sys.FileSystem.absolutePath(PLUGIN_FILE));
            @:privateAccess state.check("sys_load_plugin", handle != 0,
                'handle=$handle lastResult=${StudioSystem.lastResult().toString()}');

            var info = StudioSystem.getPluginInfo(handle);
            @:privateAccess state.check("sys_get_plugin_info", info != null && info.name == PLUGIN_NAME
                && info.type == FmodPluginType.DSP && info.version == 0x00010000,
                info == null ? 'null lastResult=${StudioSystem.lastResult().toString()}'
                    : 'name=${info.name} type=${(info.type : Int)} version=${info.version}');

            var nested = StudioSystem.getNestedPluginCount(handle);
            @:privateAccess state.check("sys_get_num_nested_plugins", nested == 1, 'value=$nested');
            var nestedHandle = StudioSystem.getNestedPlugin(handle, 0);
            @:privateAccess state.check("sys_get_nested_plugin", nestedHandle != 0,
                'handle=$nestedHandle parent=$handle');
            @:privateAccess state.check("sys_get_nested_plugin_out_of_range",
                StudioSystem.getNestedPlugin(handle, 5) == 0, 'lastResult=${StudioSystem.lastResult().toString()}');

            var dspInfo = Dsp.getPluginInfo(handle);
            @:privateAccess state.check("dsp_get_info_by_plugin", dspInfo != null && dspInfo.name == PLUGIN_NAME
                && dspInfo.inputBuffers == 1 && dspInfo.outputBuffers == 1 && dspInfo.parameterCount == 1
                && dspInfo.version == 0x00010000,
                dspInfo == null ? 'null lastResult=${StudioSystem.lastResult().toString()}'
                    : 'name=${dspInfo.name} in=${dspInfo.inputBuffers} out=${dspInfo.outputBuffers} params=${dspInfo.parameterCount}');

            var unit = Dsp.createByPlugin(handle);
            @:privateAccess state.check("dsp_create_by_plugin", !unit.isNull(),
                'handle=${(unit : Int)} lastResult=${StudioSystem.lastResult().toString()}');
            @:privateAccess state.check("plugin_dsp_parameter_roundtrip", unit.setParameter(0, 2.5).isOk()
                && Math.abs(unit.getParameter(0) - 2.5) < 0.001, 'value=${unit.getParameter(0)}');
            @:privateAccess state.check("plugin_dsp_attach", master.addDsp(0, unit).isOk(),
                'lastResult=${StudioSystem.lastResult().toString()}');
            haxefmod.studio.native.NativeStudio.sys_update();
            haxefmod.studio.native.NativeStudio.sys_update();
            @:privateAccess state.check("plugin_dsp_detach", master.removeDsp(unit).isOk(),
                'lastResult=${StudioSystem.lastResult().toString()}');
            @:privateAccess state.check("plugin_dsp_release", unit.release().isOk(),
                'lastResult=${StudioSystem.lastResult().toString()}');

            // FMOD reports DSP_INUSE on unload until its mixer thread has
            // torn the released unit down, which takes a few update ticks
            var unload:FmodResult = FmodResult.FMOD_ERR_DSP_INUSE;
            var tries = 0;
            while (unload == FmodResult.FMOD_ERR_DSP_INUSE && tries < 50) {
                haxefmod.studio.native.NativeStudio.sys_update();
                Sys.sleep(0.02);
                unload = StudioSystem.unloadPlugin(handle);
                tries++;
            }
            @:privateAccess state.check("sys_unload_plugin", unload.isOk(), 'result=${unload.toString()} tries=$tries');
        } else {
            @:privateAccess state.info("plugins", "skipped: no test plugin next to the binary");
        }
        #end

        @:privateAccess state.check("no_handle_leaks_plugins", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
