package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;

typedef TodoEntry = {
	file:String,
	line:Int,
	description:String
}

/**
 * Finds every FmodManager.Todo(...) call in a project so the sound work
 * they mark can be scheduled. Run from the project root:
 *
 *   haxelib run haxefmod todos [--json]
 *
 * The scanner is comment-aware and string-aware: commented-out calls and
 * mentions inside string literals are not reported. Only calls with a
 * literal first argument get their description shown. A computed
 * description is still found but reported as dynamic.
 */
class Todos {
	public static function main() {
		run(Sys.args(), Sys.getCwd());
	}

	public static function run(args:Array<String>, cwd:String) {
		var json = args.indexOf("--json") >= 0;
		var root = cwd;
		for (arg in args) {
			if (arg != "--json" && FileSystem.exists(arg) && FileSystem.isDirectory(arg)) root = arg;
		}
		var entries = scanDirectory(root);
		if (json) {
			Sys.println(haxe.Json.stringify(entries));
			return;
		}
		if (entries.length == 0) {
			Sys.println("No sound TODOs found.");
			return;
		}
		for (entry in entries) {
			Sys.println('${entry.file}:${entry.line}: ${entry.description}');
		}
		Sys.println("");
		Sys.println('${entries.length} sound TODO(s) remaining.');
	}

	/** Scans every .hx file under root, skipping build output and metadata directories. */
	public static function scanDirectory(root:String):Array<TodoEntry> {
		var entries:Array<TodoEntry> = [];
		scanInto(root, "", entries);
		entries.sort((a, b) -> a.file == b.file ? a.line - b.line : (a.file < b.file ? -1 : 1));
		return entries;
	}

	static var SKIP_DIRS = ["export", "bin", "obj", ".git", ".haxelib", ".haxefmod", "node_modules"];

	static function scanInto(dir:String, rel:String, entries:Array<TodoEntry>) {
		var names = try FileSystem.readDirectory(dir) catch (e:Dynamic) return;
		for (name in names) {
			var path = haxe.io.Path.join([dir, name]);
			var relPath = rel == "" ? name : '$rel/$name';
			if (FileSystem.isDirectory(path)) {
				if (SKIP_DIRS.indexOf(name) >= 0 || StringTools.startsWith(name, ".")) continue;
				scanInto(path, relPath, entries);
			} else if (StringTools.endsWith(name, ".hx")) {
				var content = try File.getContent(path) catch (e:Dynamic) continue;
				for (entry in scanContent(relPath, content)) entries.push(entry);
			}
		}
	}

	/** Finds FmodManager.Todo calls in one file's source. Exposed for tests. */
	public static function scanContent(file:String, content:String):Array<TodoEntry> {
		var entries:Array<TodoEntry> = [];
		var needle = "FmodManager.Todo";
		var i = 0;
		var line = 1;
		var len = content.length;
		while (i < len) {
			var c = content.charCodeAt(i);
			if (c == "\n".code) {
				line++;
				i++;
				continue;
			}
			// Line comment
			if (c == "/".code && i + 1 < len && content.charCodeAt(i + 1) == "/".code) {
				while (i < len && content.charCodeAt(i) != "\n".code) i++;
				continue;
			}
			// Block comment
			if (c == "/".code && i + 1 < len && content.charCodeAt(i + 1) == "*".code) {
				i += 2;
				while (i < len && !(content.charCodeAt(i) == "*".code && i + 1 < len && content.charCodeAt(i + 1) == "/".code)) {
					if (content.charCodeAt(i) == "\n".code) line++;
					i++;
				}
				i += 2;
				continue;
			}
			// String literal: skip it so quoted mentions of the call are not counted
			if (c == '"'.code || c == "'".code) {
				var skipped = skipString(content, i, line);
				i = skipped.pos;
				line = skipped.line;
				continue;
			}
			if (c == "F".code && content.substr(i, needle.length) == needle && !isIdentChar(i > 0 ? content.charCodeAt(i - 1) : 0)) {
				var callLine = line;
				var j = i + needle.length;
				var jLine = line;
				while (j < len && isSpace(content.charCodeAt(j))) {
					if (content.charCodeAt(j) == "\n".code) jLine++;
					j++;
				}
				if (j < len && content.charCodeAt(j) == "(".code) {
					j++;
					while (j < len && isSpace(content.charCodeAt(j))) {
						if (content.charCodeAt(j) == "\n".code) jLine++;
						j++;
					}
					var description = "(dynamic description)";
					if (j < len && (content.charCodeAt(j) == '"'.code || content.charCodeAt(j) == "'".code)) {
						var quote = content.charCodeAt(j);
						j++;
						var buf = new StringBuf();
						while (j < len) {
							var s = content.charCodeAt(j);
							if (s == "\\".code && j + 1 < len) {
								buf.addChar(content.charCodeAt(j + 1));
								j += 2;
								continue;
							}
							if (s == quote) {
								j++;
								break;
							}
							if (s == "\n".code) jLine++;
							buf.addChar(s);
							j++;
						}
						description = buf.toString();
					}
					entries.push({file: file, line: callLine, description: description});
					i = j;
					line = jLine;
					continue;
				}
			}
			i++;
		}
		return entries;
	}

	static function skipString(content:String, start:Int, line:Int):{pos:Int, line:Int} {
		var quote = content.charCodeAt(start);
		var i = start + 1;
		var len = content.length;
		while (i < len) {
			var c = content.charCodeAt(i);
			if (c == "\\".code) {
				i += 2;
				continue;
			}
			if (c == "\n".code) line++;
			if (c == quote) {
				i++;
				break;
			}
			i++;
		}
		return {pos: i, line: line};
	}

	static inline function isSpace(c:Int):Bool {
		return c == " ".code || c == "\t".code || c == "\n".code || c == "\r".code;
	}

	static inline function isIdentChar(c:Int):Bool {
		return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || (c >= "0".code && c <= "9".code) || c == "_".code || c == ".".code;
	}
}
