package faxe;

import flixel.FlxBasic;

/**
Add this to every state's create() method using add(new FaxeUpdater())

It will automatically call FaxeSoundHelper.Update() in the background
**/ 
class FaxeUpdater extends FlxBasic {
    override public function update(elapsed:Float):Void {
        FaxeSoundHelper.Update();
    }
}