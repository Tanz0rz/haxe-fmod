package platformer;

/**
 * A 3x5 pixel font for engines with no default font (Kha). It covers the
 * playable level's text: capitals, digits, and a little punctuation.
 * Lower case draws as capitals. Each glyph is five rows of three bits.
 */
class PixelFont {
    public static inline var GLYPH_WIDTH:Int = 3;
    public static inline var GLYPH_HEIGHT:Int = 5;
    public static inline var ADVANCE:Int = 4;

    static final GLYPHS:Map<String, Array<Int>> = [
        "A" => [2, 5, 7, 5, 5], "B" => [6, 5, 6, 5, 6], "C" => [3, 4, 4, 4, 3], "D" => [6, 5, 5, 5, 6],
        "E" => [7, 4, 6, 4, 7], "F" => [7, 4, 6, 4, 4], "G" => [3, 4, 5, 5, 3], "H" => [5, 5, 7, 5, 5],
        "I" => [7, 2, 2, 2, 7], "J" => [1, 1, 1, 5, 2], "K" => [5, 5, 6, 5, 5], "L" => [4, 4, 4, 4, 7],
        "M" => [5, 7, 5, 5, 5], "N" => [5, 7, 7, 7, 5], "O" => [2, 5, 5, 5, 2], "P" => [6, 5, 6, 4, 4],
        "Q" => [2, 5, 5, 6, 3], "R" => [6, 5, 6, 5, 5], "S" => [3, 4, 2, 1, 6], "T" => [7, 2, 2, 2, 2],
        "U" => [5, 5, 5, 5, 7], "V" => [5, 5, 5, 5, 2], "W" => [5, 5, 5, 7, 5], "X" => [5, 5, 2, 5, 5],
        "Y" => [5, 5, 2, 2, 2], "Z" => [7, 1, 2, 4, 7],
        "0" => [7, 5, 5, 5, 7], "1" => [2, 6, 2, 2, 7], "2" => [6, 1, 2, 4, 7], "3" => [6, 1, 2, 1, 6],
        "4" => [5, 5, 7, 1, 1], "5" => [7, 4, 6, 1, 6], "6" => [3, 4, 7, 5, 7], "7" => [7, 1, 1, 2, 2],
        "8" => [7, 5, 7, 5, 7], "9" => [7, 5, 7, 1, 6],
        ":" => [0, 2, 0, 2, 0], "!" => [2, 2, 2, 0, 2], "," => [0, 0, 0, 2, 4], "." => [0, 0, 0, 0, 2],
    ];

    public static function width(text:String):Int {
        return text.length * ADVANCE - 1;
    }

    /** Calls fill(x, y) for every lit pixel of the text drawn at (x, y). */
    public static function draw(text:String, x:Float, y:Float, fill:Float->Float->Void):Void {
        var penX = x;
        for (i in 0...text.length) {
            var rows = GLYPHS.get(text.charAt(i).toUpperCase());
            if (rows != null) {
                for (row in 0...GLYPH_HEIGHT) {
                    for (col in 0...GLYPH_WIDTH) {
                        if (rows[row] & (4 >> col) != 0) fill(penX + col, y + row);
                    }
                }
            }
            penX += ADVANCE;
        }
    }
}
