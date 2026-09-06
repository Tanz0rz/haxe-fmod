package;

import h2d.Object;
import h2d.Scene;
import h2d.Text;
import Level.Body;

/** Level 2: auto-run right, jump over the coin, exit at the far wall in CI. */
class PlayScene2 implements GameScene {
    var root:Object;
    var level:Level;
    var player:Body;
    var jumped:Bool = false;

    public function new() {}

    public function create(s2d:Scene):Void {
        root = new Object(s2d);
        level = new Level(root);

        // Coin on the floor to jump over
        new Body(root, 16 * 8 + 3, 28 * 8 + 2, 2, 4, 0xffff00);

        // Player auto-moves right
        player = new Body(root, 5 * 8, 28 * 8, 8, 8, 0xff0000);
        player.maxVelocityX = 80;
        player.maxVelocityY = 200;
        player.accelerationY = 200;
        player.velocityX = 40;

        var status = new Text(hxd.res.DefaultFont.get(), root);
        status.text = "Jump sound";
        status.textAlign = Center;
        status.maxWidth = 320;
        status.x = 160;
        status.y = 120 - 4;
    }

    public function update(dt:Float):Void {
        // Auto-jump when approaching the coin
        if (!jumped && player.x >= 14 * 8 && player.touchingDown) {
            FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
            player.velocityY = -player.maxVelocityY / 2;
            jumped = true;
        }

        // The wavwriter CI runs need the process to exit at the far right
        // wall so the capture ends with the demo. Normal builds keep the
        // window open.
        #if sys
        if (Sys.getEnv("FMOD_WAVWRITER") != null && player.x >= 38 * 8 && player.touchingRight) {
            Sys.exit(0);
        }
        #end

        level.moveAndCollide(player, dt);
        // Keep the run going at the wall: velocity is zeroed on contact
        if (player.velocityX == 0) player.velocityX = 40;
    }

    public function dispose():Void {
        root.remove();
    }
}
