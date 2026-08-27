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

class PlayState extends FlxState {
    var _level:FlxTilemap;
    var _player:FlxSprite;
    var _status:FlxText;
    var _prompt:FlxText;
    var _coins:FlxGroup;
    var _started:Bool = false;
    var _startDelay:Float = 0;
    var _winTimer:Float = -1;
    var _fadedOut:Bool = false;

    override public function onFocus() {
        super.onFocus();
        FmodManager.SetEventParameterOnSong("HighPass", 0);
    }

    override public function onFocusLost() {
        super.onFocusLost();
        FmodManager.SetEventParameterOnSong("HighPass", 1);
    }

    override public function create():Void {
        // One-call flixel setup: FmodFlxUpdater plugin (drives
        // FmodManager.Update) plus FlxG.sound volume routing to FMOD
        haxefmod.flixel.FmodFlxSetup.init();
        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);
        FmodManager.Todo("ambient wind loop behind the music");

        FlxG.mouse.visible = false;
        FlxG.cameras.bgColor = 0xffaaaaaa;

        _level = new FlxTilemap();
        var tileGraphic = FlxGraphic.fromClass(GraphicAuto);
        tileGraphic.persist = true;
        _level.loadMapFromCSV("assets/level.csv", tileGraphic, 0, 0, AUTO);
        add(_level);

        // Create coin to collect
        _coins = new FlxGroup();
        createCoin(16, 28);
        add(_coins);

        // Create player on the floor
        _player = new FlxSprite(5 * 8, 28 * 8);
        _player.makeGraphic(8, 8, FlxColor.RED);
        _player.maxVelocity.set(80, 200);
        _player.acceleration.y = 200;
        add(_player);

        // Camera follows player, bounded to level
        _level.follow();
        FlxG.camera.follow(_player, LOCKON);

        _status = new FlxText(2, 2, 200, "");
        _status.setFormat(null, 8, FlxColor.WHITE, null, NONE, FlxColor.BLACK);
        _status.scrollFactor.set(0, 0);
        add(_status);

        _prompt = new FlxText(0, FlxG.height / 2 - 4, FlxG.width, "Press enter to start");
        _prompt.setFormat(null, 8, FlxColor.WHITE, CENTER, NONE, FlxColor.BLACK);
        _prompt.scrollFactor.set(0, 0);
        add(_prompt);
    }

    override public function update(elapsed:Float):Void {
        // FmodManager.Update() runs via the FmodFlxUpdater plugin

        if (!_started) {
            _startDelay += elapsed;
            if (_startDelay >= 1.0 || FlxG.keys.justPressed.ENTER) {
                _started = true;
                _prompt.text = "Song parameters";
                _player.velocity.x = 40;
            }
        }

        // After coin collected, fade arp out then switch to level 2
        if (_winTimer >= 0) {
            _winTimer += elapsed;
            if (_winTimer >= 3.0 && !_fadedOut) {
                _fadedOut = true;
                FmodManager.SetEventParameterOnSong("FadeArpIn", 0);
            }
            if (_winTimer >= 6.0) {
                FlxG.switchState(new PlayState2());
            }
        }

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
        FmodManager.SetEventParameterOnSong("FadeArpIn", 1.0);
        FmodManager.PlaySoundOneShot(FmodEvents.SFXCoin);
        Coin.kill();
        _status.text = "You win!";
        _winTimer = 0;
    }
}
