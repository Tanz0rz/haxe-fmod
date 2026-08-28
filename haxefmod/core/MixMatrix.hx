package haxefmod.core;

import haxefmod.studio.native.Scratch;

/**
 * Shared packing for the mix matrix calls on Channel, ChannelGroup, and
 * DspConnection. A matrix is one flat row-major array, one row per
 * output channel. inChannelHop is the number of floats per row, 0 means
 * the rows are packed to inChannels. FMOD mixes at most 32 channels, so
 * the native buffers hold 32 by 32 floats and larger shapes are refused.
 */
class MixMatrix {
    public static inline var MAX_CHANNELS:Int = 32;

    /** Copies the rows into the scratch buffer, false when the shape is out of range. */
    public static function pack(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int):Bool {
        var stride = inChannelHop > 0 ? inChannelHop : inChannels;
        if (matrix == null || outChannels < 1 || inChannels < 1 || outChannels > MAX_CHANNELS
                || inChannels > MAX_CHANNELS || inChannelHop < 0 || inChannelHop > MAX_CHANNELS
                || stride < inChannels) {
            return false;
        }
        var total = outChannels * stride;
        if (total > matrix.length || total > Scratch.CAPACITY) return false;
        for (i in 0...total) Scratch.writeF(i, matrix[i]);
        return true;
    }

    /**
     * Reads a matrix the native side just wrote: total floats laid out as
     * the reported output count rows of stride floats. outChannels and
     * inChannels above 0 keep only that many rows and columns.
     */
    public static function read(total:Int, outChannels:Int, inChannels:Int, inChannelHop:Int):{matrix:Array<Float>, outChannels:Int, inChannels:Int} {
        var outActual = Scratch.readI(0);
        var inActual = Scratch.readI(1);
        var stride = inChannelHop > 0 ? inChannelHop : inActual;
        var rows = outChannels > 0 && outChannels < outActual ? outChannels : outActual;
        var cols = inChannels > 0 && inChannels < stride ? inChannels : stride;
        var matrix:Array<Float> = [];
        if (stride > 0) {
            for (row in 0...rows) {
                for (col in 0...cols) {
                    var index = row * stride + col;
                    matrix.push(index < total ? Scratch.readF(index) : 0.0);
                }
            }
        }
        return {matrix: matrix, outChannels: outActual, inChannels: inActual};
    }
}
