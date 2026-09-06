package;

import h2d.Object;
import h2d.Scene;
import h2d.Text;
import hxd.Key;
import Level.Body;

/** Level 1: wait a second, walk right, grab the coin, the arp fades in. */
class PlayScene implements GameScene {
    var root:Object;
    var level:Level;
    var player:Body;
    var coin:Body;
    var status:Text;
    var prompt:Text;
    var started:Bool = false;
    var startDelay:Float = 0;
    var winTimer:Float = -1;
    var fadedOut:Bool = false;

    public function new() {}

    public function create(s2d:Scene):Void {
        // One-call heaps setup: the per-frame updater (drives
        // FmodManager.Update) plus focus-driven muting
        haxefmod.heaps.FmodHeapsSetup.init();
        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        root = new Object(s2d);
        level = new Level(root);

        coin = new Body(root, 16 * 8 + 3, 28 * 8 + 2, 2, 4, 0xffff00);

        player = new Body(root, 5 * 8, 28 * 8, 8, 8, 0xff0000);
        player.maxVelocityX = 80;
        player.maxVelocityY = 200;
        player.accelerationY = 200;

        var font = hxd.res.DefaultFont.get();
        status = new Text(font, root);
        status.x = 2;
        status.y = 2;
        prompt = new Text(font, root);
        prompt.text = "Press enter to start";
        prompt.textAlign = Center;
        prompt.maxWidth = 320;
        prompt.x = 160;
        prompt.y = 120 - 4;
    }

    public function update(dt:Float):Void {
        // FmodManager.Update() runs from FmodHeapsUpdater

        if (!started) {
            startDelay += dt;
            if (startDelay >= 1.0 || Key.isPressed(Key.ENTER)) {
                started = true;
                prompt.text = "Grab the coin to bring in the arp";
                player.velocityX = 40;
            }
        }

        // After coin collected, fade arp out then switch to level 2
        if (winTimer >= 0) {
            winTimer += dt;
            if (winTimer >= 3.0 && !fadedOut) {
                fadedOut = true;
                FmodManager.SetEventParameterOnSong("FadeArpIn", 0);
            }
            if (winTimer >= 6.0) {
                Main.instance.switchScene(new PlayScene2());
                return;
            }
        }

        level.moveAndCollide(player, dt);
        if (coin.overlaps(player)) getCoin();
    }

    function getCoin():Void {
        FmodManager.SetEventParameterOnSong("FadeArpIn", 1.0);
        FmodManager.PlaySoundOneShot(FmodEvents.SFXCoin);
        coin.kill();
        status.text = "You win!";
        winTimer = 0;
    }

    public function dispose():Void {
        root.remove();
    }
}
