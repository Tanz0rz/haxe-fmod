package;

import h2d.Bitmap;
import h2d.Object;
import h2d.Tile;
import platformer.TileGrid;

/** The shared tilemap and physics, drawn as plain Heaps bitmaps. */
class Level {
    public var root:Object;
    public var grid(default, null):TileGrid;

    public function new(parent:Object) {
        root = new Object(parent);
        grid = new TileGrid(haxe.Resource.getString("level"));
        var tile = Tile.fromColor(0x555555, TileGrid.TILE, TileGrid.TILE);
        grid.forEachSolid((tx, ty) -> {
            var bitmap = new Bitmap(tile, root);
            bitmap.x = tx * TileGrid.TILE;
            bitmap.y = ty * TileGrid.TILE;
        });
    }

    public function moveAndCollide(body:Body, dt:Float):Void {
        grid.moveAndCollide(body, dt);
    }
}

/** A shared physics body drawn as a colored Heaps bitmap. */
class Body extends platformer.TileGrid.Body {
    public var bitmap:Bitmap;

    public function new(parent:Object, x:Float, y:Float, width:Int, height:Int, color:Int) {
        super(x, y, width, height);
        bitmap = new Bitmap(Tile.fromColor(color, width, height), parent);
        sync();
    }

    override public function sync():Void {
        bitmap.x = x;
        bitmap.y = y;
    }

    override public function kill():Void {
        super.kill();
        bitmap.visible = false;
    }
}
