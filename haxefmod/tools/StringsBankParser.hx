package haxefmod.tools;

import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

typedef StringsBankEntry = {
	var path:String;
	var guid:String;
}

/**
 * Parses a compiled FMOD Studio strings bank (Master.strings.bank) and
 * returns every path/GUID pair it contains, exactly as the FMOD runtime
 * reports them via Bank::getStringInfo.
 *
 * Layout (determined empirically from FMOD Studio 2.03.x banks and verified
 * byte-for-byte against the FMOD runtime's own string table output):
 *
 * The file is a RIFF container ("RIFF" <u32 size> "FEV ") of nested chunks;
 * "LIST" chunks hold a 4-byte list type followed by child chunks. The string
 * table lives in the "STDT" chunk (nested inside LIST/PROJ). Paths are NOT
 * stored as flat strings - they are fragments in a compressed radix trie.
 *
 * STDT payload (all integers little-endian):
 *
 *   u32  tableCount            always 1 in observed banks
 *   u16  nodeCountEnc          (nodeCount << 1) | 1
 *   u16  nodeSize              always 8
 *   node[nodeCount], 8 bytes each:
 *     u24 fragOffset           offset of this node's NUL-terminated path
 *                              fragment in the fragment blob. 0xffffff means
 *                              an empty fragment (root node or leaf marker)
 *     u8  branchChar           lowercased first character of the fragment
 *                              (binary-search aid for path lookups)
 *     u24 value                first-child node index for interior nodes,
 *                              string index for leaves
 *     u8  childCount           number of children. 0 marks a leaf
 *   u16  guidCountEnc          (guidCount << 1) | 1
 *   u16  guidSize              always 16
 *   guid[guidCount], 16 bytes: data1 u32 LE, data2 u16 LE, data3 u16 LE,
 *                              data4 8 raw bytes (same field order as
 *                              FMOD_GUID. Formatted by faxe_guid_format)
 *   u16  blobLen
 *   u8[blobLen]                fragment blob (NUL-terminated strings)
 *   u16  leafCount             == guidCount
 *   u24[leafCount]             string index -> leaf node index
 *   u16  parentCount           == nodeCount
 *   u24[parentCount]           node index -> parent node index (0xffffff
 *                              for the root)
 *
 * Path i is reconstructed by walking parent links from leaf[i] up to the
 * root and concatenating the fragments root-first (e.g. "b" + "ank:/Master"
 * + ".strings"). GUIDs are stored sorted by their formatted string form;
 * guid[i] pairs with path i. The parse is validated by requiring the STDT
 * payload to be consumed exactly, so layout drift errors out instead of
 * producing garbage.
 */
class StringsBankParser {
	/** Reads and parses a strings bank file. Throws haxe.Exception with an
		actionable message on any failure. */
	public static function parseFile(path:String):Array<StringsBankEntry> {
		if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) {
			throw new haxe.Exception('Strings bank not found: $path'
				+ " - expected a Master.strings.bank built by FMOD Studio (enable"
				+ ' "Include strings bank" in the FMOD Studio build settings, or pass --strings <path>).');
		}
		return parse(File.getBytes(path), path);
	}

	/** Parses strings bank bytes. sourceName is used in error messages. */
	public static function parse(bytes:Bytes, sourceName:String):Array<StringsBankEntry> {
		if (bytes.length < 16 || bytes.getString(0, 4) != "RIFF" || bytes.getString(8, 4) != "FEV ") {
			throw new haxe.Exception('$sourceName is not an FMOD bank'
				+ " - expected a RIFF/FEV header (a Master.strings.bank built by FMOD Studio).");
		}

		var riffSize = readU32(bytes, 4);
		var end = 8 + riffSize;
		if (end > bytes.length) end = bytes.length;

		var stdt = findChunk(bytes, 12, end, "STDT");
		if (stdt == null) {
			throw new haxe.Exception('No string table (STDT chunk) found in $sourceName'
				+ " - this looks like a regular bank, not the strings bank."
				+ " Point --strings at the Master.strings.bank file.");
		}

		var entries = try {
			parseStringTable(bytes, stdt.start, stdt.end);
		} catch (e:haxe.Exception) {
			throw new haxe.Exception('Failed to parse the string table in $sourceName: ${e.message}'
				+ " - the bank may be corrupt or use an unsupported FMOD Studio format.");
		}

		if (entries.length == 0) {
			throw new haxe.Exception('The string table in $sourceName is empty'
				+ " - expected at least one event:/, bus:/, vca:/, snapshot:/ or parameter:/ path."
				+ " Rebuild banks in FMOD Studio and try again.");
		}
		return entries;
	}

	/** Depth-first search for the first chunk with the given tag between
		start and end. Returns the payload range or null. */
	static function findChunk(bytes:Bytes, start:Int, end:Int, tag:String):Null<{start:Int, end:Int}> {
		var p = start;
		while (p + 8 <= end) {
			var chunkTag = bytes.getString(p, 4);
			var size = readU32(bytes, p + 4);
			var payloadStart = p + 8;
			var payloadEnd = payloadStart + size;
			// A negative size (a crafted 32-bit value read as signed) would
			// stall or rewind the scan pointer forever
			if (size < 0 || payloadEnd > end) return null; // corrupt chunk, stop scanning
			if (chunkTag == tag) return {start: payloadStart, end: payloadEnd};
			if (chunkTag == "LIST" && size >= 4) {
				// LIST payload: 4-byte list type, then child chunks
				var inner = findChunk(bytes, payloadStart + 4, payloadEnd, tag);
				if (inner != null) return inner;
			}
			// RIFF chunks are word-aligned. Sizes are padded to even
			p = payloadEnd + (size & 1);
		}
		return null;
	}

	static function parseStringTable(bytes:Bytes, start:Int, end:Int):Array<StringsBankEntry> {
		var p = start;
		inline function remaining():Int
			return end - p;

		if (remaining() < 8) throw new haxe.Exception("string table chunk is truncated");
		var tableCount = readU32(bytes, p);
		p += 4;
		if (tableCount != 1) throw new haxe.Exception('unsupported string table count $tableCount (expected 1)');

		// trie nodes
		var nodeCountEnc = readU16(bytes, p);
		var nodeSize = readU16(bytes, p + 2);
		p += 4;
		if (nodeSize != 8 || nodeCountEnc & 1 != 1)
			throw new haxe.Exception('unexpected trie node header (count field $nodeCountEnc, node size $nodeSize)');
		var nodeCount = nodeCountEnc >> 1;
		if (remaining() < nodeCount * 8) throw new haxe.Exception("truncated trie node array");
		var fragOffsets = new Array<Int>();
		for (i in 0...nodeCount) {
			var off = readU24(bytes, p);
			fragOffsets.push(off == 0xffffff ? -1 : off);
			// skip branchChar (1), value (3), childCount (1)
			p += 8;
		}

		// GUIDs
		if (remaining() < 4) throw new haxe.Exception("truncated GUID header");
		var guidCountEnc = readU16(bytes, p);
		var guidSize = readU16(bytes, p + 2);
		p += 4;
		if (guidSize != 16 || guidCountEnc & 1 != 1)
			throw new haxe.Exception('unexpected GUID header (count field $guidCountEnc, GUID size $guidSize)');
		var guidCount = guidCountEnc >> 1;
		if (remaining() < guidCount * 16) throw new haxe.Exception("truncated GUID array");
		var guids = new Array<String>();
		for (i in 0...guidCount) {
			guids.push(formatGuid(bytes, p));
			p += 16;
		}

		// fragment blob
		if (remaining() < 2) throw new haxe.Exception("truncated fragment blob header");
		var blobLen = readU16(bytes, p);
		p += 2;
		var blobStart = p;
		if (remaining() < blobLen) throw new haxe.Exception("truncated fragment blob");
		p += blobLen;

		// string index -> leaf node index
		if (remaining() < 2) throw new haxe.Exception("truncated leaf table header");
		var leafCount = readU16(bytes, p);
		p += 2;
		if (leafCount != guidCount)
			throw new haxe.Exception('leaf table count $leafCount does not match GUID count $guidCount');
		if (remaining() < leafCount * 3) throw new haxe.Exception("truncated leaf table");
		var leaves = new Array<Int>();
		for (i in 0...leafCount) {
			leaves.push(readU24(bytes, p));
			p += 3;
		}

		// node index -> parent node index
		if (remaining() < 2) throw new haxe.Exception("truncated parent table header");
		var parentCount = readU16(bytes, p);
		p += 2;
		if (parentCount != nodeCount)
			throw new haxe.Exception('parent table count $parentCount does not match node count $nodeCount');
		if (remaining() < parentCount * 3) throw new haxe.Exception("truncated parent table");
		var parents = new Array<Int>();
		for (i in 0...parentCount) {
			var v = readU24(bytes, p);
			parents.push(v == 0xffffff ? -1 : v);
			p += 3;
		}

		// the layout is only trusted if it accounts for every byte
		if (p != end)
			throw new haxe.Exception('string table has ${end - p} unexpected trailing byte(s)');

		var entries = new Array<StringsBankEntry>();
		for (i in 0...guidCount) {
			var parts = new Array<String>();
			var node = leaves[i];
			var steps = 0;
			while (node >= 0) {
				if (node >= nodeCount || ++steps > nodeCount)
					throw new haxe.Exception('corrupt trie link at string $i (node $node)');
				var off = fragOffsets[node];
				if (off >= 0) {
					if (off >= blobLen) throw new haxe.Exception('fragment offset $off outside blob (string $i)');
					parts.unshift(readCString(bytes, blobStart + off, blobStart + blobLen));
				}
				node = parents[node];
			}
			entries.push({path: parts.join(""), guid: guids[i]});
		}
		return entries;
	}

	/** Formats 16 GUID bytes as "{8-4-4-4-12}" lowercase, matching the
		native shims' faxe_guid_format (FMOD_GUID field order: Data1 u32 LE,
		Data2/Data3 u16 LE, Data4 raw bytes). */
	static function formatGuid(bytes:Bytes, p:Int):String {
		var data1 = StringTools.hex(readU32(bytes, p), 8);
		var data2 = StringTools.hex(readU16(bytes, p + 4), 4);
		var data3 = StringTools.hex(readU16(bytes, p + 6), 4);
		var data4 = "";
		for (i in 8...16)
			data4 += StringTools.hex(bytes.get(p + i), 2);
		var s = '{$data1-$data2-$data3-${data4.substr(0, 4)}-${data4.substr(4)}}';
		return s.toLowerCase();
	}

	static function readCString(bytes:Bytes, p:Int, limit:Int):String {
		var q = p;
		while (q < limit && bytes.get(q) != 0)
			q++;
		return bytes.getString(p, q - p);
	}

	static inline function readU16(bytes:Bytes, p:Int):Int
		return bytes.get(p) | (bytes.get(p + 1) << 8);

	static inline function readU24(bytes:Bytes, p:Int):Int
		return bytes.get(p) | (bytes.get(p + 1) << 8) | (bytes.get(p + 2) << 16);

	static inline function readU32(bytes:Bytes, p:Int):Int
		return bytes.get(p) | (bytes.get(p + 1) << 8) | (bytes.get(p + 2) << 16) | (bytes.get(p + 3) << 24);
}
