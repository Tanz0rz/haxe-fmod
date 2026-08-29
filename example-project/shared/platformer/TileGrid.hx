package platformer;

/**
 * The EZPlatformer tilemap (level.csv, 8px tiles, 1 = solid) plus the
 * small amount of platformer physics the two levels need: gravity, capped
 * velocity, axis-separated AABB collision against solid tiles, and
 * touching flags. Engine-free, so every example game shares one set of
 * rules and only draws differently.
 */
class TileGrid {
    public static inline var TILE:Int = 8;

    public var widthTiles(default, null):Int = 0;
    public var heightTiles(default, null):Int = 0;

    var solid:Array<Array<Bool>> = [];

    public function new(csv:String) {
        for (line in csv.split("\n")) {
            var trimmed = StringTools.trim(line);
            if (trimmed == "") continue;
            var row = [];
            for (cell in trimmed.split(",")) {
                row.push(Std.parseInt(StringTools.trim(cell)) != 0);
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

    /** Calls fn for every solid tile, in row order. */
    public function forEachSolid(fn:Int->Int->Void):Void {
        for (ty in 0...solid.length) {
            for (tx in 0...solid[ty].length) {
                if (solid[ty][tx]) fn(tx, ty);
            }
        }
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
     * body's touching flags and calls its sync() hook at the end.
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

/** A rectangle with flixel-style motion fields. Engines subclass it to draw. */
class Body {
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

    public function new(x:Float, y:Float, width:Float, height:Float) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    /** Called after every move so a drawable can follow the position. */
    public function sync():Void {}

    public function overlaps(other:Body):Bool {
        return alive && other.alive
            && x < other.x + other.width && x + width > other.x
            && y < other.y + other.height && y + height > other.y;
    }

    public function kill():Void {
        alive = false;
    }
}
