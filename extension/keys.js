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
(function (root) {
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

    // Every unit on the page: {node, tabbed, added, key, kind, heading, index}
    function units(container) {
        var nodes = container.querySelectorAll("div.language-selector, div.highlight");
        var seen = {};
        var out = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            var tabbed = node.classList.contains("language-selector");
            // A selector this extension added counts as the unit it
            // replaced, so keys stay the same on every pass over the page
            var added = node.classList.contains("haxefmod-selector");
            if (!tabbed && (attachedToSelector(node) || node.classList.contains("language-haxe"))) continue;
            var fn = tabbed ? functionHeading(node) : null;
            var heading = fn ? fn.textContent.replace(/\s+/g, " ").trim() : nearestHeading(node);
            var key;
            var kind;
            if (fn) {
                key = fn.id;
                kind = "function";
            } else {
                var base = heading || "page";
                seen[base] = (seen[base] || 0) + 1;
                key = seen[base] > 1 ? base + "#" + seen[base] : base;
                kind = "example";
            }
            out.push({ node: node, tabbed: tabbed, added: added, key: key, kind: kind, heading: heading, index: out.length });
        }
        return out;
    }

    root.haxefmodKeys = { units: units, attachedToSelector: attachedToSelector, functionHeading: functionHeading };
})(typeof window !== "undefined" ? window : this);
