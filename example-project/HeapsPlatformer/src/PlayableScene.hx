package;

import h2d.Object;
import h2d.Scene;
import h2d.Text;
import hxd.Key;
import Level.Body;
import platformer.Playable;

/**
 * The playable level that builds with -D playable start in. Arrow keys or
 * A and D move, space, up or W jump. Collect every coin, then reach the
 * exit. Each coin plays a sound and brings the arp into the music.
 */
class PlayableScene implements GameScene {
    var justDied:Bool;
    var root:Object;
    var level:Level;
    var player:Body;
    var exit:Body;
    var coins:Array<Body> = [];
    var collected:Int = 0;
    var scoreText:Text;
    var status:Text;

    public function new(justDied:Bool = false) {
        this.justDied = justDied;
    }

    public function create(s2d:Scene):Void {
        haxefmod.heaps.FmodHeapsSetup.init();
        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        root = new Object(s2d);
        level = new Level(root, "playable_level");

        exit = new Body(root, Playable.EXIT_X, Playable.EXIT_Y, Playable.EXIT_WIDTH, Playable.EXIT_HEIGHT, 0x008000);
        exit.kill();

        for (tile in Playable.COINS) {
            coins.push(new Body(root, Playable.coinX(tile), Playable.coinY(tile), Playable.COIN_WIDTH, Playable.COIN_HEIGHT, 0xffff00));
        }

        player = new Body(root, Playable.PLAYER_X, Playable.PLAYER_Y, 8, 8, 0xff0000);
        Playable.tune(player);

        var font = hxd.res.DefaultFont.get();
        scoreText = new Text(font, root);
        scoreText.x = 2;
        scoreText.y = 2;
        scoreText.text = Playable.score(0);
        status = new Text(font, root);
        status.x = Playable.SCREEN_WIDTH - 160 - 2;
        status.y = 2;
        status.maxWidth = 160;
        status.textAlign = Right;
        status.text = justDied ? "Aww, you died!" : "Collect coins.";
    }

    public function update(dt:Float):Void {
        if (!player.alive) return;
        Playable.steer(player, Key.isDown(Key.LEFT) || Key.isDown(Key.A), Key.isDown(Key.RIGHT) || Key.isDown(Key.D), dt);
        if ((Key.isPressed(Key.SPACE) || Key.isPressed(Key.UP) || Key.isPressed(Key.W)) && Playable.jump(player)) {
            FmodManager.PlayOneShot(FmodEvents.SFXJump);
        }
        level.moveAndCollide(player, dt);

        for (coin in coins) {
            if (coin.overlaps(player)) getCoin(coin);
        }
        if (exit.overlaps(player)) win();

        if (Playable.fellOut(player)) {
            // PlaySong in the new scene leaves the running song alone
            Main.instance.switchScene(new PlayableScene(true));
        }
    }

    function getCoin(coin:Body):Void {
        FmodManager.SetSongParameter("FadeArpIn", 1.0);
        FmodManager.PlayOneShot(FmodEvents.SFXCoin);
        coin.kill();
        collected++;
        scoreText.text = Playable.score(collected);
        if (collected == coins.length) {
            status.text = "Find the exit";
            exit.alive = true;
            exit.bitmap.visible = true;
        }
    }

    function win():Void {
        status.text = "Yay, you won!";
        scoreText.text = "SCORE: 5000";
        player.kill();
    }

    public function dispose():Void {
        root.remove();
    }
}
