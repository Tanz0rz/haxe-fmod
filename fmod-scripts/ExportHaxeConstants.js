/* -------------------------------------------
   FMOD Studio Script by Tanz0rz:
   Export Haxe constants and build banks

   Generates the same files as `haxelib run haxefmod generate`
   (FmodEvents.hx, FmodBuses.hx, FmodVCAs.hx, FmodSnapshots.hx,
   FmodParameters.hx, FmodEventEnum.hx) directly from the open FMOD Studio project, then
   builds the banks. Because it runs as part of the export itself, the
   constants can never drift from the project - this is the recommended
   workflow. The CLI generator produces byte-identical output from a built
   strings bank (a parity test in CI keeps the two in lockstep), so either
   tool can regenerate the files.

   The package field in the export dialog matches the CLI's --package
   flag. It emits the same package line and it defaults to empty.

   The generation core below must mirror haxefmod/tools/Generate.hx
   exactly: same categories, same identifier mangling, same collision
   suffixes, same header, same formatting.
   -------------------------------------------
 */

var HaxefmodConstants = {
    header: "// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)",

    categories: [
        { prefix: "event:/", className: "FmodEvents" },
        { prefix: "bus:/", className: "FmodBuses" },
        { prefix: "vca:/", className: "FmodVCAs" },
        { prefix: "snapshot:/", className: "FmodSnapshots" },
        { prefix: "parameter:/", className: "FmodParameters" }
    ],

    // Mirrors Generate.mangle: strip the prefix, keep letters and digits,
    // uppercase the first letter of every piece, "Root" for empty (bus:/),
    // underscore prefix for a leading digit
    mangle: function (path, prefix) {
        var rest = path.indexOf(prefix) === 0 ? path.substr(prefix.length) : path;
        var out = "";
        var startOfPiece = true;
        for (var i = 0; i < rest.length; i++) {
            var ch = rest.charAt(i);
            var isAlpha = (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z");
            var isDigit = ch >= "0" && ch <= "9";
            if (isAlpha || isDigit) {
                out += (startOfPiece && isAlpha) ? ch.toUpperCase() : ch;
                startOfPiece = false;
            } else {
                startOfPiece = true;
            }
        }
        if (out === "") return "Root";
        var first = out.charAt(0);
        if (first >= "0" && first <= "9") out = "_" + out;
        return out;
    },

    // Mirrors Generate.identifiersFor: numeric suffixes on collision
    identifiersFor: function (paths, prefix) {
        var used = {};
        var out = [];
        for (var i = 0; i < paths.length; i++) {
            var base = this.mangle(paths[i], prefix);
            var name = base;
            var n = 2;
            while (used[name] === true) {
                name = base + n;
                n++;
            }
            used[name] = true;
            out.push(name);
        }
        return out;
    },

    // Mirrors Generate.quoteHx: escapes a value for a generated
    // double-quoted Haxe string literal
    quoteHx: function (s) {
        return String(s).split("\\").join("\\\\").split('"').join('\\"');
    },

    // Mirrors Generate.emitClass byte for byte (LF line endings, tabs).
    // pkg is the Haxe package, "" for no package line.
    emitClass: function (className, prefix, entries, pkg) {
        var lines = [];
        lines.push(this.header);
        lines.push("");
        if (pkg) {
            lines.push("package " + pkg + ";");
            lines.push("");
        }
        var paths = [];
        for (var i = 0; i < entries.length; i++) paths.push(entries[i].path);
        var names = this.identifiersFor(paths, prefix);
        lines.push("class " + className + " {");
        for (var j = 0; j < entries.length; j++) {
            lines.push("\tpublic static inline var " + names[j] + ':String = "' + this.quoteHx(entries[j].path) + '";');
        }
        lines.push("}");
        lines.push("");
        // GUIDs go in a companion class so the main class autocompletes
        // to paths only
        lines.push("class " + className + "Guids {");
        for (var k = 0; k < entries.length; k++) {
            lines.push("\tpublic static inline var " + names[k] + ':String = "' + entries[k].guid + '";');
        }
        lines.push("}");
        lines.push("");
        return lines.join("\n");
    },

    // Mirrors Generate.emitEventEnums byte for byte: one FmodEventEnum enum
    // covering every event (values named exactly like the FmodEvents
    // constants) plus FmodEventTools.path()/guid() mappers. Returns null
    // when there are no events.
    generateEventEnums: function (entries, pkg) {
        var matched = [];
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].path.indexOf("event:/") === 0) {
                matched.push({ path: entries[i].path, guid: String(entries[i].guid).toLowerCase() });
            }
        }
        if (matched.length === 0) return null;
        matched.sort(function (a, b) {
            return a.path < b.path ? -1 : (a.path > b.path ? 1 : 0);
        });
        var paths = [];
        for (var j = 0; j < matched.length; j++) paths.push(matched[j].path);
        var names = this.identifiersFor(paths, "event:/");

        var lines = [];
        lines.push(this.header);
        lines.push("");
        if (pkg) {
            lines.push("package " + pkg + ";");
            lines.push("");
        }
        lines.push("enum FmodEventEnum {");
        for (var n = 0; n < names.length; n++) lines.push("\t" + names[n] + ";");
        lines.push("}");
        lines.push("");
        lines.push("// Static extension: `using FmodEventEnum.FmodEventTools;` enables");
        lines.push("// FmodEventEnum.MusicMainLevel.path() and .guid()");
        lines.push("class FmodEventTools {");
        lines.push("\tpublic static inline function path(event:FmodEventEnum):String {");
        lines.push("\t\treturn switch (event) {");
        for (var e = 0; e < matched.length; e++) {
            lines.push("\t\t\tcase " + names[e] + ': "' + this.quoteHx(matched[e].path) + '";');
        }
        lines.push("\t\t};");
        lines.push("\t}");
        lines.push("");
        lines.push("\tpublic static inline function guid(event:FmodEventEnum):String {");
        lines.push("\t\treturn switch (event) {");
        for (var g = 0; g < matched.length; g++) {
            lines.push("\t\t\tcase " + names[g] + ': "' + matched[g].guid + '";');
        }
        lines.push("\t\t};");
        lines.push("\t}");
        lines.push("}");
        lines.push("");
        return lines.join("\n");
    },

    // entries: [{path, guid}] in any order. Returns {"FmodEvents.hx": text, ...}
    // with entries sorted by path and GUIDs normalized to lowercase, exactly
    // like the CLI generator. pkg matches the CLI's --package flag and
    // defaults to no package line.
    generate: function (entries, pkg) {
        var files = {};
        for (var c = 0; c < this.categories.length; c++) {
            var cat = this.categories[c];
            var matched = [];
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].path.indexOf(cat.prefix) === 0) {
                    matched.push({ path: entries[i].path, guid: String(entries[i].guid).toLowerCase() });
                }
            }
            if (matched.length === 0) continue;
            matched.sort(function (a, b) {
                return a.path < b.path ? -1 : (a.path > b.path ? 1 : 0);
            });
            files[cat.className + ".hx"] = this.emitClass(cat.className, cat.prefix, matched, pkg);
        }
        return files;
    }
};

// Node export for the CI parity test (tests/js/constants-parity.js)
if (typeof module !== "undefined" && module.exports) {
    module.exports = HaxefmodConstants;
}

// Everything below only exists inside FMOD Studio
if (typeof studio !== "undefined") {

    studio.menu.addMenuItem({
        name: "Export Haxe Constants and Build",
        execute: function () { displayDirectoryPickerModal(); },
        keySequence: "Ctrl+B"
    });

    var cacheFileName = "CachedHaxeConstantsOutputLocation";

    function displayDirectoryPickerModal() {
        var cached = readCachedSettings();
        studio.ui.showModalDialog({
            windowTitle: "Select your Haxe project's source folder",
            windowWidth: 800,
            windowHeight: 0,
            widgetType: studio.ui.widgetType.Layout,
            layout: studio.ui.layoutType.VBoxLayout,
            items: [
                {
                    widgetType: studio.ui.widgetType.Layout,
                    layout: studio.ui.layoutType.HBoxLayout,
                    contentsMargins: { left: 0, top: 0, right: 0, bottom: 0 },
                    items: [
                        { widgetType: studio.ui.widgetType.Spacer, sizePolicy: { horizontalPolicy: studio.ui.sizePolicy.MinimumExpanding } },
                        { widgetType: studio.ui.widgetType.PathLineEdit, stretchFactor: 1, widgetId: "m_directoryPicker", text: cached.path, pathType: studio.ui.pathType.Directory }
                    ]
                },
                {
                    widgetType: studio.ui.widgetType.Layout,
                    layout: studio.ui.layoutType.HBoxLayout,
                    contentsMargins: { left: 0, top: 0, right: 0, bottom: 0 },
                    items: [
                        { widgetType: studio.ui.widgetType.Label, text: "Haxe package (optional, the CLI calls it --package):" },
                        { widgetType: studio.ui.widgetType.LineEdit, stretchFactor: 1, widgetId: "m_packageName", text: cached.pkg },
                        { widgetType: studio.ui.widgetType.PushButton, text: "Save", onClicked: function () { createConstantsFiles(this); this.closeDialog(); } }
                    ]
                }
            ]
        });
    }

    // Collects {path, guid} entries from the open project: the same set the
    // built strings bank will contain (events, snapshots, buses incl. the
    // master "bus:/", VCAs, and global parameters)
    var MODEL_CLASSES = ["Event", "Snapshot", "MixerGroup", "MixerReturn", "MixerMaster", "MixerVCA", "ParameterPreset"];

    // Another Studio version can drop or rename a model class. The lookup
    // that fails names itself in the log and the rest of the export runs.
    function findInstances(className) {
        try {
            return studio.project.model[className].findInstances();
        } catch (e) {
            console.error("studio.project.model." + className + ".findInstances() failed: " + e);
            return [];
        }
    }

    function collectEntries() {
        var entries = [];
        var sources = [];
        for (var m = 0; m < MODEL_CLASSES.length; m++) sources.push(findInstances(MODEL_CLASSES[m]));
        for (var s = 0; s < sources.length; s++) {
            var objects = sources[s];
            for (var i = 0; i < objects.length; i++) {
                var path;
                try {
                    path = objects[i].getPath();
                } catch (e) {
                    continue;
                }
                if (typeof path !== "string") continue;
                // Keep only the categories the constants cover (event-local
                // parameters and folders report other path shapes)
                for (var c = 0; c < HaxefmodConstants.categories.length; c++) {
                    if (path.indexOf(HaxefmodConstants.categories[c].prefix) === 0) {
                        entries.push({ path: path, guid: objects[i].id });
                        break;
                    }
                }
            }
        }
        return entries;
    }

    // Haxe reads a package from the folder structure, so the chosen
    // folder must end with the package's own folders. The CLI appends
    // them to --out for the same reason.
    var PACKAGE_NAME = /^[a-z_][a-zA-Z0-9_]*(\.[a-z_][a-zA-Z0-9_]*)*$/;

    function packageProblem(outputPath, pkg) {
        if (pkg === "") return null;
        if (!PACKAGE_NAME.test(pkg)) {
            return "\"" + pkg + "\" is not a valid Haxe package name.";
        }
        var parts = pkg.split(".");
        var dirs = outputPath.replace(/[\\/]+$/, "").split(/[\\/]/);
        for (var i = 0; i < parts.length; i++) {
            if (dirs[dirs.length - parts.length + i] !== parts[i]) {
                return "The output folder must end with " + parts.join("/") + " for the package " + pkg + ".";
            }
        }
        return null;
    }

    function createConstantsFiles(dialogWidget) {
        var outputPath = dialogWidget.findWidget("m_directoryPicker").text();
        var pkg = String(dialogWidget.findWidget("m_packageName").text()).replace(/^\s+|\s+$/g, "");

        if (outputPath.replace(/^\s+|\s+$/g, "") === "") {
            alert("Choose the folder to write the Haxe constants into.");
            console.error("No output folder was chosen");
            return;
        }

        var packageError = packageProblem(outputPath, pkg);
        if (packageError !== null) {
            alert(packageError);
            console.error(packageError);
            return;
        }

        var entries = collectEntries();
        var files = HaxefmodConstants.generate(entries, pkg);
        var enumsText = HaxefmodConstants.generateEventEnums(entries, pkg);
        if (enumsText !== null) files["FmodEventEnum.hx"] = enumsText;

        var names = [];
        for (var name in files) names.push(name);
        if (names.length === 0) {
            var empty = "No event:/, bus:/, vca:/, snapshot:/ or parameter:/ paths found - nothing to generate.";
            console.log(empty);
            console.log("Building banks...");
            studio.project.build();
            alert(empty + "\n\nBanks built.");
            return;
        }

        // The folder comes from the picker or from the cache of an
        // earlier run, and either one can point at a folder that is
        // gone. The first constants file is the probe.
        if (!openForWrite(outputPath + "/" + names[0])) {
            alert("Cannot write into:\n\n" + outputPath + "\n\nCheck the folder exists and is not read-only.");
            console.error("Cannot write into " + outputPath);
            return;
        }

        var written = [];
        for (var f = 0; f < names.length; f++) {
            var fileName = names[f];
            var fullPath = outputPath + "/" + fileName;
            var file = openForWrite(fullPath);
            if (file === null) {
                alert("Failed to open constants file for writing: " + fullPath + "\n\nCheck the file is not read-only.");
                console.error("Failed to open constants file for writing: " + fullPath);
                return;
            }
            file.writeText(files[fileName]);
            file.close();
            written.push(fileName);
            console.log("Wrote " + fullPath);
        }

        saveCachedSettings(outputPath, pkg);

        console.log("Building banks...");
        studio.project.build();

        alert("Haxe constants written to:\n\n" + outputPath + "\n\nBanks built.");
    }

    // The open file on success, null when the path cannot be written.
    function openForWrite(fullPath) {
        var file = studio.system.getFile(fullPath);
        return file.open(studio.system.openMode.WriteOnly) ? file : null;
    }

    function cacheLocation() {
        return studio.project.filePath.substr(0, studio.project.filePath.lastIndexOf("/") + 1) + cacheFileName;
    }

    // The cache holds the folder on the first line and the package on the
    // second. A file from an earlier run holds the folder alone.
    function readCachedSettings() {
        var file = studio.system.getFile(cacheLocation());
        if (!file.open(studio.system.openMode.ReadOnly)) {
            return { path: "", pkg: "" };
        }
        var fileData = file.readText(10000);
        file.close();
        var lines = String(fileData).split("\n");
        return { path: lines[0], pkg: lines.length > 1 ? lines[1] : "" };
    }

    function saveCachedSettings(outputDir, pkg) {
        var location = cacheLocation();
        var file = openForWrite(location);
        if (file === null) {
            alert("Failed to open file to cache the selected directory: " + location);
            console.error("Failed to open file to cache the selected directory: " + location);
            return;
        }
        file.writeText(pkg === "" ? outputDir : outputDir + "\n" + pkg);
        file.close();
    }
}
