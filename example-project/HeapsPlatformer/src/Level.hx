package;

import h2d.Bitmap;
import h2d.Object;
import h2d.Tile;

/**
 * The EZPlatformer tilemap (level.csv, 8px tiles, 1 = solid) drawn as
 * plain bitmaps, plus the small amount of platformer physics the two
 * levels need: gravity, capped velocity, axis-separated AABB collision
 * against solid tiles, and touching flags.
 */
class Level {
    public static inline var TILE:Int = 8;

    public var root:Object;
    public var widthTiles(default, null):Int = 0;
    public var heightTiles(default, null):Int = 0;

    var solid:Array<Array<Bool>> = [];

    public function new(parent:Object) {
        root = new Object(parent);
        var csv = haxe.Resource.getString("level");
        var tile = Tile.fromColor(0x555555, TILE, TILE);
        for (line in csv.split("\n")) {
            var trimmed = StringTools.trim(line);
            if (trimmed == "") continue;
            var row = [];
            for (cell in trimmed.split(",")) {
                var isSolid = Std.parseInt(StringTools.trim(cell)) != 0;
                row.push(isSolid);
                if (isSolid) {
                    var bitmap = new Bitmap(tile, root);
                    bitmap.x = row.length * TILE - TILE;
                    bitmap.y = solid.length * TILE;
                }
            }
            solid.push(row);
            if (row.length > widthTiles) widthTiles = row.length;
        }
        heightTiles = solid.length;
    }

    public function isSolid(tx:Int, ty:Int):Bool {
        if (ty < 0 || ty >= solid.length) return false;
        var row = solid[ty];
        if (tx < 0 || tx >= row.length) return false;
        return row[tx];
    }

    /** True when any solid tile overlaps the rectangle. */
    public function overlapsSolid(x:Float, y:Float, w:Float, h:Float):Bool {
        var x0 = Math.floor(x / TILE);
        var y0 = Math.floor(y / TILE);
        var x1 = Math.ceil((x + w) / TILE) - 1;
        var y1 = Math.ceil((y + h) / TILE) - 1;
        for (ty in y0...y1 + 1) {
            for (tx in x0...x1 + 1) {
                if (isSolid(tx, ty)) return true;
            }
        }
        return false;
    }

    /**
     * Moves the body by its velocity over dt and resolves collisions one
     * axis at a time, the way flixel's tilemap collide does. Sets the
     * body's touching flags.
     */
    public function moveAndCollide(body:Body, dt:Float):Void {
        body.velocityY = clamp(body.velocityY + body.accelerationY * dt, body.maxVelocityY);
        body.velocityX = clamp(body.velocityX, body.maxVelocityX);
        body.touchingDown = false;
        body.touchingRight = false;
        body.touchingLeft = false;
        body.touchingUp = false;

        var dx = body.velocityX * dt;
        body.x += dx;
        if (overlapsSolid(body.x, body.y, body.width, body.height)) {
            if (dx > 0) {
                body.x = Math.floor((body.x + body.width) / TILE) * TILE - body.width;
                body.touchingRight = true;
            } else if (dx < 0) {
                body.x = Math.ceil(body.x / TILE) * TILE;
                body.touchingLeft = true;
            }
            body.velocityX = 0;
        }

        var dy = body.velocityY * dt;
        body.y += dy;
        if (overlapsSolid(body.x, body.y, body.width, body.height)) {
            if (dy > 0) {
                body.y = Math.floor((body.y + body.height) / TILE) * TILE - body.height;
                body.touchingDown = true;
            } else if (dy < 0) {
                body.y = Math.ceil(body.y / TILE) * TILE;
                body.touchingUp = true;
            }
            body.velocityY = 0;
        }
        // Resting on the floor counts as touching it even with no motion
        if (!body.touchingDown && overlapsSolid(body.x, body.y + 1, body.width, body.height)) {
            body.touchingDown = true;
        }
        body.sync();
    }

    static inline function clamp(value:Float, max:Float):Float {
        return value > max ? max : (value < -max ? -max : value);
    }
}

/** A colored rectangle with flixel-style motion fields. */
class Body {
    public var bitmap:Bitmap;
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    public var velocityX:Float = 0;
    public var velocityY:Float = 0;
    public var accelerationY:Float = 0;
    public var maxVelocityX:Float = 10000;
    public var maxVelocityY:Float = 10000;
    public var touchingDown:Bool = false;
    public var touchingUp:Bool = false;
    public var touchingLeft:Bool = false;
    public var touchingRight:Bool = false;
    public var alive:Bool = true;

    public function new(parent:Object, x:Float, y:Float, width:Int, height:Int, color:Int) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        bitmap = new Bitmap(Tile.fromColor(color, width, height), parent);
        sync();
    }

    public function sync():Void {
        bitmap.x = x;
        bitmap.y = y;
    }

    public function overlaps(other:Body):Bool {
        return alive && other.alive
            && x < other.x + other.width && x + width > other.x
            && y < other.y + other.height && y + height > other.y;
    }

    public function kill():Void {
        alive = false;
        bitmap.visible = false;
    }
}
