package;

import kha.graphics2.Graphics;
import kha.input.KeyCode;
import kha.input.Keyboard;
import Level.Body;
import platformer.PixelFont;
import platformer.Playable;

/**
 * The playable level that builds with -D playable start in. Arrow keys or
 * A and D move, space, up or W jump. Collect every coin, then reach the
 * exit. Each coin plays a sound and brings the arp into the music.
 */
class PlayableScene implements GameScene {
    var justDied:Bool;
    var level:Level;
    var player:Body;
    var exit:Body;
    var coins:Array<Body> = [];
    var collected:Int = 0;
    var scoreText:String;
    var status:String;
    var held:Map<KeyCode, Bool> = [];
    var jumpPressed:Bool = false;

    public function new(justDied:Bool = false) {
        this.justDied = justDied;
    }

    public function create():Void {
        haxefmod.kha.FmodKhaSetup.init();
        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        level = new Level("playable_level");
        exit = new Body(Playable.EXIT_X, Playable.EXIT_Y, Playable.EXIT_WIDTH, Playable.EXIT_HEIGHT, 0xff008000);
        exit.kill();
        for (tile in Playable.COINS) {
            coins.push(new Body(Playable.coinX(tile), Playable.coinY(tile), Playable.COIN_WIDTH, Playable.COIN_HEIGHT, 0xffffff00));
        }
        player = new Body(Playable.PLAYER_X, Playable.PLAYER_Y, 8, 8, 0xffff0000);
        Playable.tune(player);

        scoreText = Playable.score(0);
        status = justDied ? "Aww, you died!" : "Collect coins.";

        var keyboard = Keyboard.get();
        if (keyboard != null) keyboard.notify(onKeyDown, onKeyUp);
    }

    function onKeyDown(key:KeyCode):Void {
        if (!held.get(key) && (key == KeyCode.Space || key == KeyCode.Up || key == KeyCode.W)) jumpPressed = true;
        held.set(key, true);
    }

    function onKeyUp(key:KeyCode):Void {
        held.set(key, false);
    }

    inline function isDown(key:KeyCode):Bool {
        return held.get(key) == true;
    }

    public function update(dt:Float):Void {
        var jump = jumpPressed;
        jumpPressed = false;
        if (!player.alive) return;
        Playable.steer(player, isDown(KeyCode.Left) || isDown(KeyCode.A), isDown(KeyCode.Right) || isDown(KeyCode.D), dt);
        if (jump && Playable.jump(player)) {
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
        scoreText = Playable.score(collected);
        if (collected == coins.length) {
            status = "Find the exit";
            exit.alive = true;
        }
    }

    function win():Void {
        status = "Yay, you won!";
        scoreText = "SCORE: 5000";
        player.kill();
    }

    public function render(g2:Graphics):Void {
        level.render(g2);
        exit.render(g2);
        for (coin in coins) coin.render(g2);
        player.render(g2);
        g2.color = 0xffffffff;
        PixelFont.draw(scoreText, 2, 2, (x, y) -> g2.fillRect(x, y, 1, 1));
        PixelFont.draw(status, Playable.SCREEN_WIDTH - 2 - PixelFont.width(status), 2, (x, y) -> g2.fillRect(x, y, 1, 1));
    }

    public function dispose():Void {
        var keyboard = Keyboard.get();
        if (keyboard != null) keyboard.remove(onKeyDown, onKeyUp, null);
    }
}
