package;

import haxefmod.FmodManager;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.UserData;

/**
 * Haxe-side userdata on handles and the description-level callback,
 * against the real backend. Runs synchronously inside ApiProbeState.create.
 */
class ProbeUserData {
    public static function run(state:ApiProbeState):Void {
        // Earlier sections leave Destroyed records queued. Drain them so
        // the baseline and the userdata table only move with this section.
        StudioSystem.flushCommands();
        CallbackDispatcher.update();
        var baseline = StudioSystem.liveHandleCount();
        var entriesBefore = UserData.count();

        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var systemBefore = StudioSystem.getUserData();
        StudioSystem.setUserData("system-tag");
        desc.setUserData({name: "main-level"});
        @:privateAccess state.check("userdata_system_roundtrip",
            StudioSystem.getUserData() == "system-tag", "");
        @:privateAccess state.check("userdata_description_roundtrip",
            desc.getUserData() != null && desc.getUserData().name == "main-level", "");

        // Lookups dedupe to the same handle, so the value is visible through
        // a second lookup of the same event
        var again = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        @:privateAccess state.check("userdata_visible_through_relookup",
            again.getUserData() == desc.getUserData(), 'a=${(desc : Int)} b=${(again : Int)}');

        // An instance keeps its value across updates and loses it on release
        var inst = desc.createInstance();
        var payload = {hits: 0};
        inst.setUserData(payload);
        inst.start();
        for (i in 0...5) {
            FmodManager.Update();
            StudioSystem.flushCommands();
            CallbackDispatcher.update();
        }
        @:privateAccess state.check("userdata_instance_survives_updates",
            inst.getUserData() == payload, "");
        inst.stop(FmodStopMode.IMMEDIATE);
        inst.release();
        @:privateAccess state.check("userdata_gone_after_release", inst.getUserData() == null, "");
        StudioSystem.flushCommands();
        CallbackDispatcher.update();

        // An instance FMOD destroys on its own (releaseAllInstances) is
        // cleared by the Destroyed drain, without release() on the handle
        var jump = StudioSystem.getEvent(FmodEvents.SFXJump);
        var doomed = jump.createInstance();
        doomed.setUserData("doomed");
        jump.releaseAllInstances();
        StudioSystem.flushCommands();
        CallbackDispatcher.update();
        @:privateAccess state.check("userdata_gone_after_destroyed",
            doomed.getUserData() == null, 'handle=${(doomed : Int)}');

        // Description callback: an instance created before the call is
        // not registered, one created after fires Started and can read
        // its own userdata from inside the handler
        var old = desc.createInstance();
        var startedNew = 0;
        var startedOld = 0;
        var seenFromHandler:Dynamic = null;
        var fresh:EventInstance = EventInstance.NULL;
        desc.setCallback(function(data) {
            if (data != Started) return;
            startedNew++;
            seenFromHandler = fresh.getUserData();
        }, EventCallbackType.STARTED);
        fresh = desc.createInstance();
        fresh.setUserData("fresh");
        @:privateAccess state.check("userdata_desc_callback_registers_new",
            CallbackDispatcher.hasHandler(fresh), "");
        @:privateAccess state.check("userdata_desc_callback_skips_old",
            !CallbackDispatcher.hasHandler(old), "");
        old.setCallback(function(data) { if (data == Started) startedOld++; });
        old.start();
        fresh.start();
        var frames = 0;
        while (startedNew == 0 && frames < 120) {
            frames++;
            FmodManager.Update();
            StudioSystem.flushCommands();
            CallbackDispatcher.update();
        }
        @:privateAccess state.check("userdata_desc_callback_started_fires",
            startedNew == 1, 'started=$startedNew frames=$frames');
        @:privateAccess state.check("userdata_desc_callback_old_uses_own_handler",
            startedOld == 1, 'started=$startedOld');
        @:privateAccess state.check("userdata_readable_inside_callback",
            seenFromHandler == "fresh", 'seen=$seenFromHandler');

        // After clearCallback new instances are plain again
        desc.clearCallback();
        var plain = desc.createInstance();
        @:privateAccess state.check("userdata_desc_clear_callback",
            !desc.hasCallback() && !CallbackDispatcher.hasHandler(plain), "");

        for (i in [old, fresh, plain]) {
            i.stop(FmodStopMode.IMMEDIATE);
            i.release();
        }
        StudioSystem.flushCommands();
        CallbackDispatcher.update();
        desc.setUserData(null);
        StudioSystem.setUserData(systemBefore);
        @:privateAccess state.check("userdata_no_entries_left",
            UserData.count() == entriesBefore, 'before=$entriesBefore now=${UserData.count()}');
        @:privateAccess state.check("no_handle_leaks_userdata",
            StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
