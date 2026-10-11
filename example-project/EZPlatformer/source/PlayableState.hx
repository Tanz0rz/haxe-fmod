package;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import platformer.Playable;

/**
 * The playable level that builds with -D playable start in. Arrow keys or
 * A and D move, space, up or W jump. Collect every coin, then reach the
 * exit. Each coin plays a sound and brings the arp into the music.
 */
class PlayableState extends FlxState {
    static var justDied:Bool = false;

    var level:FlxTilemap;
    var player:FlxSprite;
    var exit:FlxSprite;
    var scoreText:FlxText;
    var status:FlxText;
    var coins:FlxGroup;

    override public function onFocus() {
        super.onFocus();
        FmodManager.SetSongParameter("HighPass", 0);
    }

    override public function onFocusLost() {
        super.onFocusLost();
        FmodManager.SetSongParameter("HighPass", 1);
    }

    override public function create():Void {
        haxefmod.flixel.FmodFlxSetup.init();
        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        FlxG.mouse.visible = false;
        FlxG.cameras.bgColor = 0xffaaaaaa;

        level = new FlxTilemap();
        var tileGraphic = FlxGraphic.fromClass(GraphicAuto);
        tileGraphic.persist = true;
        level.loadMapFromCSV("assets/playable-level.csv", tileGraphic, 0, 0, AUTO);
        add(level);

        exit = new FlxSprite(Playable.EXIT_X, Playable.EXIT_Y);
        exit.makeGraphic(Playable.EXIT_WIDTH, Playable.EXIT_HEIGHT, FlxColor.GREEN);
        exit.exists = false;
        add(exit);

        coins = new FlxGroup();
        for (tile in Playable.COINS) {
            var coin = new FlxSprite(Playable.coinX(tile), Playable.coinY(tile));
            coin.makeGraphic(Playable.COIN_WIDTH, Playable.COIN_HEIGHT, 0xffffff00);
            coins.add(coin);
        }
        add(coins);

        player = new FlxSprite(Playable.PLAYER_X, Playable.PLAYER_Y);
        player.makeGraphic(8, 8, FlxColor.RED);
        player.maxVelocity.set(Playable.MAX_SPEED_X, Playable.MAX_SPEED_Y);
        player.acceleration.y = Playable.GRAVITY;
        player.drag.x = Playable.MAX_SPEED_X * 4;
        add(player);

        scoreText = new FlxText(2, 2, 80, Playable.score(0));
        scoreText.setFormat(null, 8, FlxColor.WHITE, null, NONE, FlxColor.BLACK);
        add(scoreText);

        status = new FlxText(FlxG.width - 160 - 2, 2, 160, justDied ? "Aww, you died!" : "Collect coins.");
        status.setFormat(null, 8, FlxColor.WHITE, RIGHT, NONE, FlxColor.BLACK);
        add(status);

        #if js
        // A page that frames the game keeps the focus at first. The blur
        // puts flixel behind its pause screen until a click focuses it. It
        // waits for the first draw, so the level shows under that screen.
        FlxG.signals.postDraw.addOnce(function() {
            if (!js.Browser.document.hasFocus()) js.Browser.window.dispatchEvent(new js.html.FocusEvent("blur"));
        });
        #end
    }

    override public function update(elapsed:Float):Void {
        player.acceleration.x = 0;
        if (FlxG.keys.anyPressed([LEFT, A])) player.acceleration.x = -Playable.MAX_SPEED_X * 4;
        if (FlxG.keys.anyPressed([RIGHT, D])) player.acceleration.x = Playable.MAX_SPEED_X * 4;
        if (FlxG.keys.anyJustPressed([SPACE, UP, W]) && player.isTouching(FLOOR)) {
            FmodManager.PlayOneShot(FmodEvents.SFXJump);
            player.velocity.y = -Playable.MAX_SPEED_Y / 2;
        }

        super.update(elapsed);

        FlxG.overlap(coins, player, getCoin);
        FlxG.collide(level, player);
        FlxG.overlap(exit, player, win);

        if (player.y > Playable.SCREEN_HEIGHT) {
            justDied = true;
            FlxG.resetState();
        }
    }

    function win(exit:FlxObject, player:FlxObject):Void {
        status.text = "Yay, you won!";
        scoreText.text = "SCORE: 5000";
        player.kill();
    }

    function getCoin(coin:FlxObject, player:FlxObject):Void {
        FmodManager.SetSongParameter("FadeArpIn", 1.0);
        FmodManager.PlayOneShot(FmodEvents.SFXCoin);
        coin.kill();
        scoreText.text = Playable.score(coins.countDead());
        if (coins.countLiving() == 0) {
            status.text = "Find the exit";
            exit.exists = true;
        }
    }
}
