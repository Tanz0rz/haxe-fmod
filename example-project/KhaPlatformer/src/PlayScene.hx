package;

import kha.graphics2.Graphics;
import kha.input.KeyCode;
import kha.input.Keyboard;
import Level.Body;

/** Level 1: wait a second, walk right, grab the coin, the arp fades in. */
class PlayScene implements GameScene {
    var level:Level;
    var player:Body;
    var coin:Body;
    var started:Bool = false;
    var enterPressed:Bool = false;
    var startDelay:Float = 0;
    var winTimer:Float = -1;
    var fadedOut:Bool = false;

    public function new() {}

    public function create():Void {
        // One-call Kha setup: the per-frame updater (drives
        // FmodManager.Update) plus focus-driven muting
        haxefmod.kha.FmodKhaSetup.init();
        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        level = new Level();
        coin = new Body(16 * 8 + 3, 28 * 8 + 2, 2, 4, 0xffffff00);
        player = new Body(5 * 8, 28 * 8, 8, 8, 0xffff0000);
        player.maxVelocityX = 80;
        player.maxVelocityY = 200;
        player.accelerationY = 200;

        var keyboard = Keyboard.get();
        if (keyboard != null) keyboard.notify(onKeyDown, null);
    }

    function onKeyDown(key:KeyCode):Void {
        if (key == KeyCode.Return) enterPressed = true;
    }

    public function update(dt:Float):Void {
        // FmodManager.Update() runs from FmodKhaUpdater

        if (!started) {
            startDelay += dt;
            if (startDelay >= 1.0 || enterPressed) {
                started = true;
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
        winTimer = 0;
    }

    public function render(g2:Graphics):Void {
        level.render(g2);
        coin.render(g2);
        player.render(g2);
    }

    public function dispose():Void {
        var keyboard = Keyboard.get();
        if (keyboard != null) keyboard.remove(onKeyDown, null, null);
    }
}
