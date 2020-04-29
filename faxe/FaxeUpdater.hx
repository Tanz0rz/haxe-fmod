package faxe;

import flixel.FlxBasic;

// Add this to your state via add(new FaxeUpdater()) 
// It automatically sends update calls to FMOD
// Updates are required by FMOD to function properly
class FaxeUpdater extends FlxBasic {
    override public function update(elapsed:Float):Void {
        FaxeSoundHelper.GetInstance().Update();
    }
}