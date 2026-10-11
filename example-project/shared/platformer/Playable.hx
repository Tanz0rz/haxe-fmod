package platformer;

import platformer.TileGrid.Body;

/**
 * The rules of the playable EZPlatformer level that every engine shares.
 * Builds with -D playable start here instead of the scripted run. The
 * level is playable-level.csv: collect every coin, then reach the exit.
 * Falling out of the bottom of the screen restarts the level.
 */
class Playable {
    public static inline var SCREEN_WIDTH:Int = 320;
    public static inline var SCREEN_HEIGHT:Int = 240;
    public static inline var MAX_SPEED_X:Float = 80;
    public static inline var MAX_SPEED_Y:Float = 200;
    public static inline var GRAVITY:Float = 200;

    /** Coin tiles, top left, bottom left, top right, then bottom right. */
    public static final COINS:Array<Array<Int>> = [
        [18, 4], [12, 4], [9, 4], [8, 11], [1, 7], [3, 4], [5, 2], [15, 11], [16, 11],
        [3, 16], [4, 16], [1, 23], [2, 23], [3, 23], [4, 23], [5, 23], [12, 26], [13, 26], [17, 20], [18, 20],
        [21, 4], [26, 2], [29, 2], [31, 5], [34, 5], [36, 8], [33, 11], [31, 11], [29, 11], [27, 11], [25, 11], [36, 14],
        [38, 17], [33, 17], [28, 19], [25, 20], [18, 26], [22, 26], [26, 26], [30, 26],
    ];

    public static inline var EXIT_X:Float = 35 * 8 + 1;
    public static inline var EXIT_Y:Float = 25 * 8;
    public static inline var EXIT_WIDTH:Int = 14;
    public static inline var EXIT_HEIGHT:Int = 16;

    public static inline var PLAYER_X:Float = SCREEN_WIDTH / 2 - 5;
    public static inline var PLAYER_Y:Float = 0;

    public static inline var COIN_WIDTH:Int = 2;
    public static inline var COIN_HEIGHT:Int = 4;

    /** Coin position in pixels, centered in its tile. */
    public static inline function coinX(tile:Array<Int>):Float return tile[0] * 8 + 3;
    public static inline function coinY(tile:Array<Int>):Float return tile[1] * 8 + 2;

    /** Gives a new player body the playable tuning. */
    public static function tune(player:Body):Void {
        player.maxVelocityX = MAX_SPEED_X;
        player.maxVelocityY = MAX_SPEED_Y;
        player.accelerationY = GRAVITY;
    }

    /**
     * Applies the arrow keys to the player the way flixel's acceleration
     * and drag do. A held direction accelerates at four times the top
     * speed. With no direction held, drag at the same rate stops it.
     */
    public static function steer(player:Body, left:Bool, right:Bool, dt:Float):Void {
        var rate = MAX_SPEED_X * 4;
        var accel = (left ? -rate : 0.0) + (right ? rate : 0.0);
        if (accel != 0) {
            player.velocityX += accel * dt;
        } else {
            var drag = rate * dt;
            if (player.velocityX > drag) player.velocityX -= drag;
            else if (player.velocityX < -drag) player.velocityX += drag;
            else player.velocityX = 0;
        }
    }

    /** Jumps when the player stands on something. True when it jumped. */
    public static function jump(player:Body):Bool {
        if (!player.touchingDown) return false;
        player.velocityY = -MAX_SPEED_Y / 2;
        return true;
    }

    public static inline function fellOut(player:Body):Bool {
        return player.y > SCREEN_HEIGHT;
    }

    public static inline function score(collected:Int):String {
        return "SCORE: " + collected * 100;
    }
}
