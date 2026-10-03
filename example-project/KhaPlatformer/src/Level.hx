package;

import kha.graphics2.Graphics;
import platformer.TileGrid;

/** The shared tilemap and physics, drawn with Graphics2 rectangles. */
class Level {
    public var grid(default, null):TileGrid;

    public function new() {
        grid = new TileGrid(haxe.Resource.getString("level"));
    }

    public function moveAndCollide(body:Body, dt:Float):Void {
        grid.moveAndCollide(body, dt);
    }

    public function render(g2:Graphics):Void {
        g2.color = 0xff555555;
        grid.forEachSolid((tx, ty) -> g2.fillRect(tx * TileGrid.TILE, ty * TileGrid.TILE, TileGrid.TILE, TileGrid.TILE));
    }
}

/** A shared physics body drawn as a colored rectangle. */
class Body extends platformer.TileGrid.Body {
    public var color:Int;

    public function new(x:Float, y:Float, width:Int, height:Int, color:Int) {
        super(x, y, width, height);
        this.color = color;
    }

    public function render(g2:Graphics):Void {
        if (!alive) return;
        g2.color = color;
        g2.fillRect(x, y, width, height);
    }
}
