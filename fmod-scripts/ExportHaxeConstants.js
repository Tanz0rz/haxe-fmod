/* -------------------------------------------
   FMOD Studio Script by Tanz0rz:
   Export Haxe constants and build banks

   Generates the same files as `haxelib run haxefmod generate`
   (FmodEvents.hx, FmodBuses.hx, FmodVCAs.hx, FmodSnapshots.hx,
   FmodParameters.hx) directly from the open FMOD Studio project, then
   builds the banks. Because it runs as part of the export itself, the
   constants can never drift from the project - this is the recommended
   workflow. The CLI generator produces byte-identical output from a built
   strings bank (a parity test in CI keeps the two in lockstep), so either
   tool can regenerate the files.

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

    // Mirrors Generate.emitClass byte for byte (LF line endings, tabs)
    emitClass: function (className, prefix, entries) {
        var lines = [];
        lines.push(this.header);
        lines.push("");
        var paths = [];
        for (var i = 0; i < entries.length; i++) paths.push(entries[i].path);
        var names = this.identifiersFor(paths, prefix);
        lines.push("class " + className + " {");
        for (var j = 0; j < entries.length; j++) {
            lines.push("\tpublic static inline var " + names[j] + ':String = "' + entries[j].path + '";');
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
    generateEventEnums: function (entries) {
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
            lines.push("\t\t\tcase " + names[e] + ': "' + matched[e].path + '";');
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
    // like the CLI generator
    generate: function (entries) {
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
            files[cat.className + ".hx"] = this.emitClass(cat.className, cat.prefix, matched);
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
        var outputPathDir = readOutputPathFromFile();
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
                        { widgetType: studio.ui.widgetType.PathLineEdit, stretchFactor: 1, widgetId: "m_directoryPicker", text: outputPathDir, pathType: studio.ui.pathType.Directory },
                        { widgetType: studio.ui.widgetType.PushButton, text: "Save", onClicked: function () { createConstantsFiles(this); this.closeDialog(); } }
                    ]
                }
            ]
        });
    }

    // Collects {path, guid} entries from the open project: the same set the
    // built strings bank will contain (events, snapshots, buses incl. the
    // master "bus:/", VCAs, and global parameters)
    function collectEntries() {
        var entries = [];
        var sources = [
            studio.project.model.Event.findInstances(),
            studio.project.model.Snapshot.findInstances(),
            studio.project.model.MixerGroup.findInstances(),
            studio.project.model.MixerReturn.findInstances(),
            studio.project.model.MixerMaster.findInstances(),
            studio.project.model.MixerVCA.findInstances(),
            studio.project.model.ParameterPreset.findInstances()
        ];
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

    function createConstantsFiles(directoryPickerWidget) {
        var outputPath = directoryPickerWidget.findWidget("m_directoryPicker").text();

        var entries = collectEntries();
        var files = HaxefmodConstants.generate(entries);
        var enumsText = HaxefmodConstants.generateEventEnums(entries);
        if (enumsText !== null) files["FmodEventEnum.hx"] = enumsText;
        var written = [];
        for (var fileName in files) {
            var fullPath = outputPath + "/" + fileName;
            var file = studio.system.getFile(fullPath);
            if (!file.open(studio.system.openMode.WriteOnly)) {
                alert("Failed to open constants file for writing: " + fullPath + "\n\nCheck the file is not read-only.");
                console.error("Failed to open constants file for writing: " + fullPath);
                return;
            }
            file.writeText(files[fileName]);
            file.close();
            written.push(fileName);
            console.log("Wrote " + fullPath);
        }

        saveOutputPathToFile(outputPath);

        console.log("Building banks...");
        studio.project.build();

        alert("Haxe constants written to:\n\n" + outputPath + "\n\nBanks built.");
    }

    function readOutputPathFromFile() {
        var location = studio.project.filePath.substr(0, studio.project.filePath.lastIndexOf("/") + 1) + cacheFileName;
        var file = studio.system.getFile(location);
        if (!file.open(studio.system.openMode.ReadOnly)) {
            return "";
        }
        var fileData = file.readText(10000);
        file.close();
        return fileData;
    }

    function saveOutputPathToFile(outputDir) {
        var location = studio.project.filePath.substr(0, studio.project.filePath.lastIndexOf("/") + 1) + cacheFileName;
        var file = studio.system.getFile(location);
        if (!file.open(studio.system.openMode.WriteOnly)) {
            alert("Failed to open file to cache the selected directory: " + location);
            console.error("Failed to open file to cache the selected directory: " + location);
            return;
        }
        file.writeText(outputDir);
        file.close();
    }
}
