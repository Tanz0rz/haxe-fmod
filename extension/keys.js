// The key of every code location on an fmod.com docs page.
//
// The catalog (extension/catalog/<page>.md), the Haxe entries
// (extension/haxe/<page>.md), and the content script all identify a code
// block by the same key, computed here from the page's own structure:
//
//   function   the id of the h2[api="function"] the block belongs to,
//              e.g. studio_eventinstance_start
//   other      the text of the nearest heading above the block, with
//              "#2", "#3", ... appended for the second and later blocks
//              under the same heading, e.g. FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
//              or "10.2 Extracting PCM Data from a Sound#2"
//
// A unit is a language selector (with its highlight blocks) or a lone
// highlight block with no selector. Units are visited in document order.
//
// Some examples appear once per language as adjacent lone blocks that
// the site's selector shows one at a time. grouped() folds such a run
// into one unit (kept under the first block's key), so the Haxe side
// stores and renders one translation for it. The fold only applies to
// the language classes the site's selector actually toggles: a block in
// another language (java, objective-c) is always visible on the site
// and stays a unit of its own.
(function (root) {
    // The language classes the site's selector shows and hides.
    var SITE_LANGS = ["language-c", "language-cpp", "language-c-cpp", "language-csharp", "language-javascript"];

    function attachedToSelector(highlight) {
        var n = highlight.previousElementSibling;
        while (n && (n.classList.contains("highlight") || (n.tagName === "P" && n.textContent.trim() === ""))) n = n.previousElementSibling;
        return !!(n && n.classList.contains("language-selector"));
    }

    function functionHeading(unit) {
        var node = unit.previousElementSibling;
        for (var i = 0; node && i < 4; i++) {
            if (node.tagName === "H2" && node.getAttribute("api") === "function") return node;
            node = node.previousElementSibling;
        }
        return null;
    }

    function nearestHeading(unit) {
        var h = unit.previousElementSibling;
        while (h && !/^H[1-6]$/.test(h.tagName)) h = h.previousElementSibling;
        return h ? h.textContent.replace(/\s+/g, " ").trim() : "";
    }

    function siteLang(node) {
        for (var i = 0; i < SITE_LANGS.length; i++) {
            if (node.classList.contains(SITE_LANGS[i])) return SITE_LANGS[i];
        }
        return null;
    }

    // Every unit on the page: {node, tabbed, added, key, kind, heading, index}
    function units(container) {
        var nodes = container.querySelectorAll("div.language-selector, div.highlight");
        var seen = {};
        var out = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            var tabbed = node.classList.contains("language-selector");
            // A selector this extension added counts as the units it
            // replaced, so keys stay the same on every pass over the
            // page. One added for a per-language run stands for every
            // block of the run (data-haxefmod-count).
            var added = node.classList.contains("haxefmod-selector");
            if (!tabbed && (attachedToSelector(node) || node.classList.contains("language-haxe"))) continue;
            var fn = tabbed && !added ? functionHeading(node) : null;
            var heading = fn ? fn.textContent.replace(/\s+/g, " ").trim() : nearestHeading(node);
            var key;
            var kind;
            if (fn) {
                key = fn.id;
                kind = "function";
            } else {
                var base = heading || "page";
                var count = added ? parseInt(node.getAttribute("data-haxefmod-count") || "1", 10) : 1;
                var first = (seen[base] || 0) + 1;
                seen[base] = (seen[base] || 0) + count;
                key = first > 1 ? base + "#" + first : base;
                kind = "example";
            }
            out.push({ node: node, tabbed: tabbed, added: added, key: key, kind: kind, heading: heading, index: out.length });
        }
        return out;
    }

    // True when b follows a with nothing but empty paragraphs between.
    function adjacent(a, b) {
        var n = a.nextElementSibling;
        while (n && n !== b) {
            if (!(n.tagName === "P" && n.textContent.trim() === "")) return false;
            n = n.nextElementSibling;
        }
        return n === b;
    }

    // Folds runs of per-language variants into one unit each. The
    // blocks of a run sit right next to each other on the page, prose
    // between two blocks means two examples. Lone units come back with
    // members (their blocks in document order) and langs (the language
    // class of each member, empty for a block with none). Tabbed and
    // already-injected units pass through untouched.
    function grouped(units) {
        var out = [];
        var i = 0;
        while (i < units.length) {
            var unit = units[i];
            if (unit.tabbed || unit.added) {
                out.push(unit);
                i++;
                continue;
            }
            var lang = siteLang(unit.node);
            var members = [unit.node];
            var langs = lang ? [lang] : [];
            var j = i + 1;
            while (lang && j < units.length) {
                var next = units[j];
                if (next.tabbed || next.added || next.kind !== "example" || next.heading !== unit.heading) break;
                var nextLang = siteLang(next.node);
                if (!nextLang || langs.indexOf(nextLang) >= 0) break;
                if (!adjacent(members[members.length - 1], next.node)) break;
                members.push(next.node);
                langs.push(nextLang);
                j++;
            }
            out.push({ node: unit.node, tabbed: false, added: false, key: unit.key, kind: unit.kind, heading: unit.heading, index: unit.index, members: members, langs: langs });
            i = j;
        }
        return out;
    }

    root.haxefmodKeys = { units: units, grouped: grouped, attachedToSelector: attachedToSelector, functionHeading: functionHeading, siteLang: siteLang };
})(typeof window !== "undefined" ? window : this);
