package haxefmod.tools;

import haxefmod.tools.StringsBankParser;
import sys.FileSystem;
import sys.io.File;

/**
 * `haxelib run haxefmod generate [--strings <path>] [--out <dir>] [--package <pkg>] [--enums]`
 *
 * Parses a compiled Master.strings.bank and emits one Haxe class per path
 * category found in it:
 *
 *   FmodEvents.hx      event:/...
 *   FmodBuses.hx       bus:/...
 *   FmodVCAs.hx        vca:/...
 *   FmodSnapshots.hx   snapshot:/...
 *   FmodParameters.hx  parameter:/...
 *
 * With --enums it additionally emits FmodEventEnum.hx: a plain
 * FmodEventEnum enum covering every event, with values named exactly like
 * the FmodEvents constants, plus a FmodEventTools.path() mapper back to the path string
 * (usable as a static extension). Plain enums suit switch statements and
 * external tools that import Haxe enums (LDtk external enums, for example).
 *
 * Each file holds the path constants plus a companion class with the
 * matching GUIDs under the same identifiers, so autocomplete on the main
 * class only shows sounds:
 *
 *   FmodEvents.MusicMainLevel        "event:/Music/MainLevel"
 *   FmodEventsGuids.MusicMainLevel   "{e5187c3f-...}"
 *
 * Identifier mangling: the category prefix is stripped, the remaining path
 * is split into segments on "/", each segment is split on any character
 * that is not a letter or digit, the first letter of every piece is
 * uppercased, and everything is concatenated ("Vehicles/Ride-on Mower" ->
 * "VehiclesRideOnMower"). An empty result (the bus:/ root) becomes "Root",
 * a leading digit gets an underscore prefix, and duplicate identifiers get
 * numeric suffixes ("Coin", "Coin2", ...).
 */
class Generate {
	static var categories = [
		{prefix: "event:/", className: "FmodEvents", label: "events"},
		{prefix: "bus:/", className: "FmodBuses", label: "buses"},
		{prefix: "vca:/", className: "FmodVCAs", label: "VCAs"},
		{prefix: "snapshot:/", className: "FmodSnapshots", label: "snapshots"},
		{prefix: "parameter:/", className: "FmodParameters", label: "parameters"},
	];

	/** Direct entry point: haxe -cp . --run haxefmod.tools.Generate <flags> */
	public static function main() {
		run(Sys.args(), Sys.getCwd());
	}

	/** Entry point used by Run.hx. cwd is the caller's working directory
		as passed by haxelib run. */
	public static function run(args:Array<String>, cwd:String) {
		var stringsPath:Null<String> = null;
		var outDir:Null<String> = null;
		var pkg = "";
		var enums = false;

		var i = 0;
		while (i < args.length) {
			switch (args[i]) {
				case "--strings":
					if (i + 1 >= args.length) usageError("--strings requires a path");
					stringsPath = args[++i];
				case "--out":
					if (i + 1 >= args.length) usageError("--out requires a directory");
					outDir = args[++i];
				case "--package":
					if (i + 1 >= args.length) usageError("--package requires a package name");
					pkg = args[++i];
				case "--enums":
					enums = true;
				case arg:
					usageError('unknown argument "$arg"');
			}
			i++;
		}

		if (stringsPath == null) stringsPath = "assets/fmod/Desktop/Master.strings.bank";
		stringsPath = absolute(stringsPath, cwd);

		if (outDir == null) {
			var source = haxe.io.Path.join([cwd, "source"]);
			outDir = (FileSystem.exists(source) && FileSystem.isDirectory(source)) ? source : cwd;
		} else {
			outDir = absolute(outDir, cwd);
		}
		// files go into the package's subdirectory so `-cp <out>` resolves them
		if (pkg != "") outDir = haxe.io.Path.join([outDir].concat(pkg.split(".")));

		var entries = try {
			StringsBankParser.parseFile(stringsPath);
		} catch (e:haxe.Exception) {
			Sys.println(e.message);
			Sys.exit(1);
			return;
		}

		Sys.println('Parsed $stringsPath: ${entries.length} entries');

		var written = 0;
		for (cat in categories) {
			var matched = entries.filter(e -> StringTools.startsWith(e.path, cat.prefix));
			if (matched.length == 0) continue;
			matched.sort((a, b) -> a.path < b.path ? -1 : a.path > b.path ? 1 : 0);

			if (!FileSystem.exists(outDir)) FileSystem.createDirectory(outDir);
			var file = haxe.io.Path.join([outDir, cat.className + ".hx"]);
			File.saveContent(file, emitClass(cat.className, cat.prefix, matched, pkg));
			written++;
			Sys.println('  ${cat.className}.hx: ${matched.length} ${cat.label}');
		}

		if (enums) {
			var enumText = emitEventEnums(entries, pkg);
			if (enumText == null) {
				Sys.println("  FmodEventEnum.hx: skipped (no events)");
			} else {
				var count = entries.filter(e -> StringTools.startsWith(e.path, "event:/")).length;
				if (!FileSystem.exists(outDir)) FileSystem.createDirectory(outDir);
				File.saveContent(haxe.io.Path.join([outDir, "FmodEventEnum.hx"]), enumText);
				written++;
				Sys.println('  FmodEventEnum.hx: $count events');
			}
		}

		if (written == 0) {
			Sys.println("No event:/, bus:/, vca:/, snapshot:/ or parameter:/ paths found - nothing to generate.");
		} else {
			Sys.println('Wrote $written file(s) to $outDir');
		}
	}

	/** Emits FmodEventEnum.hx: one FmodEventEnum enum covering every event,
		with values named exactly like the FmodEvents constants, plus a
		FmodEventTools.path()/guid() mappers. Returns null when there are no
		events.
		Kept in lockstep with fmod-scripts/ExportHaxeConstants.js
		(byte-identical output). */
	public static function emitEventEnums(entries:Array<StringsBankEntry>, pkg:String):Null<String> {
		var matched = entries.filter(e -> StringTools.startsWith(e.path, "event:/"));
		if (matched.length == 0) return null;
		matched.sort((a, b) -> a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
		var names = identifiersFor(matched.map(e -> e.path), "event:/");

		var lines = new Array<String>();
		lines.push("// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)");
		lines.push("");
		if (pkg != "") {
			lines.push('package $pkg;');
			lines.push("");
		}
		lines.push("enum FmodEventEnum {");
		for (name in names) lines.push('\t$name;');
		lines.push("}");
		lines.push("");
		lines.push("// Static extension: `using FmodEventEnum.FmodEventTools;` enables");
		lines.push("// FmodEventEnum.MusicMainLevel.path() and .guid()");
		lines.push("class FmodEventTools {");
		lines.push("\tpublic static inline function path(event:FmodEventEnum):String {");
		lines.push("\t\treturn switch (event) {");
		for (i in 0...matched.length) {
			lines.push('\t\t\tcase ${names[i]}: "${matched[i].path}";');
		}
		lines.push("\t\t};");
		lines.push("\t}");
		lines.push("");
		lines.push("\tpublic static inline function guid(event:FmodEventEnum):String {");
		lines.push("\t\treturn switch (event) {");
		for (i in 0...matched.length) {
			lines.push('\t\t\tcase ${names[i]}: "${matched[i].guid.toLowerCase()}";');
		}
		lines.push("\t\t};");
		lines.push("\t}");
		lines.push("}");
		lines.push("");
		return lines.join("\n");
	}

	static function emitClass(className:String, prefix:String, entries:Array<StringsBankEntry>, pkg:String):String {
		var lines = new Array<String>();
		// Keep in lockstep with fmod-scripts/ExportHaxeConstants.js (the
		// Studio-side generator must emit byte-identical files)
		lines.push("// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)");
		lines.push("");
		if (pkg != "") {
			lines.push('package $pkg;');
			lines.push("");
		}
		var names = identifiersFor(entries.map(e -> e.path), prefix);
		lines.push('class $className {');
		for (i in 0...entries.length) {
			lines.push('\tpublic static inline var ${names[i]}:String = "${entries[i].path}";');
		}
		lines.push("}");
		lines.push("");
		// GUIDs live in a companion class under the same identifiers, so
		// autocomplete on the main class only shows the paths
		lines.push('class ${className}Guids {');
		for (i in 0...entries.length) {
			lines.push('\tpublic static inline var ${names[i]}:String = "${entries[i].guid}";');
		}
		lines.push("}");
		lines.push("");
		return lines.join("\n");
	}

	/** Mangles one path into a Haxe identifier (see class doc for the rules). */
	public static function mangle(path:String, prefix:String):String {
		var rest = StringTools.startsWith(path, prefix) ? path.substr(prefix.length) : path;
		var out = new StringBuf();
		var startOfPiece = true;
		for (i in 0...rest.length) {
			var c = rest.charCodeAt(i);
			var isAlpha = (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
			var isDigit = c >= '0'.code && c <= '9'.code;
			if (isAlpha || isDigit) {
				var ch = rest.charAt(i);
				out.add(startOfPiece && isAlpha ? ch.toUpperCase() : ch);
				startOfPiece = false;
			} else {
				startOfPiece = true;
			}
		}
		var name = out.toString();
		if (name == "") return "Root";
		var first = name.charCodeAt(0);
		if (first >= '0'.code && first <= '9'.code) name = "_" + name;
		return name;
	}

	/** Assigns unique identifiers for a list of paths. Collisions get
		numeric suffixes. */
	public static function identifiersFor(paths:Array<String>, prefix:String):Array<String> {
		var used = new Map<String, Bool>();
		var out = new Array<String>();
		for (p in paths) {
			var base = mangle(p, prefix);
			var name = base;
			var n = 2;
			while (used.exists(name)) {
				name = base + n;
				n++;
			}
			used.set(name, true);
			out.push(name);
		}
		return out;
	}

	static function absolute(path:String, cwd:String):String {
		return haxe.io.Path.isAbsolute(path) ? path : haxe.io.Path.join([cwd, path]);
	}

	static function usageError(message:String) {
		Sys.println('generate: $message');
		Sys.println("Usage: haxelib run haxefmod generate [--strings <path>] [--out <dir>] [--package <pkg>] [--enums]");
		Sys.println("  --strings  Path to Master.strings.bank (default: assets/fmod/Desktop/Master.strings.bank)");
		Sys.println("  --out      Output directory (default: source/ if it exists, else the current directory)");
		Sys.println("  --package  Package for the generated classes (default: top-level)");
		Sys.println("  --enums    Also emit FmodEventEnum.hx (FmodEventEnum enum with a path() mapper)");
		Sys.exit(1);
	}
}
