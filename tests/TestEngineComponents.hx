package tests;

import haxefmod.heaps.FmodHeapsListener;
import haxefmod.heaps.FmodHeapsUpdater;
import haxefmod.kha.FmodKhaListener;
import haxefmod.kha.FmodKhaUpdater;
import haxefmod.studio.native.NativeStudioStub;

/**
 * The Heaps and Kha listeners on the stub backend, against the h2d
 * stand-ins in tests/stubs. A jump past the teleport distance in one
 * frame is a cut and pushes zero velocity. The automatic distance is
 * one view width for a Heaps scene and 500 units for a body.
 */
class TestEngineComponents {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Engine components (stub backend) ---");
		// Velocities here stay under the maxAttachedVelocity an earlier
		// suite set
		FmodHeapsUpdater.removeHook();
		FmodKhaUpdater.removeHook();
		NativeStudioStub.testRecordListenerPushes = true;
		testHeapsSceneListener();
		testHeapsObjectListener();
		testKhaListener();
		NativeStudioStub.testRecordListenerPushes = false;
		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static inline function approx(a:Float, b:Float):Bool {
		return Math.abs(a - b) < 0.0001;
	}

	static function last() {
		var pushes = NativeStudioStub.testListenerPushes;
		return pushes[pushes.length - 1];
	}

	static function testHeapsSceneListener():Void {
		var scene = new h2d.Scene();
		var camera = scene.camera;
		camera.x = 100;
		camera.y = 50;
		camera.viewportWidth = 640;
		camera.viewportHeight = 480;
		camera.scaleX = 2;
		camera.scaleY = 2;
		var listener = new FmodHeapsListener();
		listener.setScene(scene);
		listener.tick(4);
		assert(approx(last().x, 260) && approx(last().y, 170), 'heaps: the scene listener sits at the view center (${last().x}, ${last().y})');
		// One view width in world units is the viewport over the zoom
		camera.x += 320;
		listener.tick(4);
		assert(approx(last().vx, 80), 'heaps: a camera move of one view width is movement (vx=${last().vx})');
		camera.x += 321;
		listener.tick(4);
		assert(last().vx == 0, 'heaps: a camera move past one view width is a cut (vx=${last().vx})');
		// A quarter turn maps the viewport offset (320, 240) to (240, -320)
		camera.rotation = Math.PI / 2;
		listener.resetMotion();
		listener.tick(4);
		assert(approx(last().x, camera.x + 120) && approx(last().y, camera.y - 160),
			'heaps: a rotated camera keeps the listener at the view center (${last().x - camera.x}, ${last().y - camera.y})');
		camera.rotation = 0;
		camera.anchorX = 0.5;
		camera.anchorY = 0.5;
		listener.resetMotion();
		listener.tick(4);
		assert(approx(last().x, camera.x) && approx(last().y, camera.y), 'heaps: a centered anchor puts the view center on the camera');
		listener.teleportDistance = 1000;
		camera.x += 600;
		listener.tick(4);
		assert(approx(last().vx, 150), 'heaps: a set teleportDistance replaces the view width (vx=${last().vx})');
		camera.x += 10;
		listener.resetMotion();
		listener.tick(4);
		assert(last().vx == 0, 'heaps: resetMotion makes the next frame a cut (vx=${last().vx})');
		// A target after a scene leaves scene mode. The object distance then applies.
		listener.teleportDistance = 0;
		var target = new h2d.Object();
		listener.setTarget(target);
		listener.tick(4);
		target.x += 400;
		listener.tick(4);
		assert(approx(last().vx, 100), 'heaps: setTarget after setScene uses the object distance (vx=${last().vx})');
		listener.dispose();
	}

	static function testHeapsObjectListener():Void {
		var target = new h2d.Object();
		target.width = 10;
		target.height = 20;
		var listener = new FmodHeapsListener(target);
		listener.tick(4);
		assert(approx(last().x, 5) && approx(last().y, 10), "heaps: the object listener sits at the bounds center");
		target.x += 500;
		listener.tick(4);
		assert(approx(last().vx, 125), 'heaps: an object move of 500 units is movement (vx=${last().vx})');
		target.x += 501;
		listener.tick(4);
		assert(last().vx == 0, 'heaps: an object move past 500 units is a cut (vx=${last().vx})');
		listener.teleportDistance = 1000;
		target.x += 600;
		listener.tick(4);
		assert(approx(last().vx, 150), 'heaps: a set teleportDistance replaces the automatic one (vx=${last().vx})');
		listener.dispose();
	}

	static function testKhaListener():Void {
		var body = {x: 0.0, y: 0.0, width: 10.0, height: 20.0};
		var listener = new FmodKhaListener(body);
		listener.tick(4);
		assert(approx(last().x, 5) && approx(last().y, 10), "kha: the listener sits at the body midpoint");
		body.x += 500;
		listener.tick(4);
		assert(approx(last().vx, 125), 'kha: a move of 500 units is movement (vx=${last().vx})');
		body.x += 501;
		listener.tick(4);
		assert(last().vx == 0, 'kha: a move past 500 units is a cut (vx=${last().vx})');
		listener.teleportDistance = 1000;
		body.x += 600;
		listener.tick(4);
		assert(approx(last().vx, 150), 'kha: a set teleportDistance replaces the automatic one (vx=${last().vx})');
		var bare = {x: 7.0, y: 9.0};
		listener.setTarget(bare);
		listener.tick(4);
		assert(approx(last().x, 7) && approx(last().y, 9), "kha: a body without a size is followed at its position");
		listener.dispose();
	}
}
