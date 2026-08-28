package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.Types.FmodVector;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A set of occluding polygons in 3D space (FMOD Geometry). With geometry
 * in the world FMOD attenuates 3D sounds that have a polygon between
 * them and the listener, by the polygon's direct and reverb occlusion.
 * Unsupported in HTML5: create and load return Geometry.NULL there and
 * every other call returns FMOD_ERR_UNSUPPORTED, 0, false, or null.
 *
 * Handles are created objects, so release() frees the FMOD geometry.
 */
abstract Geometry(Int) from Int to Int {
    public static inline var NULL:Geometry = cast 0;

    /**
     * Creates an empty geometry with room for the given polygon and vertex
     * counts (unsupported in HTML5). Returns Geometry.NULL on failure (see
     * StudioSystem.lastResult).
     */
    public static inline function create(maxPolygons:Int, maxVertices:Int):Geometry {
        return NativeStudio.sys_create_geometry(maxPolygons, maxVertices);
    }

    /**
     * Rebuilds a geometry from the bytes save() produced (unsupported in
     * HTML5). Returns Geometry.NULL on failure.
     */
    public static function load(data:haxe.io.Bytes):Geometry {
        if (data == null || data.length == 0) return NULL;
        return NativeStudio.sys_load_geometry(data, data.length);
    }

    /**
     * The largest world size the occlusion calculation handles
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). FMOD's
     * default is 1000 units.
     */
    public static inline function setWorldSize(maxWorldSize:Float):FmodResult {
        return NativeStudio.sys_set_geometry_settings(maxWorldSize);
    }

    /** The current world size, 0 on failure (unsupported in HTML5, 0 there). */
    public static inline function getWorldSize():Float {
        return NativeStudio.sys_get_geometry_settings();
    }

    /**
     * The occlusion every active geometry applies between a listener and
     * a source position (unsupported in HTML5, null there). Null on
     * failure.
     */
    public static function getOcclusion(listener:FmodVector, source:FmodVector):Null<{direct:Float, reverb:Float}> {
        if (listener == null || source == null) return null;
        var result:FmodResult = NativeStudio.sys_get_geometry_occlusion(listener.x, listener.y, listener.z,
            source.x, source.y, source.z);
        if (!result.isOk()) return null;
        return {direct: Scratch.readF(0), reverb: Scratch.readF(1)};
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Frees the geometry and invalidates this handle (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function release():FmodResult {
        return NativeStudio.geo_release(this);
    }

    /**
     * Adds a convex polygon from at least three vertices in object space
     * and returns its index, -1 on failure (unsupported in HTML5, -1
     * there). direct and reverb are occlusion amounts from 0 (open) to 1
     * (blocked). A double sided polygon occludes from both faces.
     */
    public function addPolygon(direct:Float, reverb:Float, doubleSided:Bool, vertices:Array<FmodVector>):Int {
        if (vertices == null || vertices.length < 3) return -1;
        var packed = Scratch.packVectors(vertices);
        return NativeStudio.geo_add_polygon(this, direct, reverb, doubleSided, packed, vertices.length);
    }

    /** Polygons added so far, -1 on failure (unsupported in HTML5, -1 there). */
    public inline function getNumPolygons():Int {
        return NativeStudio.geo_get_num_polygons(this);
    }

    /** The capacities given at creation, null on failure (unsupported in HTML5, null there). */
    public function getMaxPolygons():Null<{polygons:Int, vertices:Int}> {
        var result:FmodResult = NativeStudio.geo_get_max_polygons(this);
        if (!result.isOk()) return null;
        return {polygons: Scratch.readI(0), vertices: Scratch.readI(1)};
    }

    /** Vertex count of one polygon, -1 on failure (unsupported in HTML5, -1 there). */
    public inline function getPolygonNumVertices(index:Int):Int {
        return NativeStudio.geo_get_polygon_num_vertices(this, index);
    }

    /** Moves one vertex of a polygon (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setPolygonVertex(index:Int, vertexIndex:Int, vertex:FmodVector):FmodResult {
        if (vertex == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_polygon_vertex(this, index, vertexIndex, vertex.x, vertex.y, vertex.z);
    }

    /** One vertex of a polygon, null on failure (unsupported in HTML5, null there). */
    public function getPolygonVertex(index:Int, vertexIndex:Int):Null<FmodVector> {
        var result:FmodResult = NativeStudio.geo_get_polygon_vertex(this, index, vertexIndex);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }

    /** Changes a polygon's occlusion amounts and sidedness (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function setPolygonAttributes(index:Int, direct:Float, reverb:Float, doubleSided:Bool):FmodResult {
        return NativeStudio.geo_set_polygon_attributes(this, index, direct, reverb, doubleSided);
    }

    /** A polygon's occlusion amounts and sidedness, null on failure (unsupported in HTML5, null there). */
    public function getPolygonAttributes(index:Int):Null<{direct:Float, reverb:Float, doubleSided:Bool}> {
        var result:FmodResult = NativeStudio.geo_get_polygon_attributes(this, index);
        if (!result.isOk()) return null;
        return {direct: Scratch.readF(0), reverb: Scratch.readF(1), doubleSided: Scratch.readF(2) != 0};
    }

    /** Turns the whole geometry's occlusion on or off (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function setActive(active:Bool):FmodResult {
        return NativeStudio.geo_set_active(this, active);
    }

    /** Whether the geometry occludes, false on failure (unsupported in HTML5, false there). */
    public inline function getActive():Bool {
        return NativeStudio.geo_get_active(this);
    }

    /** Orients the geometry with forward and up unit vectors (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setRotation(forward:FmodVector, up:FmodVector):FmodResult {
        if (forward == null || up == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_rotation(this, forward.x, forward.y, forward.z, up.x, up.y, up.z);
    }

    /** The forward and up vectors, null on failure (unsupported in HTML5, null there). */
    public function getRotation():Null<{forward:FmodVector, up:FmodVector}> {
        var result:FmodResult = NativeStudio.geo_get_rotation(this);
        if (!result.isOk()) return null;
        return {
            forward: {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)},
            up: {x: Scratch.readF(3), y: Scratch.readF(4), z: Scratch.readF(5)}
        };
    }

    /** Places the geometry in world space (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setPosition(position:FmodVector):FmodResult {
        if (position == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_position(this, position.x, position.y, position.z);
    }

    /** The world position, null on failure (unsupported in HTML5, null there). */
    public function getPosition():Null<FmodVector> {
        var result:FmodResult = NativeStudio.geo_get_position(this);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }

    /** Scales the geometry per axis (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setScale(scale:FmodVector):FmodResult {
        if (scale == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_scale(this, scale.x, scale.y, scale.z);
    }

    /** The per-axis scale, null on failure (unsupported in HTML5, null there). */
    public function getScale():Null<FmodVector> {
        var result:FmodResult = NativeStudio.geo_get_scale(this);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }

    /**
     * Serializes the geometry for Geometry.load, null on failure
     * (unsupported in HTML5, null there). The binding sizes the data first
     * and then fills a buffer of exactly that size.
     */
    public function save():Null<haxe.io.Bytes> {
        var size = NativeStudio.geo_save(this, null, 0);
        if (size <= 0) return null;
        var data = haxe.io.Bytes.alloc(size);
        var written = NativeStudio.geo_save(this, data, size);
        if (written != size) return null;
        return data;
    }
}
