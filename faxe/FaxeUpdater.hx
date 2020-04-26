package faxe;

import flixel.FlxBasic;

class FaxeUpdater extends FlxBasic {
    override public function update(elapsed:Float):Void {
        FaxeSoundHelper.GetInstance().Update();
    }
}