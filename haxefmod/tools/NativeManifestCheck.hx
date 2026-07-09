package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/**
 * Verifies that the three native shims stay in lockstep with the FFI manifest.
 *
 * The manifest (native/manifest/studio_api.txt) is the source of truth for the
 * native surface. This checker scans:
 *   native/faxe/linc_faxe.cpp   for fmod_<name>(...) definitions
 *   native/hlaxe/hlaxe_fmod.c   for DEFINE_PRIM(<ret>, <name>, <args>) registrations
 *   native/jaxe/jaxe.js         for static fmod_<name>(...) methods
 * and reports any function that is missing, unexpected, or has mismatched arity.
 *
 * Exact FFI types legitimately differ per backend (e.g. float vs double), so
 * only presence and arity are verified.
 *
 * Entry points:
 *   haxelib run haxefmod verify-native   (via Run.hx)
 *   haxe -cp . --run haxefmod.tools.NativeManifestCheck   (from the repo root, used in CI)
 */
class NativeManifestCheck {
    public static function main() {
        Sys.exit(run(Sys.getCwd()));
    }

    public static function run(libRoot:String):Int {
        var manifestPath = Path.join([libRoot, "native", "manifest", "studio_api.txt"]);
        var cppPath = Path.join([libRoot, "native", "faxe", "linc_faxe.cpp"]);
        var hlPath = Path.join([libRoot, "native", "hlaxe", "hlaxe_fmod.c"]);
        var jsPath = Path.join([libRoot, "native", "jaxe", "jaxe.js"]);

        for (path in [manifestPath, cppPath, hlPath, jsPath]) {
            if (!FileSystem.exists(path)) {
                Sys.println('verify-native: file not found: $path');
                return 1;
            }
        }

        var manifest = parseManifest(manifestPath);
        var errors:Array<String> = [];

        diff("cpp (linc_faxe.cpp)", scanCpp(cppPath), manifest, errors);
        diff("hl (hlaxe_fmod.c)", scanHl(hlPath), manifest, errors);
        diff("js (jaxe.js)", scanJs(jsPath), manifest, errors);
        checkAbiLockstep(libRoot, manifestPath, errors);

        var total = 0;
        for (_ in manifest.keys()) total++;

        if (errors.length == 0) {
            Sys.println('verify-native: OK ($total functions in lockstep across cpp, hl, js)');
            return 0;
        }

        Sys.println('verify-native: FAILED (${errors.length} problem(s)):');
        for (error in errors) {
            Sys.println('  $error');
        }
        Sys.println("");
        Sys.println("The manifest (native/manifest/studio_api.txt) is the source of truth.");
        Sys.println("Every native function must exist with matching arity in all three shims.");
        return 1;
    }

    /** Manifest line format: <name> <argtype> <argtype> ... -> <rettype> */
    static function parseManifest(path:String):Map<String, Int> {
        var entries = new Map<String, Int>();
        for (line in File.getContent(path).split("\n")) {
            var trimmed = StringTools.trim(line);
            if (trimmed == "" || StringTools.startsWith(trimmed, "#")) continue;
            var arrowIdx = trimmed.indexOf("->");
            if (arrowIdx == -1) continue;
            var left = StringTools.trim(trimmed.substr(0, arrowIdx));
            var tokens = splitTokens(left);
            if (tokens.length == 0) continue;
            entries.set(tokens[0], tokens.length - 1);
        }
        return entries;
    }

    /** Matches single-line C++ definitions like: int fmod_load_bank(const ::String& path) { */
    static function scanCpp(path:String):Map<String, Int> {
        var found = new Map<String, Int>();
        var re = ~/^\s*[A-Za-z_][\w:&<>\* ]*\bfmod_(\w+)\s*\(([^)]*)\)\s*\{/;
        for (line in File.getContent(path).split("\n")) {
            if (re.match(line)) {
                found.set(re.matched(1), countCArgs(re.matched(2)));
            }
        }
        return found;
    }

    /** Matches: DEFINE_PRIM(_I32, create_instance, _BYTES); */
    static function scanHl(path:String):Map<String, Int> {
        var found = new Map<String, Int>();
        var re = ~/DEFINE_PRIM\s*\(\s*_\w+\s*,\s*(\w+)\s*,\s*([^)]*)\)/;
        for (line in File.getContent(path).split("\n")) {
            if (re.match(line)) {
                var args = StringTools.trim(re.matched(2));
                var arity = (args == "" || args == "_NO_ARG") ? 0 : splitTokens(args).length;
                found.set(re.matched(1), arity);
            }
        }
        return found;
    }

    /** Matches: static fmod_get_param(handle, name) { */
    static function scanJs(path:String):Map<String, Int> {
        var found = new Map<String, Int>();
        var re = ~/static\s+fmod_(\w+)\s*\(([^)]*)\)/;
        for (line in File.getContent(path).split("\n")) {
            if (re.match(line)) {
                found.set(re.matched(1), countCArgs(re.matched(2)));
            }
        }
        return found;
    }

    static function countCArgs(argStr:String):Int {
        var trimmed = StringTools.trim(argStr);
        if (trimmed == "" || trimmed == "void") return 0;
        return trimmed.split(",").length;
    }

    static function splitTokens(text:String):Array<String> {
        var tokens:Array<String> = [];
        for (token in ~/\s+/g.split(text)) {
            if (token != "") tokens.push(token);
        }
        return tokens;
    }

    /**
     * The binding ABI version is declared in four places that must agree:
     * the manifest header, the hl marker string (scanned from hdll binaries
     * by PostBuild), and the constants in the cpp/js shims and FmodRuntime.
     */
    static function checkAbiLockstep(libRoot:String, manifestPath:String, errors:Array<String>) {
        var expected = -1;
        for (line in File.getContent(manifestPath).split("\n")) {
            var trimmed = StringTools.trim(line);
            if (StringTools.startsWith(trimmed, "# abi-version:")) {
                expected = Std.parseInt(StringTools.trim(trimmed.substr("# abi-version:".length)));
                break;
            }
        }
        if (expected == null || expected <= 0) {
            errors.push('manifest: missing or invalid "# abi-version:" header');
            return;
        }

        var checks = [
            {
                label: "hl marker (hlaxe_fmod.c)",
                path: Path.join([libRoot, "native", "hlaxe", "hlaxe_fmod.c"]),
                pattern: ~/hlaxe_fmod_abi=(\d+)/,
            },
            {
                label: "cpp constant (linc_faxe.cpp)",
                path: Path.join([libRoot, "native", "faxe", "linc_faxe.cpp"]),
                pattern: ~/fmod_binding_abi_version\(\)\s*\{[^}]*return\s+(\d+)/,
            },
            {
                label: "js constant (jaxe.js)",
                path: Path.join([libRoot, "native", "jaxe", "jaxe.js"]),
                pattern: ~/fmod_binding_abi_version\(\)\s*\{[^}]*return\s+(\d+)/,
            },
            {
                label: "runtime constant (FmodRuntime.hx)",
                path: Path.join([libRoot, "haxefmod", "runtime", "FmodRuntime.hx"]),
                pattern: ~/BINDING_ABI:Int\s*=\s*(\d+)/,
            },
        ];
        for (check in checks) {
            if (!FileSystem.exists(check.path)) {
                errors.push('abi: file not found: ${check.path}');
                continue;
            }
            var content = File.getContent(check.path);
            if (!check.pattern.match(content)) {
                errors.push('abi: ${check.label} declares no version');
            } else if (Std.parseInt(check.pattern.matched(1)) != expected) {
                errors.push('abi: ${check.label} is ${check.pattern.matched(1)}, manifest says $expected');
            }
        }
    }

    static function diff(backend:String, found:Map<String, Int>, manifest:Map<String, Int>, errors:Array<String>) {
        for (name in manifest.keys()) {
            if (!found.exists(name)) {
                errors.push('$backend: missing "$name"');
            } else if (found.get(name) != manifest.get(name)) {
                errors.push('$backend: arity mismatch for "$name" (manifest ${manifest.get(name)}, found ${found.get(name)})');
            }
        }
        for (name in found.keys()) {
            if (!manifest.exists(name)) {
                errors.push('$backend: "$name" is not in the manifest');
            }
        }
    }
}
