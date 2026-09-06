package;

import kha.graphics2.Graphics;
import Level.Body;

/** Level 2: auto-run right, jump over the coin, exit at the far wall in CI. */
class PlayScene2 implements GameScene {
    var level:Level;
    var player:Body;
    var coin:Body;
    var jumped:Bool = false;

    public function new() {}

    public function create():Void {
        level = new Level();
        // Coin on the floor to jump over
        coin = new Body(16 * 8 + 3, 28 * 8 + 2, 2, 4, 0xffffff00);
        // Player auto-moves right
        player = new Body(5 * 8, 28 * 8, 8, 8, 0xffff0000);
        player.maxVelocityX = 80;
        player.maxVelocityY = 200;
        player.accelerationY = 200;
        player.velocityX = 40;
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

    public function render(g2:Graphics):Void {
        level.render(g2);
        coin.render(g2);
        player.render(g2);
    }

    public function dispose():Void {}
}
