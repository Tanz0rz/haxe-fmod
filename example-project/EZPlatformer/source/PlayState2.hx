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
import flixel.util.FlxDirectionFlags;

class PlayState2 extends FlxState {
    var _level:FlxTilemap;
    var _player:FlxSprite;
    var _status:FlxText;
    var _coins:FlxGroup;
    var _jumped:Bool = false;

    override public function onFocus() {
        super.onFocus();
        FmodManager.SetEventParameterOnSong("HighPass", 0);
    }

    override public function onFocusLost() {
        super.onFocusLost();
        FmodManager.SetEventParameterOnSong("HighPass", 1);
    }

    override public function create():Void {
        FlxG.mouse.visible = false;
        FlxG.cameras.bgColor = 0xffaaaaaa;

        _level = new FlxTilemap();
        _level.loadMapFromCSV("assets/level.csv", FlxGraphic.fromClass(GraphicAuto), 0, 0, AUTO);
        add(_level);

        // Coin on the floor to jump over
        _coins = new FlxGroup();
        createCoin(16, 28);
        add(_coins);

        // Player auto-moves right
        _player = new FlxSprite(5 * 8, 28 * 8);
        _player.makeGraphic(8, 8, FlxColor.RED);
        _player.maxVelocity.set(80, 200);
        _player.acceleration.y = 200;
        _player.velocity.x = 40;
        add(_player);

        _status = new FlxText(0, FlxG.height / 2 - 4, FlxG.width, "Jump sound");
        _status.setFormat(null, 8, FlxColor.WHITE, CENTER, NONE, FlxColor.BLACK);
        add(_status);
    }

    override public function update(elapsed:Float):Void {
        // FmodManager.Update() runs via the FmodFlxUpdater plugin added in PlayState

        // Auto-jump when approaching the coin
        if (!_jumped && _player.x >= 14 * 8 && _player.isTouching(FlxDirectionFlags.DOWN)) {
            FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
            _player.velocity.y = -_player.maxVelocity.y / 2;
            _jumped = true;
        }

        // Exit at the far right wall so CI captures end with the demo.
        // Normal builds keep the window open.
        #if sys
        var ciExit = Sys.getEnv("FMOD_WAVWRITER") != null;
        #if audio_test
        ciExit = true;
        #end
        if (ciExit && _player.x >= 38 * 8 && _player.isTouching(FlxDirectionFlags.RIGHT)) {
            Sys.exit(0);
        }
        #end

        super.update(elapsed);

        FlxG.overlap(_coins, _player, getCoin);
        FlxG.collide(_level, _player);
    }

    function createCoin(X:Int, Y:Int):Void {
        var coin:FlxSprite = new FlxSprite(X * 8 + 3, Y * 8 + 2);
        coin.makeGraphic(2, 4, 0xffffff00);
        _coins.add(coin);
    }

    function getCoin(Coin:FlxObject, Player:FlxObject):Void {
        FmodManager.PlaySoundOneShot(FmodEvents.SFXCoin);
        Coin.kill();
        _status.text = "Oops! Collected the coin.";
    }
}
