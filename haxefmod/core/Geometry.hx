package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;
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

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Creates an empty geometry with room for the given polygon and vertex
     * counts (unsupported in HTML5). Returns Geometry.NULL on failure (see
     * StudioSystem.lastResult).
     */
    public static macro function create(maxPolygons:haxe.macro.Expr, maxVertices:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.create", "the web build has no geometry occlusion");
    }
    #else
    /**
     * Creates an empty geometry with room for the given polygon and vertex
     * counts (unsupported in HTML5). Returns Geometry.NULL on failure (see
     * StudioSystem.lastResult).
     */
    public static inline function create(maxPolygons:Int, maxVertices:Int):Geometry {
        return NativeStudio.sys_create_geometry(maxPolygons, maxVertices);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Rebuilds a geometry from the bytes save() produced (unsupported in
     * HTML5). Returns Geometry.NULL on failure.
     */
    public static macro function load(data:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.load", "the web build has no geometry occlusion");
    }
    #else
    /**
     * Rebuilds a geometry from the bytes save() produced (unsupported in
     * HTML5). Returns Geometry.NULL on failure.
     */
    public static function load(data:haxe.io.Bytes):Geometry {
        if (data == null || data.length == 0) return NULL;
        return NativeStudio.sys_load_geometry(data, data.length);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The largest world size the occlusion calculation handles
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). FMOD's
     * default is 1000 units.
     */
    public static macro function setWorldSize(maxWorldSize:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setWorldSize", "the web build has no geometry occlusion");
    }
    #else
    /**
     * The largest world size the occlusion calculation handles
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). FMOD's
     * default is 1000 units.
     */
    public static inline function setWorldSize(maxWorldSize:Float):FmodResult {
        return NativeStudio.sys_set_geometry_settings(maxWorldSize);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The current world size, 0 on failure (unsupported in HTML5, 0 there). */
    public static macro function getWorldSize():haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getWorldSize", "the web build has no geometry occlusion");
    }
    #else
    /** The current world size, 0 on failure (unsupported in HTML5, 0 there). */
    public static inline function getWorldSize():Float {
        return NativeStudio.sys_get_geometry_settings();
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The occlusion every active geometry applies between a listener and
     * a source position (unsupported in HTML5, null there). Null on
     * failure.
     */
    public static macro function getOcclusion(listener:haxe.macro.Expr, source:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getOcclusion", "the web build has no geometry occlusion");
    }
    #else
    /**
     * The occlusion every active geometry applies between a listener and
     * a source position (unsupported in HTML5, null there). Null on
     * failure.
     */
    public static function getOcclusion(listener:FmodVector, source:FmodVector):Null<FmodOcclusion> {
        if (listener == null || source == null) return null;
        var result:FmodResult = NativeStudio.sys_get_geometry_occlusion(listener.x, listener.y, listener.z,
            source.x, source.y, source.z);
        if (!result.isOk()) return null;
        return {direct: Scratch.readF(0), reverb: Scratch.readF(1)};
    }
    #end

    public inline function isNull():Bool {
        return this == 0;
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Frees the geometry and invalidates this handle (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function release(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.release", "the web build has no geometry occlusion");
    }
    #else
    /** Frees the geometry and invalidates this handle (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function release():FmodResult {
        haxefmod.studio.UserData.clear(haxefmod.studio.UserData.UserDataKind.Geometry, this);
        return NativeStudio.geo_release(this);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Adds a convex polygon from at least three vertices in object space
     * and returns its index, -1 on failure (unsupported in HTML5, -1
     * there). direct and reverb are occlusion amounts from 0 (open) to 1
     * (blocked). A double sided polygon occludes from both faces.
     */
    public macro function addPolygon(self:haxe.macro.Expr, direct:haxe.macro.Expr, reverb:haxe.macro.Expr, doubleSided:haxe.macro.Expr, vertices:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.addPolygon", "the web build has no geometry occlusion");
    }
    #else
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
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Polygons added so far, -1 on failure (unsupported in HTML5, -1 there). */
    public macro function getNumPolygons(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getNumPolygons", "the web build has no geometry occlusion");
    }
    #else
    /** Polygons added so far, -1 on failure (unsupported in HTML5, -1 there). */
    public inline function getNumPolygons():Int {
        return NativeStudio.geo_get_num_polygons(this);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The capacities given at creation, null on failure (unsupported in HTML5, null there). */
    public macro function getMaxPolygons(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getMaxPolygons", "the web build has no geometry occlusion");
    }
    #else
    /** The capacities given at creation, null on failure (unsupported in HTML5, null there). */
    public function getMaxPolygons():Null<FmodGeometryMaxPolygons> {
        var result:FmodResult = NativeStudio.geo_get_max_polygons(this);
        if (!result.isOk()) return null;
        return {polygons: Scratch.readI(0), vertices: Scratch.readI(1)};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Vertex count of one polygon, -1 on failure (unsupported in HTML5, -1 there). */
    public macro function getPolygonNumVertices(self:haxe.macro.Expr, index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getPolygonNumVertices", "the web build has no geometry occlusion");
    }
    #else
    /** Vertex count of one polygon, -1 on failure (unsupported in HTML5, -1 there). */
    public inline function getPolygonNumVertices(index:Int):Int {
        return NativeStudio.geo_get_polygon_num_vertices(this, index);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Moves one vertex of a polygon (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setPolygonVertex(self:haxe.macro.Expr, index:haxe.macro.Expr, vertexIndex:haxe.macro.Expr, vertex:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setPolygonVertex", "the web build has no geometry occlusion");
    }
    #else
    /** Moves one vertex of a polygon (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setPolygonVertex(index:Int, vertexIndex:Int, vertex:FmodVector):FmodResult {
        if (vertex == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_polygon_vertex(this, index, vertexIndex, vertex.x, vertex.y, vertex.z);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** One vertex of a polygon, null on failure (unsupported in HTML5, null there). */
    public macro function getPolygonVertex(self:haxe.macro.Expr, index:haxe.macro.Expr, vertexIndex:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getPolygonVertex", "the web build has no geometry occlusion");
    }
    #else
    /** One vertex of a polygon, null on failure (unsupported in HTML5, null there). */
    public function getPolygonVertex(index:Int, vertexIndex:Int):Null<FmodVector> {
        var result:FmodResult = NativeStudio.geo_get_polygon_vertex(this, index, vertexIndex);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Changes a polygon's occlusion amounts and sidedness (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setPolygonAttributes(self:haxe.macro.Expr, index:haxe.macro.Expr, direct:haxe.macro.Expr, reverb:haxe.macro.Expr, doubleSided:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setPolygonAttributes", "the web build has no geometry occlusion");
    }
    #else
    /** Changes a polygon's occlusion amounts and sidedness (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function setPolygonAttributes(index:Int, direct:Float, reverb:Float, doubleSided:Bool):FmodResult {
        return NativeStudio.geo_set_polygon_attributes(this, index, direct, reverb, doubleSided);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** A polygon's occlusion amounts and sidedness, null on failure (unsupported in HTML5, null there). */
    public macro function getPolygonAttributes(self:haxe.macro.Expr, index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getPolygonAttributes", "the web build has no geometry occlusion");
    }
    #else
    /** A polygon's occlusion amounts and sidedness, null on failure (unsupported in HTML5, null there). */
    public function getPolygonAttributes(index:Int):Null<FmodPolygonAttributes> {
        var result:FmodResult = NativeStudio.geo_get_polygon_attributes(this, index);
        if (!result.isOk()) return null;
        return {direct: Scratch.readF(0), reverb: Scratch.readF(1), doubleSided: Scratch.readF(2) != 0};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Turns the whole geometry's occlusion on or off (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setActive(self:haxe.macro.Expr, active:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setActive", "the web build has no geometry occlusion");
    }
    #else
    /** Turns the whole geometry's occlusion on or off (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function setActive(active:Bool):FmodResult {
        return NativeStudio.geo_set_active(this, active);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Whether the geometry occludes, false on failure (unsupported in HTML5, false there). */
    public macro function getActive(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getActive", "the web build has no geometry occlusion");
    }
    #else
    /** Whether the geometry occludes, false on failure (unsupported in HTML5, false there). */
    public inline function getActive():Bool {
        return NativeStudio.geo_get_active(this);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Orients the geometry with forward and up unit vectors (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setRotation(self:haxe.macro.Expr, forward:haxe.macro.Expr, up:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setRotation", "the web build has no geometry occlusion");
    }
    #else
    /** Orients the geometry with forward and up unit vectors (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setRotation(forward:FmodVector, up:FmodVector):FmodResult {
        if (forward == null || up == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_rotation(this, forward.x, forward.y, forward.z, up.x, up.y, up.z);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The forward and up vectors, null on failure (unsupported in HTML5, null there). */
    public macro function getRotation(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getRotation", "the web build has no geometry occlusion");
    }
    #else
    /** The forward and up vectors, null on failure (unsupported in HTML5, null there). */
    public function getRotation():Null<FmodGeometryRotation> {
        var result:FmodResult = NativeStudio.geo_get_rotation(this);
        if (!result.isOk()) return null;
        return {
            forward: {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)},
            up: {x: Scratch.readF(3), y: Scratch.readF(4), z: Scratch.readF(5)}
        };
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Places the geometry in world space (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setPosition(self:haxe.macro.Expr, position:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setPosition", "the web build has no geometry occlusion");
    }
    #else
    /** Places the geometry in world space (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setPosition(position:FmodVector):FmodResult {
        if (position == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_position(this, position.x, position.y, position.z);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The world position, null on failure (unsupported in HTML5, null there). */
    public macro function getPosition(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getPosition", "the web build has no geometry occlusion");
    }
    #else
    /** The world position, null on failure (unsupported in HTML5, null there). */
    public function getPosition():Null<FmodVector> {
        var result:FmodResult = NativeStudio.geo_get_position(this);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Scales the geometry per axis (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setScale(self:haxe.macro.Expr, scale:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.setScale", "the web build has no geometry occlusion");
    }
    #else
    /** Scales the geometry per axis (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public function setScale(scale:FmodVector):FmodResult {
        if (scale == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.geo_set_scale(this, scale.x, scale.y, scale.z);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The per-axis scale, null on failure (unsupported in HTML5, null there). */
    public macro function getScale(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.getScale", "the web build has no geometry occlusion");
    }
    #else
    /** The per-axis scale, null on failure (unsupported in HTML5, null there). */
    public function getScale():Null<FmodVector> {
        var result:FmodResult = NativeStudio.geo_get_scale(this);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Serializes the geometry for Geometry.load, null on failure
     * (unsupported in HTML5, null there). The binding sizes the data first
     * and then fills a buffer of exactly that size.
     */
    public macro function save(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Geometry.save", "the web build has no geometry occlusion");
    }
    #else
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
    #end

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        haxefmod.studio.UserData.set(haxefmod.studio.UserData.UserDataKind.Geometry, this, value);
    }

    public inline function getUserData():Dynamic {
        return haxefmod.studio.UserData.get(haxefmod.studio.UserData.UserDataKind.Geometry, this);
    }
}
