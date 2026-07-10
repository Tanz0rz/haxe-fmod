package tests;

import haxefmod.studio.Bank;
import haxefmod.studio.Bus;
import haxefmod.studio.CoreSound;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.Vca;

/**
 * Sweeps the whole haxefmod.studio abstract surface against the stub
 * backend. Proves the studio package compiles without flixel and that every
 * abstract method behaves safely on invalid handles (defaults returned,
 * no exceptions).
 */
class TestStudioSurface {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Studio surface (stub backend) ---");

		testNullHandles();
		testSystemSurface();
		testStructReturns();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function testNullHandles():Void {
		var bus:Bus = Bus.NULL;
		assert(bus.isNull(), "bus null");
		assert(!bus.isValid(), "bus invalid");
		assert(bus.getPath() == "", "bus path default");
		assert(!bus.setVolume(1.0).isOk(), "bus setVolume result");

		var vca:Vca = Vca.NULL;
		assert(!vca.isValid(), "vca invalid");
		assert(vca.getVolume() == 0.0, "vca volume default");
		assert(!vca.setVolume(1.0).isOk(), "vca setVolume result");

		var bank:Bank = Bank.NULL;
		assert(!bank.isValid(), "bank invalid");
		assert(bank.getLoadingState() == FmodLoadingState.UNLOADED, "bank loading state default");
		assert(bank.getEventList().length == 0, "bank event list empty");
		assert(bank.getBusList().length == 0, "bank bus list empty");
		assert(bank.getVCAList().length == 0, "bank vca list empty");
		assert(!bank.unload().isOk(), "bank unload result");

		var desc:EventDescription = EventDescription.NULL;
		assert(!desc.isValid(), "evd invalid");
		assert(desc.getLength() == 0, "evd length default");
		assert(desc.getMinMaxDistance() == null, "evd minmax null");
		assert(desc.createInstance().isNull(), "evd createInstance null");
		assert(desc.getInstanceList().length == 0, "evd instance list empty");
		assert(desc.getParameterDescriptionByIndex(0) == null, "evd param desc null");
		assert(desc.getParameterLabel("x", 0) == "", "evd param label default");

		var instance:EventInstance = EventInstance.NULL;
		assert(!instance.isValid(), "evi invalid");
		assert(instance.getDescription().isNull(), "evi description null");
		assert(!instance.start().isOk(), "evi start result");
		assert(!instance.stop().isOk(), "evi stop result");
		assert(!instance.keyOff().isOk(), "evi keyOff result");
		assert(!instance.release().isOk(), "evi release result");
		assert(instance.getPlaybackState() == FmodPlaybackState.STOPPED, "evi playback state default");
		assert(instance.getVolume() == 0.0, "evi volume default");
		assert(instance.getTimelinePosition() == 0, "evi timeline default");
		assert(instance.getMinMaxDistance() == null, "evi minmax null");
		assert(instance.get3DAttributes() == null, "evi 3d attrs null");
		assert(!instance.setPosition2D(1, 2).isOk(), "evi setPosition2D result");
		assert(instance.getParameter("x") == 0.0, "evi param default");
		assert(!instance.setParameter("x", 1.0).isOk(), "evi setParameter result");
		assert(!instance.setParameterWithLabel("x", "label").isOk(), "evi setParameterWithLabel result");
		assert(instance.getProperty(CHANNELPRIORITY) == 0.0, "evi property default");
		assert(instance.getReverbLevel(0) == 0.0, "evi reverb default");
		assert(instance.getCpuUsage() == null, "evi cpu null");
		assert(instance.getMemoryUsage() == null, "evi memory null");
	}

	static function testSystemSurface():Void {
		assert(StudioSystem.getEvent("event:/x").isNull(), "sys getEvent null");
		assert(StudioSystem.getEventByID("{0}").isNull(), "sys getEventByID null");
		assert(StudioSystem.getVCA("vca:/x").isNull(), "sys getVCA null");
		assert(StudioSystem.getBank("bank:/x").isNull(), "sys getBank null");
		assert(StudioSystem.getBankCount() == 0, "sys bank count default");
		assert(StudioSystem.getBankList().length == 0, "sys bank list empty");
		assert(StudioSystem.lookupID("event:/x") == "", "sys lookupID default");
		assert(StudioSystem.lookupPath("{0}") == "", "sys lookupPath default");
		assert(StudioSystem.loadBankFile("x.bank").isNull(), "sys loadBankFile null");
		assert(!StudioSystem.unloadAll().isOk(), "sys unloadAll result");
		assert(StudioSystem.getParameter("x") == 0.0, "sys param default");
		assert(!StudioSystem.setParameter("x", 1.0).isOk(), "sys setParameter result");
		assert(!StudioSystem.setParameterByID({data1: 1, data2: 2}, 0.5).isOk(), "sys setParameterByID result");
		assert(StudioSystem.getParameterDescriptionCount() == 0, "sys param count default");
		assert(StudioSystem.getParameterDescriptionByIndex(0) == null, "sys param desc null");
		assert(StudioSystem.getNumListeners() == 0, "sys listeners default");
		assert(!StudioSystem.setListenerPosition2D(0, 1, 2).isOk(), "sys listener pos result");
		assert(StudioSystem.getListenerAttributes(0) == null, "sys listener attrs null");
	}

	static function testStructReturns():Void {
		assert(StudioSystem.getCpuUsage() == null, "sys cpu null");
		assert(StudioSystem.getBufferUsage() == null, "sys buffer null");
		assert(StudioSystem.getMemoryUsage() == null, "sys memory null");

		// setListenerAttributes with a full struct exercises the flattening path
		var attrs:Fmod3DAttributes = {
			position: {x: 1, y: 2, z: 3},
			velocity: {x: 0, y: 0, z: 0},
			forward: {x: 0, y: 0, z: 1},
			up: {x: 0, y: 1, z: 0},
		};
		assert(!StudioSystem.setListenerAttributes(0, attrs).isOk(), "sys setListenerAttributes result");

		var instance:EventInstance = EventInstance.NULL;
		assert(!instance.set3DAttributes(attrs).isOk(), "evi set3DAttributes result");

		// Programmer sounds + core micro subset
		assert(!instance.assignProgrammerSound("key").isOk(), "evi assignProgrammerSound result");
		assert(!instance.clearProgrammerSound().isOk(), "evi clearProgrammerSound result");
		var sound = CoreSound.create("missing.wav");
		assert(sound.isNull(), "core sound null");
		assert(sound.getLength() == -1, "core sound length default");
		assert(!sound.release().isOk(), "core sound release result");
	}
}
