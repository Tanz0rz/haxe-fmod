package kha;

/**
 * The slice of kha.Scheduler that FmodKhaUpdater uses, driven by hand.
 * runFrame() advances both clocks and runs every frame task. A task
 * added during a frame runs in that frame, and a removed one is skipped,
 * the way Kha does it.
 */
class Scheduler {
	static var tasks:Array<{id:Int, task:Void->Void, active:Bool}> = [];
	static var nextId:Int = 0;
	static var frameTime:Float = 0;
	static var clock:Float = 0;

	public static function addFrameTask(task:Void->Void, priority:Int):Int {
		var id = nextId++;
		tasks.push({id: id, task: task, active: true});
		return id;
	}

	public static function removeFrameTask(id:Int):Void {
		for (entry in tasks) {
			if (entry.id == id) entry.active = false;
		}
	}

	public static function time():Float return frameTime;

	public static function realTime():Float return clock;

	public static function runFrame():Void {
		frameTime += 1 / 60;
		clock += 1 / 60;
		for (entry in tasks) {
			if (entry.active) entry.task();
		}
		tasks = tasks.filter(entry -> entry.active);
	}

	public static function taskCount():Int {
		return tasks.filter(entry -> entry.active).length;
	}
}
