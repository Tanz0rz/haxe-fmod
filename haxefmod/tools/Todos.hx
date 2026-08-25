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
		var root = resolveRoot(args, cwd);
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

	/**
	 * Resolves the scan root from the arguments. A relative directory is
	 * the caller's: under haxelib run the process cwd is the library root,
	 * so resolving against it would scan the wrong tree (or silently fall
	 * back when the name does not exist there). Exposed for tests.
	 */
	public static function resolveRoot(args:Array<String>, cwd:String):String {
		for (arg in args) {
			if (arg == "--json") continue;
			var candidate = haxe.io.Path.isAbsolute(arg) ? arg : haxe.io.Path.join([cwd, arg]);
			if (FileSystem.exists(candidate) && FileSystem.isDirectory(candidate)) return candidate;
		}
		return cwd;
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
			// Regex literal: a quote inside it would desync the string
			// skipper and swallow real calls up to the next quote
			if (c == "~".code && i + 1 < len && content.charCodeAt(i + 1) == "/".code) {
				var skipped = skipRegex(content, i, line);
				i = skipped.pos;
				line = skipped.line;
				continue;
			}
			if (c == "F".code && content.substr(i, needle.length) == needle && callPrefixOk(content, i)) {
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

	// The call must not be a member access on some other value. A bare call
	// and the package-qualified haxefmod.FmodManager.Todo both count; any
	// other dotted or identifier prefix is a lookalike.
	static function callPrefixOk(content:String, i:Int):Bool {
		if (i == 0) return true;
		var prev = content.charCodeAt(i - 1);
		if (!isIdentChar(prev)) return true;
		if (prev != ".".code) return false;
		var pkg = "haxefmod";
		var start = i - 1 - pkg.length;
		if (start < 0 || content.substr(start, pkg.length) != pkg) return false;
		return start == 0 || !isIdentChar(content.charCodeAt(start - 1));
	}

	static function skipRegex(content:String, start:Int, line:Int):{pos:Int, line:Int} {
		var i = start + 2;
		var len = content.length;
		while (i < len) {
			var c = content.charCodeAt(i);
			if (c == "\\".code) {
				i += 2;
				continue;
			}
			if (c == "\n".code) line++;
			if (c == "/".code) {
				i++;
				// trailing flags (g, i, m, s, u)
				while (i < len && isIdentChar(content.charCodeAt(i))) i++;
				break;
			}
			i++;
		}
		return {pos: i, line: line};
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
