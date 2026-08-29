package tests;

import haxefmod.core.Dsp;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * The plugin surface against the stub backend: every wrapper routes to its
 * binding, the stub reports UNSUPPORTED or the failure value of the
 * binding's shape, and null paths never reach the shim.
 */
class TestPlugins {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Plugins (stub backend) ---");

		assert((FmodPluginType.OUTPUT : Int) == 0 && (FmodPluginType.CODEC : Int) == 1 && (FmodPluginType.DSP : Int) == 2,
			"FmodPluginType matches FMOD_PLUGINTYPE");

		assert(NativeStudio.sys_set_plugin_path("plugins") == FmodResult.FMOD_ERR_UNSUPPORTED, "sys_set_plugin_path stub unsupported");
		assert(NativeStudio.sys_load_plugin("gain.so", 0) == 0, "sys_load_plugin stub 0");
		assert(NativeStudio.sys_unload_plugin(1) == FmodResult.FMOD_ERR_UNSUPPORTED, "sys_unload_plugin stub unsupported");
		assert(NativeStudio.sys_get_num_plugins(2) == -1, "sys_get_num_plugins stub -1");
		assert(NativeStudio.sys_get_plugin_handle(2, 0) == 0, "sys_get_plugin_handle stub 0");
		assert(NativeStudio.sys_get_plugin_info(1) == "", "sys_get_plugin_info stub empty");
		assert(NativeStudio.sys_get_num_nested_plugins(1) == -1, "sys_get_num_nested_plugins stub -1");
		assert(NativeStudio.sys_get_nested_plugin(1, 0) == 0, "sys_get_nested_plugin stub 0");
		assert(NativeStudio.dsp_create_by_plugin(1) == 0, "dsp_create_by_plugin stub 0");
		assert(NativeStudio.dsp_get_info_by_plugin(1) == "", "dsp_get_info_by_plugin stub empty");

		assert(StudioSystem.setPluginPath("plugins") == FmodResult.FMOD_ERR_UNSUPPORTED, "setPluginPath routes");
		assert(StudioSystem.setPluginPath(null) == FmodResult.FMOD_ERR_UNSUPPORTED, "setPluginPath null path is safe");
		assert(StudioSystem.loadPlugin("gain.so") == 0, "loadPlugin default priority");
		assert(StudioSystem.loadPlugin("gain.so", 5) == 0, "loadPlugin with priority");
		assert(StudioSystem.loadPlugin(null) == 0, "loadPlugin null path is safe");
		assert(StudioSystem.unloadPlugin(1) == FmodResult.FMOD_ERR_UNSUPPORTED, "unloadPlugin routes");
		assert(StudioSystem.getPluginCount(FmodPluginType.DSP) == -1, "getPluginCount default");
		assert(StudioSystem.getPluginHandle(FmodPluginType.DSP, 0) == 0, "getPluginHandle default");
		assert(StudioSystem.getPluginInfo(1) == null, "getPluginInfo null on failure");
		assert(StudioSystem.getNestedPluginCount(1) == -1, "getNestedPluginCount default");
		assert(StudioSystem.getNestedPlugin(1, 0) == 0, "getNestedPlugin default");
		assert(Dsp.createByPlugin(1).isNull(), "Dsp.createByPlugin null");
		assert(Dsp.getPluginInfo(1) == null, "Dsp.getPluginInfo null on failure");

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}
}
