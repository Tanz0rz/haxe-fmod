// ==UserScript==
// @name         haxefmod for FMOD docs
// @namespace    https://github.com/Tanz0rz/haxe-fmod
// @version      3.0.0
// @description  Adds a Haxe tab to the FMOD API reference showing the haxefmod method for every function.
// @match        https://www.fmod.com/docs/*
// @match        https://fmod.com/docs/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

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

// Generated by ci/haxe-bindings.py from the native shim and the
// Haxe wrappers. Do not edit by hand.
const HAXEFMOD_BINDINGS = {
 "entries": {
  "channel_adddsp": {
   "fmod": "FMOD_Channel_AddDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Inserts an effect on this channel (0 = head of the chain).",
     "gated": false,
     "name": "addDsp",
     "signature": "addDsp(index:Int, dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_addfadepoint": {
   "fmod": "FMOD_Channel_AddFadePoint",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Schedules a volume point at a parent-clock time.",
     "gated": false,
     "name": "addFadePoint",
     "signature": "addFadePoint(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dattributes": {
   "fmod": "FMOD_Channel_Get3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DAttributes",
     "signature": "get3DAttributes():Null<FmodChannel3DAttributes>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dconeorientation": {
   "fmod": "FMOD_Channel_Get3DConeOrientation",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeOrientation",
     "signature": "get3DConeOrientation():Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dconesettings": {
   "fmod": "FMOD_Channel_Get3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeSettings",
     "signature": "get3DConeSettings():Null<FmodConeSettings>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dcustomrolloff": {
   "fmod": "FMOD_Channel_Get3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The custom rolloff points (unsupported in HTML5, always empty there), empty when none are set or on failure (see StudioSystem.lastResult).",
     "gated": true,
     "name": "get3DCustomRolloff",
     "signature": "get3DCustomRolloff():Array<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channel_get3ddistancefilter": {
   "fmod": "FMOD_Channel_Get3DDistanceFilter",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDistanceFilter",
     "signature": "get3DDistanceFilter():Null<FmodDistanceFilter>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3ddopplerlevel": {
   "fmod": "FMOD_Channel_Get3DDopplerLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDopplerLevel",
     "signature": "get3DDopplerLevel():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dlevel": {
   "fmod": "FMOD_Channel_Get3DLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DLevel",
     "signature": "get3DLevel():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dminmaxdistance": {
   "fmod": "FMOD_Channel_Get3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DMinMaxDistance",
     "signature": "get3DMinMaxDistance():Null<FmodMinMaxDistance>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3docclusion": {
   "fmod": "FMOD_Channel_Get3DOcclusion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DOcclusion",
     "signature": "get3DOcclusion():Null<FmodOcclusion>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_get3dspread": {
   "fmod": "FMOD_Channel_Get3DSpread",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DSpread",
     "signature": "get3DSpread():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getaudibility": {
   "fmod": "FMOD_Channel_GetAudibility",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The final audible volume after group, 3D, and occlusion scaling.",
     "gated": false,
     "name": "getAudibility",
     "signature": "getAudibility():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getchannelgroup": {
   "fmod": "FMOD_Channel_GetChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group this channel is routed into (a known group returns its existing handle).",
     "gated": false,
     "name": "getChannelGroup",
     "signature": "getChannelGroup():ChannelGroup",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getcurrentsound": {
   "fmod": "FMOD_Channel_GetCurrentSound",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The sound this channel plays (a borrowed reference: never release it).",
     "gated": false,
     "name": "getCurrentSound",
     "signature": "getCurrentSound():haxefmod.core.Sound",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getdelay": {
   "fmod": "FMOD_Channel_GetDelay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getDelay",
     "signature": "getDelay():Null<FmodDelay>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getdsp": {
   "fmod": "FMOD_Channel_GetDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The effect at chain position index (a known DSP returns its existing handle).",
     "gated": false,
     "name": "getDsp",
     "signature": "getDsp(index:Int):Dsp",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getdspclock": {
   "fmod": "FMOD_Channel_GetDSPClock",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The channel's mixer clock in output samples, or null on failure.",
     "gated": false,
     "name": "getDspClock",
     "signature": "getDspClock():Null<FmodDspClock>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getdspindex": {
   "fmod": "FMOD_Channel_GetDSPIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The chain position of an attached effect, -1 when it is not attached or on failure.",
     "gated": false,
     "name": "getDspIndex",
     "signature": "getDspIndex(dsp:Dsp):Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getfadepoints": {
   "fmod": "FMOD_Channel_GetFadePoints",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The scheduled fade points as parent-clock and volume pairs (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getFadePoints",
     "signature": "getFadePoints():Null<Array<FmodFadePoint>>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channel_getfrequency": {
   "fmod": "FMOD_Channel_GetFrequency",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback rate in samples per second (resampling: also shifts pitch).",
     "gated": false,
     "name": "getFrequency",
     "signature": "getFrequency():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getindex": {
   "fmod": "FMOD_Channel_GetIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The channel's index inside FMOD's channel pool, or -1 on failure.",
     "gated": false,
     "name": "getIndex",
     "signature": "getIndex():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getloopcount": {
   "fmod": "FMOD_Channel_GetLoopCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getLoopCount",
     "signature": "getLoopCount():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getlooppoints": {
   "fmod": "FMOD_Channel_GetLoopPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The loop region, loopStart in loopStartType and loopEnd in loopEndType (milliseconds when left out, a missing loopEndType follows loopStartType), or null on failure.",
     "gated": false,
     "name": "getLoopPoints",
     "signature": "getLoopPoints(loopStartType:FmodTimeUnit = FmodTimeUnit.MS, ?loopEndType:FmodTimeUnit):Null<{loopStart:Int, loopEnd:Int}>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getlowpassgain": {
   "fmod": "FMOD_Channel_GetLowPassGain",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getLowPassGain",
     "signature": "getLowPassGain():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getmixmatrix": {
   "fmod": "FMOD_Channel_GetMixMatrix",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Reads the mix matrix back as one flat row-major array with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMixMatrix",
     "signature": "getMixMatrix(outChannels:Int = 0, inChannels:Int = 0, inChannelHop:Int = 0):Null<FmodMixMatrix>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channel_getmode": {
   "fmod": "FMOD_Channel_GetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMode",
     "signature": "getMode():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getmute": {
   "fmod": "FMOD_Channel_GetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMute",
     "signature": "getMute():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getnumdsps": {
   "fmod": "FMOD_Channel_GetNumDSPs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getDspCount under FMOD's name.",
     "gated": false,
     "name": "getNumDSPs",
     "signature": "getNumDSPs():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getDspCount",
     "signature": "getDspCount():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getpaused": {
   "fmod": "FMOD_Channel_GetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getpitch": {
   "fmod": "FMOD_Channel_GetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The pitch multiplier (1.0 = as recorded, 2.0 = one octave up).",
     "gated": false,
     "name": "getPitch",
     "signature": "getPitch():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getposition": {
   "fmod": "FMOD_Channel_GetPosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback position in unit (milliseconds by default, samples with FmodTimeUnit.PCM), or -1 on failure.",
     "gated": false,
     "name": "getPosition",
     "signature": "getPosition(unit:FmodTimeUnit = FmodTimeUnit.MS):Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getpriority": {
   "fmod": "FMOD_Channel_GetPriority",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPriority",
     "signature": "getPriority():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getreverbproperties": {
   "fmod": "FMOD_Channel_GetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The wet level of a reverb send, the same read as getReverbWet under FMOD's name.",
     "gated": false,
     "name": "getReverbProperties",
     "signature": "getReverbProperties(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getReverbWet",
     "signature": "getReverbWet(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getuserdata": {
   "fmod": "FMOD_Channel_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getvolume": {
   "fmod": "FMOD_Channel_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The volume as set by the API (linear: 0.0 = silent, 1.0 = full).",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_getvolumeramp": {
   "fmod": "FMOD_Channel_GetVolumeRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolumeRamp",
     "signature": "getVolumeRamp():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_isplaying": {
   "fmod": "FMOD_Channel_IsPlaying",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isPlaying",
     "signature": "isPlaying():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_isvirtual": {
   "fmod": "FMOD_Channel_IsVirtual",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True when FMOD virtualized the channel (inaudible, position still tracked).",
     "gated": false,
     "name": "isVirtual",
     "signature": "isVirtual():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_removedsp": {
   "fmod": "FMOD_Channel_RemoveDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeDsp",
     "signature": "removeDsp(dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_removefadepoints": {
   "fmod": "FMOD_Channel_RemoveFadePoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeFadePoints",
     "signature": "removeFadePoints(startClock:Float, endClock:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dattributes": {
   "fmod": "FMOD_Channel_Set3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Positions the channel in 3D space.",
     "gated": false,
     "name": "set3DAttributes",
     "signature": "set3DAttributes(posX:Float, posY:Float, posZ:Float, velX:Float = 0, velY:Float = 0, velZ:Float = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dconeorientation": {
   "fmod": "FMOD_Channel_Set3DConeOrientation",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DConeOrientation",
     "signature": "set3DConeOrientation(x:Float, y:Float, z:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dconesettings": {
   "fmod": "FMOD_Channel_Set3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Directional sound: full volume inside the cone, outsideVolume behind it.",
     "gated": false,
     "name": "set3DConeSettings",
     "signature": "set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dcustomrolloff": {
   "fmod": "FMOD_Channel_Set3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Replaces the distance rolloff curve with the given points.",
     "gated": true,
     "name": "set3DCustomRolloff",
     "signature": "set3DCustomRolloff(points:Array<FmodVector>):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channel_set3ddistancefilter": {
   "fmod": "FMOD_Channel_Set3DDistanceFilter",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Overrides the distance lowpass on this 3D channel.",
     "gated": false,
     "name": "set3DDistanceFilter",
     "signature": "set3DDistanceFilter(custom:Bool, customLevel:Float, centerFreq:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3ddopplerlevel": {
   "fmod": "FMOD_Channel_Set3DDopplerLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DDopplerLevel",
     "signature": "set3DDopplerLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dlevel": {
   "fmod": "FMOD_Channel_Set3DLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Blend between 2D and full 3D positioning (0.0 = 2D, 1.0 = 3D).",
     "gated": false,
     "name": "set3DLevel",
     "signature": "set3DLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dminmaxdistance": {
   "fmod": "FMOD_Channel_Set3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Distances where attenuation starts and stops (3D sounds).",
     "gated": false,
     "name": "set3DMinMaxDistance",
     "signature": "set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3docclusion": {
   "fmod": "FMOD_Channel_Set3DOcclusion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Muffles the channel as if behind an obstacle (0.0 = clear, 1.0 = fully blocked).",
     "gated": false,
     "name": "set3DOcclusion",
     "signature": "set3DOcclusion(direct:Float, reverb:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_set3dspread": {
   "fmod": "FMOD_Channel_Set3DSpread",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Speaker spread of a 3D sound in degrees (0 = point source).",
     "gated": false,
     "name": "set3DSpread",
     "signature": "set3DSpread(angle:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setcallback": {
   "fmod": "FMOD_Channel_SetCallback",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Delivers ChannelEvent values for this channel (drained once per frame with the other callbacks): End, SyncPoint, VirtualVoice, and Occlusion.",
     "name": "setCallback",
     "signature": "setCallback(handler:haxefmod.core.ChannelEvent.ChannelCallback):Void",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "",
     "name": "clearCallback",
     "signature": "clearCallback():Void",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setchannelgroup": {
   "fmod": "FMOD_Channel_SetChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Reroutes this channel into a group.",
     "gated": false,
     "name": "setChannelGroup",
     "signature": "setChannelGroup(group:ChannelGroup):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setdelay": {
   "fmod": "FMOD_Channel_SetDelay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sample-accurate start/stop window on the parent clock (0 = no bound).",
     "gated": false,
     "name": "setDelay",
     "signature": "setDelay(startClock:Float, endClock:Float, stopChannels:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setdspindex": {
   "fmod": "FMOD_Channel_SetDSPIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves an attached effect to another chain position (0 = head).",
     "gated": false,
     "name": "setDspIndex",
     "signature": "setDspIndex(dsp:Dsp, index:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setfadepointramp": {
   "fmod": "FMOD_Channel_SetFadePointRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A click-free ramp from the current volume to volume, ending at clock.",
     "gated": false,
     "name": "setFadePointRamp",
     "signature": "setFadePointRamp(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setfrequency": {
   "fmod": "FMOD_Channel_SetFrequency",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setFrequency",
     "signature": "setFrequency(frequency:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setloopcount": {
   "fmod": "FMOD_Channel_SetLoopCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Times to loop before stopping (-1 = forever, 0 = play once).",
     "gated": false,
     "name": "setLoopCount",
     "signature": "setLoopCount(loopCount:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setlooppoints": {
   "fmod": "FMOD_Channel_SetLoopPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loop region for this channel (overrides the sound's).",
     "gated": false,
     "name": "setLoopPoints",
     "signature": "setLoopPoints(loopStart:Int, loopEnd:Int, loopStartType:FmodTimeUnit = FmodTimeUnit.MS, ?loopEndType:FmodTimeUnit):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setlowpassgain": {
   "fmod": "FMOD_Channel_SetLowPassGain",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A built-in lowpass on the channel (1.0 = open, 0.0 = fully closed).",
     "gated": false,
     "name": "setLowPassGain",
     "signature": "setLowPassGain(gain:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setmixlevelsinput": {
   "fmod": "FMOD_Channel_SetMixLevelsInput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the gain of each incoming signal channel before the mix matrix, one level per input channel (1 to 32, an empty list is rejected with FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "setMixLevelsInput",
     "signature": "setMixLevelsInput(levels:Array<Float>):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setmixlevelsoutput": {
   "fmod": "FMOD_Channel_SetMixLevelsOutput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the gain of each output speaker directly, which replaces the mix matrix with a standard speaker layout.",
     "gated": false,
     "name": "setMixLevelsOutput",
     "signature": "setMixLevelsOutput(frontLeft:Float, frontRight:Float, center:Float, lowFrequency:Float, surroundLeft:Float, surroundRight:Float, backLeft:Float, backRight:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setmixmatrix": {
   "fmod": "FMOD_Channel_SetMixMatrix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes input channels to output speakers with explicit gains.",
     "gated": false,
     "name": "setMixMatrix",
     "signature": "setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setmode": {
   "fmod": "FMOD_Channel_SetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Combines ChannelMode flags (looping, 2D/3D, rolloff shape).",
     "gated": false,
     "name": "setMode",
     "signature": "setMode(mode:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setmute": {
   "fmod": "FMOD_Channel_SetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setMute",
     "signature": "setMute(mute:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setpan": {
   "fmod": "FMOD_Channel_SetPan",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Constant-power stereo pan (-1.0 = full left, 0 = center, 1.0 = full right).",
     "gated": false,
     "name": "setPan",
     "signature": "setPan(pan:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setpaused": {
   "fmod": "FMOD_Channel_SetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setpitch": {
   "fmod": "FMOD_Channel_SetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPitch",
     "signature": "setPitch(pitch:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setposition": {
   "fmod": "FMOD_Channel_SetPosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Seeks to a position read in unit, milliseconds unless another FmodTimeUnit is given.",
     "gated": false,
     "name": "setPosition",
     "signature": "setPosition(positionMs:Int, unit:FmodTimeUnit = FmodTimeUnit.MS):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setpriority": {
   "fmod": "FMOD_Channel_SetPriority",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Voice priority for virtualization (0 = most important, 256 = least).",
     "gated": false,
     "name": "setPriority",
     "signature": "setPriority(priority:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setreverbproperties": {
   "fmod": "FMOD_Channel_SetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same reverb send as setReverbWet under FMOD's name (ChannelControl::setReverbProperties).",
     "gated": false,
     "name": "setReverbProperties",
     "signature": "setReverbProperties(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "How much this channel feeds a reverb instance (0.0 = none, 1.0 = full).",
     "gated": false,
     "name": "setReverbWet",
     "signature": "setReverbWet(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setuserdata": {
   "fmod": "FMOD_Channel_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setvolume": {
   "fmod": "FMOD_Channel_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_setvolumeramp": {
   "fmod": "FMOD_Channel_SetVolumeRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Short volume ramping on changes (on by default, prevents clicks).",
     "gated": false,
     "name": "setVolumeRamp",
     "signature": "setVolumeRamp(ramp:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channel_stop": {
   "fmod": "FMOD_Channel_Stop",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops playback, removes any callback handler, and invalidates this handle.",
     "gated": false,
     "name": "stop",
     "signature": "stop():FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_adddsp": {
   "fmod": "FMOD_ChannelGroup_AddDSP, FMOD_Channel_AddDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Inserts an effect at index (0 = head of the chain, or a DSP_* position).",
     "gated": false,
     "name": "addDsp",
     "signature": "addDsp(index:Int, dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Inserts an effect on this channel (0 = head of the chain).",
     "gated": false,
     "name": "addDsp",
     "signature": "addDsp(index:Int, dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_addfadepoint": {
   "fmod": "FMOD_ChannelGroup_AddFadePoint, FMOD_Channel_AddFadePoint",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Schedules a volume point at a parent-clock time.",
     "gated": false,
     "name": "addFadePoint",
     "signature": "addFadePoint(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Schedules a volume point at a parent-clock time.",
     "gated": false,
     "name": "addFadePoint",
     "signature": "addFadePoint(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_addgroup": {
   "fmod": "FMOD_ChannelGroup_AddGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes a child group's output through this one (group hierarchies).",
     "gated": false,
     "name": "addGroup",
     "signature": "addGroup(child:ChannelGroup, propagateDspClock:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "Routes a child group's output through this one and returns the connection between the two, DspConnection.NULL on failure with the reason in StudioSystem.lastResult().",
     "gated": false,
     "name": "addGroupConnection",
     "signature": "addGroupConnection(child:ChannelGroup, propagateDspClock:Bool = true):DspConnection",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dattributes": {
   "fmod": "FMOD_ChannelGroup_Get3DAttributes, FMOD_Channel_Get3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DAttributes",
     "signature": "get3DAttributes():Null<FmodChannel3DAttributes>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DAttributes",
     "signature": "get3DAttributes():Null<FmodChannel3DAttributes>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dconeorientation": {
   "fmod": "FMOD_ChannelGroup_Get3DConeOrientation, FMOD_Channel_Get3DConeOrientation",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeOrientation",
     "signature": "get3DConeOrientation():Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeOrientation",
     "signature": "get3DConeOrientation():Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dconesettings": {
   "fmod": "FMOD_ChannelGroup_Get3DConeSettings, FMOD_Channel_Get3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeSettings",
     "signature": "get3DConeSettings():Null<FmodConeSettings>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeSettings",
     "signature": "get3DConeSettings():Null<FmodConeSettings>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dcustomrolloff": {
   "fmod": "FMOD_ChannelGroup_Get3DCustomRolloff, FMOD_Channel_Get3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The custom rolloff points (unsupported in HTML5, always empty there), empty when none are set or on failure (see StudioSystem.lastResult).",
     "gated": true,
     "name": "get3DCustomRolloff",
     "signature": "get3DCustomRolloff():Array<FmodVector>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The custom rolloff points (unsupported in HTML5, always empty there), empty when none are set or on failure (see StudioSystem.lastResult).",
     "gated": true,
     "name": "get3DCustomRolloff",
     "signature": "get3DCustomRolloff():Array<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channelcontrol_get3ddistancefilter": {
   "fmod": "FMOD_ChannelGroup_Get3DDistanceFilter, FMOD_Channel_Get3DDistanceFilter",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDistanceFilter",
     "signature": "get3DDistanceFilter():Null<FmodDistanceFilter>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDistanceFilter",
     "signature": "get3DDistanceFilter():Null<FmodDistanceFilter>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3ddopplerlevel": {
   "fmod": "FMOD_ChannelGroup_Get3DDopplerLevel, FMOD_Channel_Get3DDopplerLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDopplerLevel",
     "signature": "get3DDopplerLevel():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDopplerLevel",
     "signature": "get3DDopplerLevel():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dlevel": {
   "fmod": "FMOD_ChannelGroup_Get3DLevel, FMOD_Channel_Get3DLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DLevel",
     "signature": "get3DLevel():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DLevel",
     "signature": "get3DLevel():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dminmaxdistance": {
   "fmod": "FMOD_ChannelGroup_Get3DMinMaxDistance, FMOD_Channel_Get3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DMinMaxDistance",
     "signature": "get3DMinMaxDistance():Null<FmodMinMaxDistance>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DMinMaxDistance",
     "signature": "get3DMinMaxDistance():Null<FmodMinMaxDistance>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3docclusion": {
   "fmod": "FMOD_ChannelGroup_Get3DOcclusion, FMOD_Channel_Get3DOcclusion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group's occlusion levels, null on failure.",
     "gated": false,
     "name": "get3DOcclusion",
     "signature": "get3DOcclusion():Null<FmodOcclusion>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DOcclusion",
     "signature": "get3DOcclusion():Null<FmodOcclusion>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_get3dspread": {
   "fmod": "FMOD_ChannelGroup_Get3DSpread, FMOD_Channel_Get3DSpread",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DSpread",
     "signature": "get3DSpread():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DSpread",
     "signature": "get3DSpread():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getaudibility": {
   "fmod": "FMOD_ChannelGroup_GetAudibility, FMOD_Channel_GetAudibility",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The final audible volume after parent groups and 3D scaling.",
     "gated": false,
     "name": "getAudibility",
     "signature": "getAudibility():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The final audible volume after group, 3D, and occlusion scaling.",
     "gated": false,
     "name": "getAudibility",
     "signature": "getAudibility():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getchannel": {
   "fmod": "FMOD_ChannelGroup_GetChannel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A channel routed into this group by index (known channels dedup).",
     "gated": false,
     "name": "getChannel",
     "signature": "getChannel(index:Int):Channel",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_getchannelgroup": {
   "fmod": "FMOD_Channel_GetChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group this channel is routed into (a known group returns its existing handle).",
     "gated": false,
     "name": "getChannelGroup",
     "signature": "getChannelGroup():ChannelGroup",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getcurrentsound": {
   "fmod": "FMOD_Channel_GetCurrentSound",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The sound this channel plays (a borrowed reference: never release it).",
     "gated": false,
     "name": "getCurrentSound",
     "signature": "getCurrentSound():haxefmod.core.Sound",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getdelay": {
   "fmod": "FMOD_ChannelGroup_GetDelay, FMOD_Channel_GetDelay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getDelay",
     "signature": "getDelay():Null<FmodDelay>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getDelay",
     "signature": "getDelay():Null<FmodDelay>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getdsp": {
   "fmod": "FMOD_ChannelGroup_GetDSP, FMOD_Channel_GetDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The effect at chain position index.",
     "gated": false,
     "name": "getDsp",
     "signature": "getDsp(index:Int):Dsp",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The effect at chain position index (a known DSP returns its existing handle).",
     "gated": false,
     "name": "getDsp",
     "signature": "getDsp(index:Int):Dsp",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getdspclock": {
   "fmod": "FMOD_ChannelGroup_GetDSPClock, FMOD_Channel_GetDSPClock",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group's mixer clock in output samples, or null on failure.",
     "gated": false,
     "name": "getDspClock",
     "signature": "getDspClock():Null<FmodDspClock>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The channel's mixer clock in output samples, or null on failure.",
     "gated": false,
     "name": "getDspClock",
     "signature": "getDspClock():Null<FmodDspClock>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getdspindex": {
   "fmod": "FMOD_ChannelGroup_GetDSPIndex, FMOD_Channel_GetDSPIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The chain position of an attached effect, -1 when it is not attached or on failure.",
     "gated": false,
     "name": "getDspIndex",
     "signature": "getDspIndex(dsp:Dsp):Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The chain position of an attached effect, -1 when it is not attached or on failure.",
     "gated": false,
     "name": "getDspIndex",
     "signature": "getDspIndex(dsp:Dsp):Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getfadepoints": {
   "fmod": "FMOD_ChannelGroup_GetFadePoints, FMOD_Channel_GetFadePoints",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The scheduled fade points as parent-clock and volume pairs (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getFadePoints",
     "signature": "getFadePoints():Null<Array<FmodFadePoint>>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The scheduled fade points as parent-clock and volume pairs (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getFadePoints",
     "signature": "getFadePoints():Null<Array<FmodFadePoint>>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channelcontrol_getfrequency": {
   "fmod": "FMOD_Channel_GetFrequency",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback rate in samples per second (resampling: also shifts pitch).",
     "gated": false,
     "name": "getFrequency",
     "signature": "getFrequency():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getgroup": {
   "fmod": "FMOD_ChannelGroup_GetGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A nested child group by index (a known group returns its existing handle).",
     "gated": false,
     "name": "getGroup",
     "signature": "getGroup(index:Int):ChannelGroup",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_getindex": {
   "fmod": "FMOD_Channel_GetIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The channel's index inside FMOD's channel pool, or -1 on failure.",
     "gated": false,
     "name": "getIndex",
     "signature": "getIndex():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getloopcount": {
   "fmod": "FMOD_Channel_GetLoopCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getLoopCount",
     "signature": "getLoopCount():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getlooppoints": {
   "fmod": "FMOD_Channel_GetLoopPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The loop region, loopStart in loopStartType and loopEnd in loopEndType (milliseconds when left out, a missing loopEndType follows loopStartType), or null on failure.",
     "gated": false,
     "name": "getLoopPoints",
     "signature": "getLoopPoints(loopStartType:FmodTimeUnit = FmodTimeUnit.MS, ?loopEndType:FmodTimeUnit):Null<{loopStart:Int, loopEnd:Int}>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getlowpassgain": {
   "fmod": "FMOD_ChannelGroup_GetLowPassGain, FMOD_Channel_GetLowPassGain",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group's lowpass gain, 0.0 on failure.",
     "gated": false,
     "name": "getLowPassGain",
     "signature": "getLowPassGain():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getLowPassGain",
     "signature": "getLowPassGain():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getmixmatrix": {
   "fmod": "FMOD_ChannelGroup_GetMixMatrix, FMOD_Channel_GetMixMatrix",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Reads the mix matrix back as one flat row-major array with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMixMatrix",
     "signature": "getMixMatrix(outChannels:Int = 0, inChannels:Int = 0, inChannelHop:Int = 0):Null<FmodMixMatrix>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Reads the mix matrix back as one flat row-major array with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMixMatrix",
     "signature": "getMixMatrix(outChannels:Int = 0, inChannels:Int = 0, inChannelHop:Int = 0):Null<FmodMixMatrix>",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channelcontrol_getmode": {
   "fmod": "FMOD_ChannelGroup_GetMode, FMOD_Channel_GetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMode",
     "signature": "getMode():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMode",
     "signature": "getMode():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getmute": {
   "fmod": "FMOD_ChannelGroup_GetMute, FMOD_Channel_GetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMute",
     "signature": "getMute():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMute",
     "signature": "getMute():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getname": {
   "fmod": "FMOD_ChannelGroup_GetName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getName",
     "signature": "getName():String",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_getnumchannels": {
   "fmod": "FMOD_ChannelGroup_GetNumChannels",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getChannelCount under FMOD's name.",
     "gated": false,
     "name": "getNumChannels",
     "signature": "getNumChannels():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getChannelCount",
     "signature": "getChannelCount():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_getnumdsps": {
   "fmod": "FMOD_ChannelGroup_GetNumDSPs, FMOD_Channel_GetNumDSPs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getDspCount under FMOD's name.",
     "gated": false,
     "name": "getNumDSPs",
     "signature": "getNumDSPs():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "How many DSP units sit in this group's chain (the fader counts, so a fresh group reports 1).",
     "gated": false,
     "name": "getDspCount",
     "signature": "getDspCount():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The same count as getDspCount under FMOD's name.",
     "gated": false,
     "name": "getNumDSPs",
     "signature": "getNumDSPs():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getDspCount",
     "signature": "getDspCount():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getnumgroups": {
   "fmod": "FMOD_ChannelGroup_GetNumGroups",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getGroupCount under FMOD's name.",
     "gated": false,
     "name": "getNumGroups",
     "signature": "getNumGroups():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getGroupCount",
     "signature": "getGroupCount():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_getparentgroup": {
   "fmod": "FMOD_ChannelGroup_GetParentGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getParentGroup",
     "signature": "getParentGroup():ChannelGroup",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_getpaused": {
   "fmod": "FMOD_ChannelGroup_GetPaused, FMOD_Channel_GetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getpitch": {
   "fmod": "FMOD_ChannelGroup_GetPitch, FMOD_Channel_GetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPitch",
     "signature": "getPitch():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The pitch multiplier (1.0 = as recorded, 2.0 = one octave up).",
     "gated": false,
     "name": "getPitch",
     "signature": "getPitch():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getposition": {
   "fmod": "FMOD_Channel_GetPosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback position in unit (milliseconds by default, samples with FmodTimeUnit.PCM), or -1 on failure.",
     "gated": false,
     "name": "getPosition",
     "signature": "getPosition(unit:FmodTimeUnit = FmodTimeUnit.MS):Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getpriority": {
   "fmod": "FMOD_Channel_GetPriority",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPriority",
     "signature": "getPriority():Int",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getreverbproperties": {
   "fmod": "FMOD_ChannelGroup_GetReverbProperties, FMOD_Channel_GetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The wet level of a reverb send, the same read as getReverbWet under FMOD's name.",
     "gated": false,
     "name": "getReverbProperties",
     "signature": "getReverbProperties(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getReverbWet",
     "signature": "getReverbWet(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The wet level of a reverb send, the same read as getReverbWet under FMOD's name.",
     "gated": false,
     "name": "getReverbProperties",
     "signature": "getReverbProperties(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getReverbWet",
     "signature": "getReverbWet(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getsystemobject": {
   "fmod": "",
   "haxe": [],
   "heading": "ChannelControl::getSystemObject",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back."
   ]
  },
  "channelcontrol_getuserdata": {
   "fmod": "FMOD_ChannelGroup_GetUserData, FMOD_Channel_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getvolume": {
   "fmod": "FMOD_ChannelGroup_GetVolume, FMOD_Channel_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The volume as set by the API (linear: 0.0 = silent, 1.0 = full).",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_getvolumeramp": {
   "fmod": "FMOD_ChannelGroup_GetVolumeRamp, FMOD_Channel_GetVolumeRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolumeRamp",
     "signature": "getVolumeRamp():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolumeRamp",
     "signature": "getVolumeRamp():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_isplaying": {
   "fmod": "FMOD_ChannelGroup_IsPlaying, FMOD_Channel_IsPlaying",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True while any channel in the group or a nested group is playing.",
     "gated": false,
     "name": "isPlaying",
     "signature": "isPlaying():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isPlaying",
     "signature": "isPlaying():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_isvirtual": {
   "fmod": "FMOD_Channel_IsVirtual",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True when FMOD virtualized the channel (inaudible, position still tracked).",
     "gated": false,
     "name": "isVirtual",
     "signature": "isVirtual():Bool",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_release": {
   "fmod": "FMOD_ChannelGroup_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Frees a group made with create() and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelcontrol_removedsp": {
   "fmod": "FMOD_ChannelGroup_RemoveDSP, FMOD_Channel_RemoveDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeDsp",
     "signature": "removeDsp(dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeDsp",
     "signature": "removeDsp(dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_removefadepoints": {
   "fmod": "FMOD_ChannelGroup_RemoveFadePoints, FMOD_Channel_RemoveFadePoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeFadePoints",
     "signature": "removeFadePoints(startClock:Float, endClock:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeFadePoints",
     "signature": "removeFadePoints(startClock:Float, endClock:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dattributes": {
   "fmod": "FMOD_ChannelGroup_Set3DAttributes, FMOD_Channel_Set3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Positions the whole group in 3D space (needs a 3D mode set).",
     "gated": false,
     "name": "set3DAttributes",
     "signature": "set3DAttributes(posX:Float, posY:Float, posZ:Float, velX:Float = 0, velY:Float = 0, velZ:Float = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Positions the channel in 3D space.",
     "gated": false,
     "name": "set3DAttributes",
     "signature": "set3DAttributes(posX:Float, posY:Float, posZ:Float, velX:Float = 0, velY:Float = 0, velZ:Float = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dconeorientation": {
   "fmod": "FMOD_ChannelGroup_Set3DConeOrientation, FMOD_Channel_Set3DConeOrientation",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DConeOrientation",
     "signature": "set3DConeOrientation(x:Float, y:Float, z:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DConeOrientation",
     "signature": "set3DConeOrientation(x:Float, y:Float, z:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dconesettings": {
   "fmod": "FMOD_ChannelGroup_Set3DConeSettings, FMOD_Channel_Set3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DConeSettings",
     "signature": "set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Directional sound: full volume inside the cone, outsideVolume behind it.",
     "gated": false,
     "name": "set3DConeSettings",
     "signature": "set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dcustomrolloff": {
   "fmod": "FMOD_ChannelGroup_Set3DCustomRolloff, FMOD_Channel_Set3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Replaces the distance rolloff curve with the given points.",
     "gated": true,
     "name": "set3DCustomRolloff",
     "signature": "set3DCustomRolloff(points:Array<FmodVector>):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Replaces the distance rolloff curve with the given points.",
     "gated": true,
     "name": "set3DCustomRolloff",
     "signature": "set3DCustomRolloff(points:Array<FmodVector>):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": true
  },
  "channelcontrol_set3ddistancefilter": {
   "fmod": "FMOD_ChannelGroup_Set3DDistanceFilter, FMOD_Channel_Set3DDistanceFilter",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Overrides the distance lowpass on this group's 3D channels.",
     "gated": false,
     "name": "set3DDistanceFilter",
     "signature": "set3DDistanceFilter(custom:Bool, customLevel:Float, centerFreq:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Overrides the distance lowpass on this 3D channel.",
     "gated": false,
     "name": "set3DDistanceFilter",
     "signature": "set3DDistanceFilter(custom:Bool, customLevel:Float, centerFreq:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3ddopplerlevel": {
   "fmod": "FMOD_ChannelGroup_Set3DDopplerLevel, FMOD_Channel_Set3DDopplerLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DDopplerLevel",
     "signature": "set3DDopplerLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DDopplerLevel",
     "signature": "set3DDopplerLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dlevel": {
   "fmod": "FMOD_ChannelGroup_Set3DLevel, FMOD_Channel_Set3DLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DLevel",
     "signature": "set3DLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Blend between 2D and full 3D positioning (0.0 = 2D, 1.0 = 3D).",
     "gated": false,
     "name": "set3DLevel",
     "signature": "set3DLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dminmaxdistance": {
   "fmod": "FMOD_ChannelGroup_Set3DMinMaxDistance, FMOD_Channel_Set3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DMinMaxDistance",
     "signature": "set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Distances where attenuation starts and stops (3D sounds).",
     "gated": false,
     "name": "set3DMinMaxDistance",
     "signature": "set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3docclusion": {
   "fmod": "FMOD_ChannelGroup_Set3DOcclusion, FMOD_Channel_Set3DOcclusion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Muffles the group as if behind an obstacle (0.0 = clear, 1.0 = fully blocked).",
     "gated": false,
     "name": "set3DOcclusion",
     "signature": "set3DOcclusion(direct:Float, reverb:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Muffles the channel as if behind an obstacle (0.0 = clear, 1.0 = fully blocked).",
     "gated": false,
     "name": "set3DOcclusion",
     "signature": "set3DOcclusion(direct:Float, reverb:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_set3dspread": {
   "fmod": "FMOD_ChannelGroup_Set3DSpread, FMOD_Channel_Set3DSpread",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DSpread",
     "signature": "set3DSpread(angle:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Speaker spread of a 3D sound in degrees (0 = point source).",
     "gated": false,
     "name": "set3DSpread",
     "signature": "set3DSpread(angle:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setcallback": {
   "fmod": "FMOD_ChannelGroup_SetCallback, FMOD_Channel_SetCallback",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Delivers ChannelEvent values for this group (drained once per frame with the other callbacks).",
     "name": "setCallback",
     "signature": "setCallback(handler:haxefmod.core.ChannelEvent.ChannelCallback):Void",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "name": "clearCallback",
     "signature": "clearCallback():Void",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Delivers ChannelEvent values for this channel (drained once per frame with the other callbacks): End, SyncPoint, VirtualVoice, and Occlusion.",
     "name": "setCallback",
     "signature": "setCallback(handler:haxefmod.core.ChannelEvent.ChannelCallback):Void",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "",
     "name": "clearCallback",
     "signature": "clearCallback():Void",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setchannelgroup": {
   "fmod": "FMOD_Channel_SetChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Reroutes this channel into a group.",
     "gated": false,
     "name": "setChannelGroup",
     "signature": "setChannelGroup(group:ChannelGroup):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setdelay": {
   "fmod": "FMOD_ChannelGroup_SetDelay, FMOD_Channel_SetDelay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sample-accurate start/stop window on the parent clock (0 = no bound).",
     "gated": false,
     "name": "setDelay",
     "signature": "setDelay(startClock:Float, endClock:Float, stopChannels:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Sample-accurate start/stop window on the parent clock (0 = no bound).",
     "gated": false,
     "name": "setDelay",
     "signature": "setDelay(startClock:Float, endClock:Float, stopChannels:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setdspindex": {
   "fmod": "FMOD_ChannelGroup_SetDSPIndex, FMOD_Channel_SetDSPIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves an attached effect to another chain position (0 = head).",
     "gated": false,
     "name": "setDspIndex",
     "signature": "setDspIndex(dsp:Dsp, index:Int):haxefmod.studio.FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Moves an attached effect to another chain position (0 = head).",
     "gated": false,
     "name": "setDspIndex",
     "signature": "setDspIndex(dsp:Dsp, index:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setfadepointramp": {
   "fmod": "FMOD_ChannelGroup_SetFadePointRamp, FMOD_Channel_SetFadePointRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A click-free ramp from the current volume to volume, ending at clock.",
     "gated": false,
     "name": "setFadePointRamp",
     "signature": "setFadePointRamp(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "A click-free ramp from the current volume to volume, ending at clock.",
     "gated": false,
     "name": "setFadePointRamp",
     "signature": "setFadePointRamp(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setfrequency": {
   "fmod": "FMOD_Channel_SetFrequency",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setFrequency",
     "signature": "setFrequency(frequency:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setloopcount": {
   "fmod": "FMOD_Channel_SetLoopCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Times to loop before stopping (-1 = forever, 0 = play once).",
     "gated": false,
     "name": "setLoopCount",
     "signature": "setLoopCount(loopCount:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setlooppoints": {
   "fmod": "FMOD_Channel_SetLoopPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loop region for this channel (overrides the sound's).",
     "gated": false,
     "name": "setLoopPoints",
     "signature": "setLoopPoints(loopStart:Int, loopEnd:Int, loopStartType:FmodTimeUnit = FmodTimeUnit.MS, ?loopEndType:FmodTimeUnit):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setlowpassgain": {
   "fmod": "FMOD_ChannelGroup_SetLowPassGain, FMOD_Channel_SetLowPassGain",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A built-in lowpass on the group (1.0 = open, 0.0 = closed).",
     "gated": false,
     "name": "setLowPassGain",
     "signature": "setLowPassGain(gain:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "A built-in lowpass on the channel (1.0 = open, 0.0 = fully closed).",
     "gated": false,
     "name": "setLowPassGain",
     "signature": "setLowPassGain(gain:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setmixlevelsinput": {
   "fmod": "FMOD_ChannelGroup_SetMixLevelsInput, FMOD_Channel_SetMixLevelsInput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the gain of each incoming signal channel before the mix matrix, one level per input channel (1 to 32, an empty list is rejected with FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "setMixLevelsInput",
     "signature": "setMixLevelsInput(levels:Array<Float>):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Sets the gain of each incoming signal channel before the mix matrix, one level per input channel (1 to 32, an empty list is rejected with FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "setMixLevelsInput",
     "signature": "setMixLevelsInput(levels:Array<Float>):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setmixlevelsoutput": {
   "fmod": "FMOD_ChannelGroup_SetMixLevelsOutput, FMOD_Channel_SetMixLevelsOutput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the gain of each output speaker directly, which replaces the mix matrix with a standard speaker layout.",
     "gated": false,
     "name": "setMixLevelsOutput",
     "signature": "setMixLevelsOutput(frontLeft:Float, frontRight:Float, center:Float, lowFrequency:Float, surroundLeft:Float, surroundRight:Float, backLeft:Float, backRight:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Sets the gain of each output speaker directly, which replaces the mix matrix with a standard speaker layout.",
     "gated": false,
     "name": "setMixLevelsOutput",
     "signature": "setMixLevelsOutput(frontLeft:Float, frontRight:Float, center:Float, lowFrequency:Float, surroundLeft:Float, surroundRight:Float, backLeft:Float, backRight:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setmixmatrix": {
   "fmod": "FMOD_ChannelGroup_SetMixMatrix, FMOD_Channel_SetMixMatrix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes input channels to output speakers with explicit gains.",
     "gated": false,
     "name": "setMixMatrix",
     "signature": "setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Routes input channels to output speakers with explicit gains.",
     "gated": false,
     "name": "setMixMatrix",
     "signature": "setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setmode": {
   "fmod": "FMOD_ChannelGroup_SetMode, FMOD_Channel_SetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Combines ChannelMode flags (looping, 2D/3D, rolloff shape).",
     "gated": false,
     "name": "setMode",
     "signature": "setMode(mode:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Combines ChannelMode flags (looping, 2D/3D, rolloff shape).",
     "gated": false,
     "name": "setMode",
     "signature": "setMode(mode:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setmute": {
   "fmod": "FMOD_ChannelGroup_SetMute, FMOD_Channel_SetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setMute",
     "signature": "setMute(mute:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setMute",
     "signature": "setMute(mute:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setpan": {
   "fmod": "FMOD_ChannelGroup_SetPan, FMOD_Channel_SetPan",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Constant-power stereo pan over the whole group.",
     "gated": false,
     "name": "setPan",
     "signature": "setPan(pan:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Constant-power stereo pan (-1.0 = full left, 0 = center, 1.0 = full right).",
     "gated": false,
     "name": "setPan",
     "signature": "setPan(pan:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setpaused": {
   "fmod": "FMOD_ChannelGroup_SetPaused, FMOD_Channel_SetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setpitch": {
   "fmod": "FMOD_ChannelGroup_SetPitch, FMOD_Channel_SetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPitch",
     "signature": "setPitch(pitch:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPitch",
     "signature": "setPitch(pitch:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setposition": {
   "fmod": "FMOD_Channel_SetPosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Seeks to a position read in unit, milliseconds unless another FmodTimeUnit is given.",
     "gated": false,
     "name": "setPosition",
     "signature": "setPosition(positionMs:Int, unit:FmodTimeUnit = FmodTimeUnit.MS):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setpriority": {
   "fmod": "FMOD_Channel_SetPriority",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Voice priority for virtualization (0 = most important, 256 = least).",
     "gated": false,
     "name": "setPriority",
     "signature": "setPriority(priority:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setreverbproperties": {
   "fmod": "FMOD_ChannelGroup_SetReverbProperties, FMOD_Channel_SetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same reverb send as setReverbWet under FMOD's name (ChannelControl::setReverbProperties).",
     "gated": false,
     "name": "setReverbProperties",
     "signature": "setReverbProperties(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "How much this group feeds a reverb instance (0.0 = none, 1.0 = full).",
     "gated": false,
     "name": "setReverbWet",
     "signature": "setReverbWet(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "The same reverb send as setReverbWet under FMOD's name (ChannelControl::setReverbProperties).",
     "gated": false,
     "name": "setReverbProperties",
     "signature": "setReverbProperties(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    },
    {
     "direct": false,
     "doc": "How much this channel feeds a reverb instance (0.0 = none, 1.0 = full).",
     "gated": false,
     "name": "setReverbWet",
     "signature": "setReverbWet(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setuserdata": {
   "fmod": "FMOD_ChannelGroup_SetUserData, FMOD_Channel_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setvolume": {
   "fmod": "FMOD_ChannelGroup_SetVolume, FMOD_Channel_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_setvolumeramp": {
   "fmod": "FMOD_ChannelGroup_SetVolumeRamp, FMOD_Channel_SetVolumeRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Short volume ramping on changes (on by default, prevents clicks).",
     "gated": false,
     "name": "setVolumeRamp",
     "signature": "setVolumeRamp(ramp:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Short volume ramping on changes (on by default, prevents clicks).",
     "gated": false,
     "name": "setVolumeRamp",
     "signature": "setVolumeRamp(ramp:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelcontrol_stop": {
   "fmod": "FMOD_ChannelGroup_Stop, FMOD_Channel_Stop",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops every channel in the group.",
     "gated": false,
     "name": "stop",
     "signature": "stop():FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": true,
     "doc": "Stops playback, removes any callback handler, and invalidates this handle.",
     "gated": false,
     "name": "stop",
     "signature": "stop():FmodResult",
     "static": false,
     "type": "haxefmod.core.Channel"
    }
   ],
   "html5": false
  },
  "channelgroup_adddsp": {
   "fmod": "FMOD_ChannelGroup_AddDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Inserts an effect at index (0 = head of the chain, or a DSP_* position).",
     "gated": false,
     "name": "addDsp",
     "signature": "addDsp(index:Int, dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_addfadepoint": {
   "fmod": "FMOD_ChannelGroup_AddFadePoint",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Schedules a volume point at a parent-clock time.",
     "gated": false,
     "name": "addFadePoint",
     "signature": "addFadePoint(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_addgroup": {
   "fmod": "FMOD_ChannelGroup_AddGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes a child group's output through this one (group hierarchies).",
     "gated": false,
     "name": "addGroup",
     "signature": "addGroup(child:ChannelGroup, propagateDspClock:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "Routes a child group's output through this one and returns the connection between the two, DspConnection.NULL on failure with the reason in StudioSystem.lastResult().",
     "gated": false,
     "name": "addGroupConnection",
     "signature": "addGroupConnection(child:ChannelGroup, propagateDspClock:Bool = true):DspConnection",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dattributes": {
   "fmod": "FMOD_ChannelGroup_Get3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DAttributes",
     "signature": "get3DAttributes():Null<FmodChannel3DAttributes>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dconeorientation": {
   "fmod": "FMOD_ChannelGroup_Get3DConeOrientation",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeOrientation",
     "signature": "get3DConeOrientation():Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dconesettings": {
   "fmod": "FMOD_ChannelGroup_Get3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeSettings",
     "signature": "get3DConeSettings():Null<FmodConeSettings>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dcustomrolloff": {
   "fmod": "FMOD_ChannelGroup_Get3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The custom rolloff points (unsupported in HTML5, always empty there), empty when none are set or on failure (see StudioSystem.lastResult).",
     "gated": true,
     "name": "get3DCustomRolloff",
     "signature": "get3DCustomRolloff():Array<FmodVector>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": true
  },
  "channelgroup_get3ddistancefilter": {
   "fmod": "FMOD_ChannelGroup_Get3DDistanceFilter",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDistanceFilter",
     "signature": "get3DDistanceFilter():Null<FmodDistanceFilter>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3ddopplerlevel": {
   "fmod": "FMOD_ChannelGroup_Get3DDopplerLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DDopplerLevel",
     "signature": "get3DDopplerLevel():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dlevel": {
   "fmod": "FMOD_ChannelGroup_Get3DLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DLevel",
     "signature": "get3DLevel():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dminmaxdistance": {
   "fmod": "FMOD_ChannelGroup_Get3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DMinMaxDistance",
     "signature": "get3DMinMaxDistance():Null<FmodMinMaxDistance>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3docclusion": {
   "fmod": "FMOD_ChannelGroup_Get3DOcclusion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group's occlusion levels, null on failure.",
     "gated": false,
     "name": "get3DOcclusion",
     "signature": "get3DOcclusion():Null<FmodOcclusion>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_get3dspread": {
   "fmod": "FMOD_ChannelGroup_Get3DSpread",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DSpread",
     "signature": "get3DSpread():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getaudibility": {
   "fmod": "FMOD_ChannelGroup_GetAudibility",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The final audible volume after parent groups and 3D scaling.",
     "gated": false,
     "name": "getAudibility",
     "signature": "getAudibility():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getchannel": {
   "fmod": "FMOD_ChannelGroup_GetChannel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A channel routed into this group by index (known channels dedup).",
     "gated": false,
     "name": "getChannel",
     "signature": "getChannel(index:Int):Channel",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getdelay": {
   "fmod": "FMOD_ChannelGroup_GetDelay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getDelay",
     "signature": "getDelay():Null<FmodDelay>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getdsp": {
   "fmod": "FMOD_ChannelGroup_GetDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The effect at chain position index.",
     "gated": false,
     "name": "getDsp",
     "signature": "getDsp(index:Int):Dsp",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getdspclock": {
   "fmod": "FMOD_ChannelGroup_GetDSPClock",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group's mixer clock in output samples, or null on failure.",
     "gated": false,
     "name": "getDspClock",
     "signature": "getDspClock():Null<FmodDspClock>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getdspindex": {
   "fmod": "FMOD_ChannelGroup_GetDSPIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The chain position of an attached effect, -1 when it is not attached or on failure.",
     "gated": false,
     "name": "getDspIndex",
     "signature": "getDspIndex(dsp:Dsp):Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getfadepoints": {
   "fmod": "FMOD_ChannelGroup_GetFadePoints",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The scheduled fade points as parent-clock and volume pairs (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getFadePoints",
     "signature": "getFadePoints():Null<Array<FmodFadePoint>>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": true
  },
  "channelgroup_getgroup": {
   "fmod": "FMOD_ChannelGroup_GetGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A nested child group by index (a known group returns its existing handle).",
     "gated": false,
     "name": "getGroup",
     "signature": "getGroup(index:Int):ChannelGroup",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getlowpassgain": {
   "fmod": "FMOD_ChannelGroup_GetLowPassGain",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group's lowpass gain, 0.0 on failure.",
     "gated": false,
     "name": "getLowPassGain",
     "signature": "getLowPassGain():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getmixmatrix": {
   "fmod": "FMOD_ChannelGroup_GetMixMatrix",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Reads the mix matrix back as one flat row-major array with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMixMatrix",
     "signature": "getMixMatrix(outChannels:Int = 0, inChannels:Int = 0, inChannelHop:Int = 0):Null<FmodMixMatrix>",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": true
  },
  "channelgroup_getmode": {
   "fmod": "FMOD_ChannelGroup_GetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMode",
     "signature": "getMode():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getmute": {
   "fmod": "FMOD_ChannelGroup_GetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMute",
     "signature": "getMute():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getname": {
   "fmod": "FMOD_ChannelGroup_GetName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getName",
     "signature": "getName():String",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getnumchannels": {
   "fmod": "FMOD_ChannelGroup_GetNumChannels",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getChannelCount under FMOD's name.",
     "gated": false,
     "name": "getNumChannels",
     "signature": "getNumChannels():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getChannelCount",
     "signature": "getChannelCount():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getnumdsps": {
   "fmod": "FMOD_ChannelGroup_GetNumDSPs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getDspCount under FMOD's name.",
     "gated": false,
     "name": "getNumDSPs",
     "signature": "getNumDSPs():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "How many DSP units sit in this group's chain (the fader counts, so a fresh group reports 1).",
     "gated": false,
     "name": "getDspCount",
     "signature": "getDspCount():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getnumgroups": {
   "fmod": "FMOD_ChannelGroup_GetNumGroups",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getGroupCount under FMOD's name.",
     "gated": false,
     "name": "getNumGroups",
     "signature": "getNumGroups():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getGroupCount",
     "signature": "getGroupCount():Int",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getparentgroup": {
   "fmod": "FMOD_ChannelGroup_GetParentGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getParentGroup",
     "signature": "getParentGroup():ChannelGroup",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getpaused": {
   "fmod": "FMOD_ChannelGroup_GetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getpitch": {
   "fmod": "FMOD_ChannelGroup_GetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPitch",
     "signature": "getPitch():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getreverbproperties": {
   "fmod": "FMOD_ChannelGroup_GetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The wet level of a reverb send, the same read as getReverbWet under FMOD's name.",
     "gated": false,
     "name": "getReverbProperties",
     "signature": "getReverbProperties(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getReverbWet",
     "signature": "getReverbWet(instance:Int):Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getuserdata": {
   "fmod": "FMOD_ChannelGroup_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getvolume": {
   "fmod": "FMOD_ChannelGroup_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_getvolumeramp": {
   "fmod": "FMOD_ChannelGroup_GetVolumeRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolumeRamp",
     "signature": "getVolumeRamp():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_isplaying": {
   "fmod": "FMOD_ChannelGroup_IsPlaying",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True while any channel in the group or a nested group is playing.",
     "gated": false,
     "name": "isPlaying",
     "signature": "isPlaying():Bool",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_release": {
   "fmod": "FMOD_ChannelGroup_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Frees a group made with create() and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_removedsp": {
   "fmod": "FMOD_ChannelGroup_RemoveDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeDsp",
     "signature": "removeDsp(dsp:Dsp):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_removefadepoints": {
   "fmod": "FMOD_ChannelGroup_RemoveFadePoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "removeFadePoints",
     "signature": "removeFadePoints(startClock:Float, endClock:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dattributes": {
   "fmod": "FMOD_ChannelGroup_Set3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Positions the whole group in 3D space (needs a 3D mode set).",
     "gated": false,
     "name": "set3DAttributes",
     "signature": "set3DAttributes(posX:Float, posY:Float, posZ:Float, velX:Float = 0, velY:Float = 0, velZ:Float = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dconeorientation": {
   "fmod": "FMOD_ChannelGroup_Set3DConeOrientation",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DConeOrientation",
     "signature": "set3DConeOrientation(x:Float, y:Float, z:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dconesettings": {
   "fmod": "FMOD_ChannelGroup_Set3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DConeSettings",
     "signature": "set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dcustomrolloff": {
   "fmod": "FMOD_ChannelGroup_Set3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Replaces the distance rolloff curve with the given points.",
     "gated": true,
     "name": "set3DCustomRolloff",
     "signature": "set3DCustomRolloff(points:Array<FmodVector>):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": true
  },
  "channelgroup_set3ddistancefilter": {
   "fmod": "FMOD_ChannelGroup_Set3DDistanceFilter",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Overrides the distance lowpass on this group's 3D channels.",
     "gated": false,
     "name": "set3DDistanceFilter",
     "signature": "set3DDistanceFilter(custom:Bool, customLevel:Float, centerFreq:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3ddopplerlevel": {
   "fmod": "FMOD_ChannelGroup_Set3DDopplerLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DDopplerLevel",
     "signature": "set3DDopplerLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dlevel": {
   "fmod": "FMOD_ChannelGroup_Set3DLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DLevel",
     "signature": "set3DLevel(level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dminmaxdistance": {
   "fmod": "FMOD_ChannelGroup_Set3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DMinMaxDistance",
     "signature": "set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3docclusion": {
   "fmod": "FMOD_ChannelGroup_Set3DOcclusion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Muffles the group as if behind an obstacle (0.0 = clear, 1.0 = fully blocked).",
     "gated": false,
     "name": "set3DOcclusion",
     "signature": "set3DOcclusion(direct:Float, reverb:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_set3dspread": {
   "fmod": "FMOD_ChannelGroup_Set3DSpread",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DSpread",
     "signature": "set3DSpread(angle:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setcallback": {
   "fmod": "FMOD_ChannelGroup_SetCallback",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Delivers ChannelEvent values for this group (drained once per frame with the other callbacks).",
     "name": "setCallback",
     "signature": "setCallback(handler:haxefmod.core.ChannelEvent.ChannelCallback):Void",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "",
     "name": "clearCallback",
     "signature": "clearCallback():Void",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setdelay": {
   "fmod": "FMOD_ChannelGroup_SetDelay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sample-accurate start/stop window on the parent clock (0 = no bound).",
     "gated": false,
     "name": "setDelay",
     "signature": "setDelay(startClock:Float, endClock:Float, stopChannels:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setdspindex": {
   "fmod": "FMOD_ChannelGroup_SetDSPIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves an attached effect to another chain position (0 = head).",
     "gated": false,
     "name": "setDspIndex",
     "signature": "setDspIndex(dsp:Dsp, index:Int):haxefmod.studio.FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setfadepointramp": {
   "fmod": "FMOD_ChannelGroup_SetFadePointRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A click-free ramp from the current volume to volume, ending at clock.",
     "gated": false,
     "name": "setFadePointRamp",
     "signature": "setFadePointRamp(clock:Float, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setlowpassgain": {
   "fmod": "FMOD_ChannelGroup_SetLowPassGain",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A built-in lowpass on the group (1.0 = open, 0.0 = closed).",
     "gated": false,
     "name": "setLowPassGain",
     "signature": "setLowPassGain(gain:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setmixlevelsinput": {
   "fmod": "FMOD_ChannelGroup_SetMixLevelsInput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the gain of each incoming signal channel before the mix matrix, one level per input channel (1 to 32, an empty list is rejected with FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "setMixLevelsInput",
     "signature": "setMixLevelsInput(levels:Array<Float>):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setmixlevelsoutput": {
   "fmod": "FMOD_ChannelGroup_SetMixLevelsOutput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the gain of each output speaker directly, which replaces the mix matrix with a standard speaker layout.",
     "gated": false,
     "name": "setMixLevelsOutput",
     "signature": "setMixLevelsOutput(frontLeft:Float, frontRight:Float, center:Float, lowFrequency:Float, surroundLeft:Float, surroundRight:Float, backLeft:Float, backRight:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setmixmatrix": {
   "fmod": "FMOD_ChannelGroup_SetMixMatrix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes input channels to output speakers with explicit gains.",
     "gated": false,
     "name": "setMixMatrix",
     "signature": "setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setmode": {
   "fmod": "FMOD_ChannelGroup_SetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Combines ChannelMode flags (looping, 2D/3D, rolloff shape).",
     "gated": false,
     "name": "setMode",
     "signature": "setMode(mode:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setmute": {
   "fmod": "FMOD_ChannelGroup_SetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setMute",
     "signature": "setMute(mute:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setpan": {
   "fmod": "FMOD_ChannelGroup_SetPan",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Constant-power stereo pan over the whole group.",
     "gated": false,
     "name": "setPan",
     "signature": "setPan(pan:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setpaused": {
   "fmod": "FMOD_ChannelGroup_SetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setpitch": {
   "fmod": "FMOD_ChannelGroup_SetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPitch",
     "signature": "setPitch(pitch:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setreverbproperties": {
   "fmod": "FMOD_ChannelGroup_SetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same reverb send as setReverbWet under FMOD's name (ChannelControl::setReverbProperties).",
     "gated": false,
     "name": "setReverbProperties",
     "signature": "setReverbProperties(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    },
    {
     "direct": false,
     "doc": "How much this group feeds a reverb instance (0.0 = none, 1.0 = full).",
     "gated": false,
     "name": "setReverbWet",
     "signature": "setReverbWet(instance:Int, wet:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setuserdata": {
   "fmod": "FMOD_ChannelGroup_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setvolume": {
   "fmod": "FMOD_ChannelGroup_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_setvolumeramp": {
   "fmod": "FMOD_ChannelGroup_SetVolumeRamp",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Short volume ramping on changes (on by default, prevents clicks).",
     "gated": false,
     "name": "setVolumeRamp",
     "signature": "setVolumeRamp(ramp:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "channelgroup_stop": {
   "fmod": "FMOD_ChannelGroup_Stop",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops every channel in the group.",
     "gated": false,
     "name": "stop",
     "signature": "stop():FmodResult",
     "static": false,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "debug_initialize": {
   "fmod": "FMOD_Debug_Initialize",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Turns on FMOD debug logging and facade operation traces.",
     "gated": false,
     "name": "EnableDebugMessages",
     "signature": "EnableDebugMessages():Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": true
  },
  "dsp_addinput": {
   "fmod": "FMOD_DSP_AddInput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Wires another DSP's output into this one, building custom mixer topologies.",
     "gated": false,
     "name": "addInput",
     "signature": "addInput(input:Dsp, connectionType:DspConnectionType = DspConnectionType.STANDARD):DspConnection",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_addinputpreallocated": {
   "fmod": "FMOD_DSP_AddInputPreallocated",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Wires another DSP's output into this one through a connection FMOD reserved ahead of time, so the mixer allocates nothing on the way in (unsupported in HTML5, returns DspConnection.NULL there).",
     "gated": true,
     "name": "addInputPreallocated",
     "signature": "addInputPreallocated(input:Dsp, connection:DspConnection):DspConnection",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": true
  },
  "dsp_disconnectall": {
   "fmod": "FMOD_DSP_DisconnectAll",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "disconnectAll",
     "signature": "disconnectAll(inputs:Bool = true, outputs:Bool = true):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_disconnectfrom": {
   "fmod": "FMOD_DSP_DisconnectFrom",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Removes the link from input into this unit.",
     "gated": false,
     "name": "disconnectFrom",
     "signature": "disconnectFrom(input:Dsp, connection:DspConnection = DspConnection.NULL):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getactive": {
   "fmod": "FMOD_DSP_GetActive",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getActive",
     "signature": "getActive():Bool",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getbypass": {
   "fmod": "FMOD_DSP_GetBypass",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getBypass",
     "signature": "getBypass():Bool",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getchannelformat": {
   "fmod": "FMOD_DSP_GetChannelFormat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getChannelFormat",
     "signature": "getChannelFormat():Null<FmodChannelFormat>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getcpuusage": {
   "fmod": "FMOD_DSP_GetCPUUsage",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Microseconds spent in this DSP per mix, or null (needs profiling enabled at init).",
     "gated": false,
     "name": "getCpuUsage",
     "signature": "getCpuUsage():Null<FmodCpuUsage>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getdataparameterindex": {
   "fmod": "FMOD_DSP_GetDataParameterIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The index of the data parameter carrying the given FmodDspParameterDataType (negative values are FMOD's own types, 0 and up are user data), -1 when the effect has none or on failure.",
     "gated": false,
     "name": "getDataParameterIndex",
     "signature": "getDataParameterIndex(dataType:FmodDspParameterDataType):Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getidle": {
   "fmod": "FMOD_DSP_GetIdle",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "True when no signal has flowed through the unit recently.",
     "gated": false,
     "name": "isIdle",
     "signature": "isIdle():Bool",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getinfo": {
   "fmod": "FMOD_DSP_GetInfo",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The unit's description: display name, plugin version (BCD, 0x10000 is 1.0), channel count (0 when the unit takes any), and the config dialog size a plugin declares.",
     "gated": false,
     "name": "getInfo",
     "signature": "getInfo():Null<FmodDspInfo>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "The effect's display name (e.g.",
     "gated": false,
     "name": "getName",
     "signature": "getName():String",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getinput": {
   "fmod": "FMOD_DSP_GetInput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The DSP feeding input slot index (a known DSP returns its existing handle).",
     "gated": false,
     "name": "getInput",
     "signature": "getInput(index:Int):Dsp",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getInputConnection",
     "signature": "getInputConnection(index:Int):DspConnection",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getmeteringenabled": {
   "fmod": "FMOD_DSP_GetMeteringEnabled",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMeteringEnabled",
     "signature": "getMeteringEnabled():Null<FmodMeteringEnabled>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getmeteringinfo": {
   "fmod": "FMOD_DSP_GetMeteringInfo",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "The FMOD_DSP_METERING_INFO of the output side, or of the input side with input set: peakLevel and rmsLevel per channel (linear 0..1), numChannels, and numSamples, the sample count the meter averaged.",
     "gated": false,
     "name": "getMetering",
     "signature": "getMetering(input:Bool = false):Null<FmodDspMeteringInfo>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getnuminputs": {
   "fmod": "FMOD_DSP_GetNumInputs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getInputCount under FMOD's name.",
     "gated": false,
     "name": "getNumInputs",
     "signature": "getNumInputs():Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getInputCount",
     "signature": "getInputCount():Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getnumoutputs": {
   "fmod": "FMOD_DSP_GetNumOutputs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getOutputCount under FMOD's name.",
     "gated": false,
     "name": "getNumOutputs",
     "signature": "getNumOutputs():Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getOutputCount",
     "signature": "getOutputCount():Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getnumparameters": {
   "fmod": "FMOD_DSP_GetNumParameters",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getParameterCount under FMOD's name.",
     "gated": false,
     "name": "getNumParameters",
     "signature": "getNumParameters():Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameterCount",
     "signature": "getParameterCount():Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getoutput": {
   "fmod": "FMOD_DSP_GetOutput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The DSP fed by output slot index (a known DSP returns its existing handle).",
     "gated": false,
     "name": "getOutput",
     "signature": "getOutput(index:Int):Dsp",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getOutputConnection",
     "signature": "getOutputConnection(index:Int):DspConnection",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getoutputchannelformat": {
   "fmod": "FMOD_DSP_GetOutputChannelFormat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The format the unit would emit when fed the given input format, or null on failure.",
     "gated": false,
     "name": "getOutputChannelFormat",
     "signature": "getOutputChannelFormat(inMask:FmodChannelMask, inChannels:Int, inSpeakerMode:FmodSpeakerMode):Null<FmodChannelFormat>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getparameterbool": {
   "fmod": "FMOD_DSP_GetParameterBool",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getParameterBool",
     "signature": "getParameterBool(index:Int):Bool",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getparameterdata": {
   "fmod": "FMOD_DSP_GetParameterData",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "A copy of the data block behind a data parameter, laid out as the effect's C struct (little endian, read it with haxe.io.Bytes getFloat and getInt32).",
     "gated": false,
     "name": "getParameterData",
     "signature": "getParameterData(index:Int):Null<haxe.io.Bytes>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Spectrum magnitudes from an FFT effect (create with DspType.FFT and attach where you want to analyze).",
     "gated": false,
     "name": "getFftSpectrum",
     "signature": "getFftSpectrum(maxBins:Int = 512):Null<Array<Float>>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "The whole FFT payload: the bin count, the channel count, and one magnitude array per channel, each capped at maxBins (512 at most).",
     "gated": false,
     "name": "getFftSpectrumInfo",
     "signature": "getFftSpectrumInfo(maxBins:Int = 512):Null<FmodDspParameterFft>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Reads the FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE of a DspType.LOUDNESS_METER unit back, all MAX_CHANNEL_SLOTS weights (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getLoudnessMeterWeighting",
     "signature": "getLoudnessMeterWeighting():Null<FmodDspLoudnessMeterWeightingType>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Reads a FmodDspParameterDataType.ATTENUATION_RANGE data parameter back.",
     "gated": false,
     "name": "getParameterAttenuationRange",
     "signature": "getParameterAttenuationRange(index:Int):Null<FmodDspParameterAttenuationRange>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Reads a FmodDspParameterDataType.DYNAMIC_RESPONSE data parameter (FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE), the RMS level per channel a dynamics plugin reports.",
     "gated": false,
     "name": "getParameterDynamicResponse",
     "signature": "getParameterDynamicResponse(index:Int):Null<FmodDspParameterDynamicResponse>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Reads a FmodDspParameterDataType.FINITE_LENGTH data parameter back.",
     "gated": false,
     "name": "getParameterFiniteLength",
     "signature": "getParameterFiniteLength(index:Int):Null<FmodDspParameterFiniteLength>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Reads a FmodDspParameterDataType.SIDECHAIN data parameter back.",
     "gated": false,
     "name": "getParameterSidechain",
     "signature": "getParameterSidechain(index:Int):Null<FmodDspParameterSidechain>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": true
  },
  "dsp_getparameterfloat": {
   "fmod": "FMOD_DSP_GetParameterFloat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same float read as getParameter under FMOD's name.",
     "gated": false,
     "name": "getParameterFloat",
     "signature": "getParameterFloat(index:Int):Float",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameter",
     "signature": "getParameter(index:Int):Float",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getparameterinfo": {
   "fmod": "FMOD_DSP_GetParameterInfo",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The FMOD_DSP_PARAMETER_DESC of the parameter at index (unsupported in HTML5, null there): type, name, label, description, and the union member matching type.",
     "gated": true,
     "name": "getParameterInfo",
     "signature": "getParameterInfo(index:Int):Null<FmodDspParameterDesc>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": true
  },
  "dsp_getparameterint": {
   "fmod": "FMOD_DSP_GetParameterInt",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getParameterInt",
     "signature": "getParameterInt(index:Int):Int",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getsystemobject": {
   "fmod": "",
   "haxe": [],
   "heading": "DSP::getSystemObject",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back."
   ]
  },
  "dsp_gettype": {
   "fmod": "FMOD_DSP_GetType",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getType",
     "signature": "getType():DspType",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getuserdata": {
   "fmod": "FMOD_DSP_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_getwetdrymix": {
   "fmod": "FMOD_DSP_GetWetDryMix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getWetDryMix",
     "signature": "getWetDryMix():Null<FmodWetDryMix>",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_release": {
   "fmod": "FMOD_DSP_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Releases the effect and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_reset": {
   "fmod": "FMOD_DSP_Reset",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Clears the effect's internal state (delay lines, envelopes).",
     "gated": false,
     "name": "reset",
     "signature": "reset():FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setactive": {
   "fmod": "FMOD_DSP_SetActive",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setActive",
     "signature": "setActive(active:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setbypass": {
   "fmod": "FMOD_DSP_SetBypass",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A bypassed effect passes audio through unprocessed.",
     "gated": false,
     "name": "setBypass",
     "signature": "setBypass(bypass:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setcallback": {
   "fmod": "",
   "haxe": [],
   "heading": "DSP::setCallback",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Poll the unit from the game loop with Dsp.getMetering(), Dsp.getFftSpectrumInfo(), or Dsp.getParameterData() instead."
   ]
  },
  "dsp_setchannelformat": {
   "fmod": "FMOD_DSP_SetChannelFormat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Fixes the unit's input format to the given channel mask, channel count, and speaker mode.",
     "gated": false,
     "name": "setChannelFormat",
     "signature": "setChannelFormat(channelMask:FmodChannelMask, channels:Int, speakerMode:FmodSpeakerMode):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setmeteringenabled": {
   "fmod": "FMOD_DSP_SetMeteringEnabled",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Metering must be enabled before getMetering returns data.",
     "gated": false,
     "name": "setMeteringEnabled",
     "signature": "setMeteringEnabled(input:Bool, output:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setparameterbool": {
   "fmod": "FMOD_DSP_SetParameterBool",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setParameterBool",
     "signature": "setParameterBool(index:Int, value:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setparameterdata": {
   "fmod": "FMOD_DSP_SetParameterData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Uploads a data parameter payload (byte layout per the effect's contract, e.g.",
     "gated": false,
     "name": "setParameterData",
     "signature": "setParameterData(index:Int, data:haxe.io.Bytes):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Sets the FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE of a DspType.LOUDNESS_METER unit, its DspLoudnessMeter.WEIGHTING data parameter.",
     "gated": false,
     "name": "setLoudnessMeterWeighting",
     "signature": "setLoudnessMeterWeighting(weighting:FmodDspLoudnessMeterWeightingType):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Sets a data parameter of type FmodDspParameterDataType._3DATTRIBUTES (FMOD_DSP_PARAMETER_3DATTRIBUTES).",
     "gated": false,
     "name": "setParameter3DAttributes",
     "signature": "setParameter3DAttributes(index:Int, absolute:Fmod3DAttributes, ?relative:Fmod3DAttributes):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Sets a data parameter of type FmodDspParameterDataType._3DATTRIBUTES_MULTI (FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI), the position of an object panner or pan unit for every listener.",
     "gated": false,
     "name": "setParameter3DAttributesMulti",
     "signature": "setParameter3DAttributesMulti(index:Int, absolute:Fmod3DAttributes, relative:Array<Fmod3DAttributes>, ?weights:Array<Float>):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Sets a data parameter of type FmodDspParameterDataType.ATTENUATION_RANGE (FMOD_DSP_PARAMETER_ATTENUATION_RANGE), the distance range of a pan or object pan unit.",
     "gated": false,
     "name": "setParameterAttenuationRange",
     "signature": "setParameterAttenuationRange(index:Int, props:FmodDspParameterAttenuationRange):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Sets a data parameter of type FmodDspParameterDataType.FINITE_LENGTH (FMOD_DSP_PARAMETER_FINITE_LENGTH).",
     "gated": false,
     "name": "setParameterFiniteLength",
     "signature": "setParameterFiniteLength(index:Int, props:FmodDspParameterFiniteLength):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "Sets a data parameter of type FmodDspParameterDataType.SIDECHAIN (FMOD_DSP_PARAMETER_SIDECHAIN), for example DspCompressor.USESIDECHAIN.",
     "gated": false,
     "name": "setParameterSidechain",
     "signature": "setParameterSidechain(index:Int, props:FmodDspParameterSidechain):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setparameterfloat": {
   "fmod": "FMOD_DSP_SetParameterFloat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same float write as setParameter under FMOD's name.",
     "gated": false,
     "name": "setParameterFloat",
     "signature": "setParameterFloat(index:Int, value:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "setParameter",
     "signature": "setParameter(index:Int, value:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setparameterint": {
   "fmod": "FMOD_DSP_SetParameterInt",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setParameterInt",
     "signature": "setParameterInt(index:Int, value:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setuserdata": {
   "fmod": "FMOD_DSP_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_setwetdrymix": {
   "fmod": "FMOD_DSP_SetWetDryMix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Scales the pre-effect signal, the processed signal, and the dry signal (each 0..1).",
     "gated": false,
     "name": "setWetDryMix",
     "signature": "setWetDryMix(prewet:Float, postwet:Float, dry:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "dsp_showconfigdialog": {
   "fmod": "",
   "haxe": [],
   "heading": "DSP::showConfigDialog",
   "html5": false,
   "notes": [
    "Cannot be bound. It takes a raw operating system window handle, which has no meaning in Haxe. Plugin and built-in DSP parameters are set through Dsp.setParameter."
   ]
  },
  "dspconnection_getinput": {
   "fmod": "FMOD_DSPConnection_GetInput",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "The DSP feeding this connection (a known DSP returns its existing handle).",
     "gated": false,
     "name": "getInputDsp",
     "signature": "getInputDsp():Dsp",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_getmix": {
   "fmod": "FMOD_DSPConnection_GetMix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Signal scale through this connection (linear, 0.0 = silent, 1.0 = full).",
     "gated": false,
     "name": "getMix",
     "signature": "getMix():Float",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_getmixmatrix": {
   "fmod": "FMOD_DSPConnection_GetMixMatrix",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Reads the mix matrix back as one flat row-major array with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMixMatrix",
     "signature": "getMixMatrix(outChannels:Int = 0, inChannels:Int = 0, inChannelHop:Int = 0):Null<FmodMixMatrix>",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": true
  },
  "dspconnection_getoutput": {
   "fmod": "FMOD_DSPConnection_GetOutput",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getOutputDsp",
     "signature": "getOutputDsp():Dsp",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_gettype": {
   "fmod": "FMOD_DSPConnection_GetType",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The connection's type, STANDARD on failure.",
     "gated": false,
     "name": "getType",
     "signature": "getType():DspConnectionType",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_getuserdata": {
   "fmod": "FMOD_DSPConnection_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_setmix": {
   "fmod": "FMOD_DSPConnection_SetMix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setMix",
     "signature": "setMix(mix:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_setmixmatrix": {
   "fmod": "FMOD_DSPConnection_SetMixMatrix",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes the input's channels to the output's with explicit gains.",
     "gated": false,
     "name": "setMixMatrix",
     "signature": "setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int = 0):FmodResult",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "dspconnection_setuserdata": {
   "fmod": "FMOD_DSPConnection_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.DspConnection"
    }
   ],
   "html5": false
  },
  "file_close": {
   "fmod": "",
   "haxe": [],
   "heading": "file_close",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths."
   ]
  },
  "file_getdiskbusy": {
   "fmod": "FMOD_File_GetDiskBusy",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The global disk busy flag (unsupported in HTML5, false there).",
     "gated": true,
     "name": "getDiskBusy",
     "signature": "getDiskBusy():Bool",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": true
  },
  "file_open": {
   "fmod": "",
   "haxe": [],
   "heading": "file_open",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths."
   ]
  },
  "file_read": {
   "fmod": "",
   "haxe": [],
   "heading": "file_read",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths."
   ]
  },
  "file_seek": {
   "fmod": "",
   "haxe": [],
   "heading": "file_seek",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths."
   ]
  },
  "file_seek_1": {
   "fmod": "",
   "haxe": [],
   "heading": "file_seek",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths."
   ]
  },
  "file_setdiskbusy": {
   "fmod": "FMOD_File_SetDiskBusy",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets FMOD's global disk busy flag (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setDiskBusy",
     "signature": "setDiskBusy(busy:Bool):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": true
  },
  "fmod_android_jni_close": {
   "fmod": "",
   "haxe": [],
   "heading": "FMOD_Android_JNI_Close",
   "html5": false,
   "notes": [
    "Cannot be bound. This is an Android JNI entry point and haxefmod targets desktop and web only."
   ]
  },
  "fmod_android_jni_init": {
   "fmod": "",
   "haxe": [],
   "heading": "FMOD_Android_JNI_Init",
   "html5": false,
   "notes": [
    "Cannot be bound. This is an Android JNI entry point and haxefmod targets desktop and web only."
   ]
  },
  "fs_createpreloadedfile": {
   "fmod": "",
   "haxe": [],
   "heading": "FS_createPreloadedFile",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod does this for you on HTML5."
   ]
  },
  "fsbank_build": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_Build",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_buildcancel": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_BuildCancel",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_fetchfsbmemory": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_FetchFSBMemory",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_fetchnextprogressitem": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_FetchNextProgressItem",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_init": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_Init",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_memorygetstats": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_MemoryGetStats",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_memoryinit": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_MemoryInit",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_release": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_Release",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "fsbank_releaseprogressitem": {
   "fmod": "",
   "haxe": [],
   "heading": "FSBank_ReleaseProgressItem",
   "html5": false,
   "notes": [
    "Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio."
   ]
  },
  "geometry_addpolygon": {
   "fmod": "FMOD_Geometry_AddPolygon",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Adds a convex polygon from at least three vertices in object space and returns its index, -1 on failure (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "addPolygon",
     "signature": "addPolygon(direct:Float, reverb:Float, doubleSided:Bool, vertices:Array<FmodVector>):Int",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "geometry_getactive": {
   "fmod": "FMOD_Geometry_GetActive",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Whether the geometry occludes, false on failure (unsupported in HTML5, false there).",
     "gated": true,
     "name": "getActive",
     "signature": "getActive():Bool",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "geometry_getmaxpolygons": {
   "fmod": "FMOD_Geometry_GetMaxPolygons",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The capacities given at creation, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMaxPolygons",
     "signature": "getMaxPolygons():Null<FmodGeometryMaxPolygons>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_getnumpolygons": {
   "fmod": "FMOD_Geometry_GetNumPolygons",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Polygons added so far, -1 on failure (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "getNumPolygons",
     "signature": "getNumPolygons():Int",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "geometry_getpolygonattributes": {
   "fmod": "FMOD_Geometry_GetPolygonAttributes",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "A polygon's occlusion amounts and sidedness, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getPolygonAttributes",
     "signature": "getPolygonAttributes(index:Int):Null<FmodPolygonAttributes>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_getpolygonnumvertices": {
   "fmod": "FMOD_Geometry_GetPolygonNumVertices",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Vertex count of one polygon, -1 on failure (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "getPolygonNumVertices",
     "signature": "getPolygonNumVertices(index:Int):Int",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "geometry_getpolygonvertex": {
   "fmod": "FMOD_Geometry_GetPolygonVertex",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "One vertex of a polygon, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getPolygonVertex",
     "signature": "getPolygonVertex(index:Int, vertexIndex:Int):Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_getposition": {
   "fmod": "FMOD_Geometry_GetPosition",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The world position, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getPosition",
     "signature": "getPosition():Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_getrotation": {
   "fmod": "FMOD_Geometry_GetRotation",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The forward and up vectors, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getRotation",
     "signature": "getRotation():Null<FmodGeometryRotation>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_getscale": {
   "fmod": "FMOD_Geometry_GetScale",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The per-axis scale, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getScale",
     "signature": "getScale():Null<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_getuserdata": {
   "fmod": "FMOD_Geometry_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "geometry_release": {
   "fmod": "FMOD_Geometry_Release",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Frees the geometry and invalidates this handle (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_save": {
   "fmod": "FMOD_Geometry_Save",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Serializes the geometry for Geometry.load, null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "save",
     "signature": "save():Null<haxe.io.Bytes>",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "geometry_setactive": {
   "fmod": "FMOD_Geometry_SetActive",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Turns the whole geometry's occlusion on or off (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setActive",
     "signature": "setActive(active:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_setpolygonattributes": {
   "fmod": "FMOD_Geometry_SetPolygonAttributes",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Changes a polygon's occlusion amounts and sidedness (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setPolygonAttributes",
     "signature": "setPolygonAttributes(index:Int, direct:Float, reverb:Float, doubleSided:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_setpolygonvertex": {
   "fmod": "FMOD_Geometry_SetPolygonVertex",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves one vertex of a polygon (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setPolygonVertex",
     "signature": "setPolygonVertex(index:Int, vertexIndex:Int, vertex:FmodVector):FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_setposition": {
   "fmod": "FMOD_Geometry_SetPosition",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Places the geometry in world space (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setPosition",
     "signature": "setPosition(position:FmodVector):FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_setrotation": {
   "fmod": "FMOD_Geometry_SetRotation",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Orients the geometry with forward and up unit vectors (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setRotation",
     "signature": "setRotation(forward:FmodVector, up:FmodVector):FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_setscale": {
   "fmod": "FMOD_Geometry_SetScale",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Scales the geometry per axis (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setScale",
     "signature": "setScale(scale:FmodVector):FmodResult",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "geometry_setuserdata": {
   "fmod": "FMOD_Geometry_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "getvalue": {
   "fmod": "",
   "haxe": [],
   "heading": "getValue",
   "html5": false,
   "notes": [
    "Cannot be bound. This reads and writes the wasm heap through a raw address, which has no meaning in Haxe. Values cross into FMOD through the typed haxefmod methods, and getters return values directly."
   ]
  },
  "memory_free": {
   "fmod": "",
   "haxe": [],
   "heading": "Memory_Free",
   "html5": false,
   "notes": [
    "Cannot be bound. It frees a raw pointer from FMOD's heap, which has no meaning in Haxe, and Haxe code never receives one. Release handles with the release() method of the object that created them."
   ]
  },
  "memory_getstats": {
   "fmod": "FMOD_Memory_GetStats",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Bytes FMOD currently has allocated and the most it has ever had.",
     "gated": false,
     "name": "getMemoryStats",
     "signature": "getMemoryStats(blocking:Bool = true):Null<FmodMemoryStats>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "memory_initialize": {
   "fmod": "FMOD_Memory_Initialize",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": true
  },
  "readfile": {
   "fmod": "",
   "haxe": [],
   "heading": "ReadFile",
   "html5": false,
   "notes": [
    "Cannot be bound. It returns a raw wasm heap address, which has no meaning in Haxe. StudioSystem.loadBankMemory() loads a bank from bytes you already hold, and Sound.fromPcm() plays raw PCM you already hold."
   ]
  },
  "reverb3d_get3dattributes": {
   "fmod": "FMOD_Reverb3D_Get3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DAttributes",
     "signature": "get3DAttributes():Null<FmodReverb3DAttributes>",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_getactive": {
   "fmod": "FMOD_Reverb3D_GetActive",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getActive",
     "signature": "getActive():Bool",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_getproperties": {
   "fmod": "FMOD_Reverb3D_GetProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getProperties",
     "signature": "getProperties():Null<ReverbProperties>",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_getuserdata": {
   "fmod": "FMOD_Reverb3D_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_release": {
   "fmod": "FMOD_Reverb3D_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Frees the zone and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_set3dattributes": {
   "fmod": "FMOD_Reverb3D_Set3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Places the zone: full strength inside minDistance, silent past maxDistance.",
     "gated": false,
     "name": "set3DAttributes",
     "signature": "set3DAttributes(x:Float, y:Float, z:Float, minDistance:Float, maxDistance:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_setactive": {
   "fmod": "FMOD_Reverb3D_SetActive",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setActive",
     "signature": "setActive(active:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_setproperties": {
   "fmod": "FMOD_Reverb3D_SetProperties",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setProperties",
     "signature": "setProperties(properties:ReverbProperties):FmodResult",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "reverb3d_setuserdata": {
   "fmod": "FMOD_Reverb3D_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "setvalue": {
   "fmod": "",
   "haxe": [],
   "heading": "setValue",
   "html5": false,
   "notes": [
    "Cannot be bound. This reads and writes the wasm heap through a raw address, which has no meaning in Haxe. Values cross into FMOD through the typed haxefmod methods, and getters return values directly."
   ]
  },
  "sound_addsyncpoint": {
   "fmod": "FMOD_Sound_AddSyncPoint",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Marks a timeline position.",
     "gated": false,
     "name": "addSyncPoint",
     "signature": "addSyncPoint(offset:Int, name:String, offsetType:FmodTimeUnit = FmodTimeUnit.MS):FmodSyncPoint",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_deletesyncpoint": {
   "fmod": "FMOD_Sound_DeleteSyncPoint",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Removes a point.",
     "gated": false,
     "name": "deleteSyncPoint",
     "signature": "deleteSyncPoint(point:FmodSyncPoint):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_get3dconesettings": {
   "fmod": "FMOD_Sound_Get3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DConeSettings",
     "signature": "get3DConeSettings():Null<FmodConeSettings>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_get3dcustomrolloff": {
   "fmod": "FMOD_Sound_Get3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The custom rolloff points (unsupported in HTML5, always empty there), empty when none are set or on failure (see StudioSystem.lastResult).",
     "gated": true,
     "name": "get3DCustomRolloff",
     "signature": "get3DCustomRolloff():Array<FmodVector>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_get3dminmaxdistance": {
   "fmod": "FMOD_Sound_Get3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DMinMaxDistance",
     "signature": "get3DMinMaxDistance():Null<FmodMinMaxDistance>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getdefaults": {
   "fmod": "FMOD_Sound_GetDefaults",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getDefaults",
     "signature": "getDefaults():Null<FmodSoundDefaults>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getformat": {
   "fmod": "FMOD_Sound_GetFormat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Container type, sample format, channel count, and bits per sample, or null on failure.",
     "gated": false,
     "name": "getFormat",
     "signature": "getFormat():Null<FmodSoundFormatInfo>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getlength": {
   "fmod": "FMOD_Sound_GetLength",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Length in unit (milliseconds by default, PCM samples with FmodTimeUnit.PCM), or -1 on failure.",
     "gated": false,
     "name": "getLength",
     "signature": "getLength(unit:FmodTimeUnit = FmodTimeUnit.MS):Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getloopcount": {
   "fmod": "FMOD_Sound_GetLoopCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getLoopCount",
     "signature": "getLoopCount():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getlooppoints": {
   "fmod": "FMOD_Sound_GetLoopPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The loop region, loopStart in loopStartType and loopEnd in loopEndType (milliseconds when left out, a missing loopEndType follows loopStartType), or null on failure.",
     "gated": false,
     "name": "getLoopPoints",
     "signature": "getLoopPoints(loopStartType:FmodTimeUnit = FmodTimeUnit.MS, ?loopEndType:FmodTimeUnit):Null<{loopStart:Int, loopEnd:Int}>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getmode": {
   "fmod": "FMOD_Sound_GetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMode",
     "signature": "getMode():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getmusicchannelvolume": {
   "fmod": "FMOD_Sound_GetMusicChannelVolume",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Volume of one tracker channel (unsupported in HTML5, returns 0 there).",
     "gated": true,
     "name": "getMusicChannelVolume",
     "signature": "getMusicChannelVolume(channel:Int):Float",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_getmusicnumchannels": {
   "fmod": "FMOD_Sound_GetMusicNumChannels",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Channel count of a tracker module (MOD, S3M, XM, IT) (unsupported in HTML5, returns -1 there).",
     "gated": true,
     "name": "getMusicNumChannels",
     "signature": "getMusicNumChannels():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_getmusicspeed": {
   "fmod": "FMOD_Sound_GetMusicSpeed",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback speed of a tracker module (unsupported in HTML5, returns 0 there).",
     "gated": true,
     "name": "getMusicSpeed",
     "signature": "getMusicSpeed():Float",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_getname": {
   "fmod": "FMOD_Sound_GetName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The sound's name (raw memory sounds report an empty name).",
     "gated": false,
     "name": "getName",
     "signature": "getName():String",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getnumsubsounds": {
   "fmod": "FMOD_Sound_GetNumSubSounds",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of subsounds (FSB and multi-stream containers).",
     "gated": false,
     "name": "getNumSubSounds",
     "signature": "getNumSubSounds():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getnumsyncpoints": {
   "fmod": "FMOD_Sound_GetNumSyncPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Alias of getSyncPointCount under FMOD's name.",
     "gated": false,
     "name": "getNumSyncPoints",
     "signature": "getNumSyncPoints():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "Number of sync points, 0 on failure.",
     "gated": false,
     "name": "getSyncPointCount",
     "signature": "getSyncPointCount():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getnumtags": {
   "fmod": "FMOD_Sound_GetNumTags",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of metadata tags, -1 on failure.",
     "gated": false,
     "name": "getNumTags",
     "signature": "getNumTags():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "Tags that changed since the last getTag pass, -1 on failure.",
     "gated": false,
     "name": "getNumTagsUpdated",
     "signature": "getNumTagsUpdated():Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getopenstate": {
   "fmod": "FMOD_Sound_GetOpenState",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The sound's open state, READY once it can play.",
     "gated": false,
     "name": "getOpenState",
     "signature": "getOpenState():FmodOpenState",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "The open state with the streaming details FMOD reports next to it.",
     "gated": false,
     "name": "getOpenStateInfo",
     "signature": "getOpenStateInfo():Null<FmodOpenStateInfo>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getsoundgroup": {
   "fmod": "FMOD_Sound_GetSoundGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The group this sound belongs to (a known group returns its existing handle).",
     "gated": false,
     "name": "getSoundGroup",
     "signature": "getSoundGroup():haxefmod.core.SoundGroup",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getsubsound": {
   "fmod": "FMOD_Sound_GetSubSound",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A subsound by index, or Sound.NULL when the index is out of range (StudioSystem.lastResult reports FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "getSubSound",
     "signature": "getSubSound(index:Int):Sound",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getsubsoundparent": {
   "fmod": "FMOD_Sound_GetSubSoundParent",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The sound this one is a subsound of, or Sound.NULL for a top-level sound (lastResult stays FMOD_OK).",
     "gated": false,
     "name": "getSubSoundParent",
     "signature": "getSubSoundParent():Sound",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getsyncpoint": {
   "fmod": "FMOD_Sound_GetSyncPoint",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "The point at index in offset order, FmodSyncPoint.NULL when the index is out of range (StudioSystem.lastResult reports FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "getSyncPoint",
     "signature": "getSyncPoint(index:Int):FmodSyncPoint",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": true,
     "doc": "The point's name and its offset in offsetType (milliseconds by default), or null when the point does not exist.",
     "gated": false,
     "name": "getSyncPointInfo",
     "signature": "getSyncPointInfo(point:FmodSyncPoint, offsetType:FmodTimeUnit = FmodTimeUnit.MS):Null<{name:String, offset:Int}>",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getSyncPointName",
     "signature": "getSyncPointName(index:Int):String",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getSyncPointOffset",
     "signature": "getSyncPointOffset(index:Int, unit:FmodTimeUnit = FmodTimeUnit.MS):Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getsyncpointinfo": {
   "fmod": "FMOD_Sound_GetSyncPointInfo",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The point's name and its offset in offsetType (milliseconds by default), or null when the point does not exist.",
     "gated": false,
     "name": "getSyncPointInfo",
     "signature": "getSyncPointInfo(point:FmodSyncPoint, offsetType:FmodTimeUnit = FmodTimeUnit.MS):Null<{name:String, offset:Int}>",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "The point at index in offset order, FmodSyncPoint.NULL when the index is out of range (StudioSystem.lastResult reports FMOD_ERR_INVALID_PARAM).",
     "gated": false,
     "name": "getSyncPoint",
     "signature": "getSyncPoint(index:Int):FmodSyncPoint",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getSyncPointName",
     "signature": "getSyncPointName(index:Int):String",
     "static": false,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getSyncPointOffset",
     "signature": "getSyncPointOffset(index:Int, unit:FmodTimeUnit = FmodTimeUnit.MS):Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_getsystemobject": {
   "fmod": "",
   "haxe": [],
   "heading": "Sound::getSystemObject",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back."
   ]
  },
  "sound_gettag": {
   "fmod": "FMOD_Sound_GetTag",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Reads one metadata tag (unsupported in HTML5, returns null there).",
     "gated": true,
     "name": "getTag",
     "signature": "getTag(name:String, index:Int = 0):Null<FmodTag>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_getuserdata": {
   "fmod": "FMOD_Sound_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.PcmStream"
    },
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_lock": {
   "fmod": "FMOD_Sound_Lock",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Locks a byte range of the sample buffer for writing and returns a copy of it (unsupported in HTML5, null there).",
     "gated": true,
     "name": "lock",
     "signature": "lock(offset:Int, length:Int):Null<haxe.io.Bytes>",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_readdata": {
   "fmod": "FMOD_Sound_ReadData",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Reads decoded PCM from a sound created with openOnly into buffer (unsupported in HTML5).",
     "gated": true,
     "name": "readData",
     "signature": "readData(buffer:haxe.io.Bytes, length:Int = -1):Int",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_release": {
   "fmod": "FMOD_Sound_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops playback, frees the stream, and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.PcmStream"
    },
    {
     "direct": true,
     "doc": "Releases the sound and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_seekdata": {
   "fmod": "FMOD_Sound_SeekData",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves the readData cursor to a PCM sample offset (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "seekData",
     "signature": "seekData(pcm:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_set3dconesettings": {
   "fmod": "FMOD_Sound_Set3DConeSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Default 3D cone for channels played from this sound: full volume inside insideAngle, fading to outsideVolume past outsideAngle.",
     "gated": false,
     "name": "set3DConeSettings",
     "signature": "set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_set3dcustomrolloff": {
   "fmod": "FMOD_Sound_Set3DCustomRolloff",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Replaces the distance rolloff curve with the given points.",
     "gated": true,
     "name": "set3DCustomRolloff",
     "signature": "set3DCustomRolloff(points:Array<FmodVector>):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_set3dminmaxdistance": {
   "fmod": "FMOD_Sound_Set3DMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Default rolloff distances for channels played from this sound.",
     "gated": false,
     "name": "set3DMinMaxDistance",
     "signature": "set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_setdefaults": {
   "fmod": "FMOD_Sound_SetDefaults",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Default playback rate (samples per second) and priority (0 = highest, 256 = lowest).",
     "gated": false,
     "name": "setDefaults",
     "signature": "setDefaults(frequency:Float, priority:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_setloopcount": {
   "fmod": "FMOD_Sound_SetLoopCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Times to loop before stopping (-1 = forever).",
     "gated": false,
     "name": "setLoopCount",
     "signature": "setLoopCount(loopCount:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_setlooppoints": {
   "fmod": "FMOD_Sound_SetLoopPoints",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loop region (needs a looping mode set).",
     "gated": false,
     "name": "setLoopPoints",
     "signature": "setLoopPoints(loopStart:Int, loopEnd:Int, loopStartType:FmodTimeUnit = FmodTimeUnit.MS, ?loopEndType:FmodTimeUnit):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_setmode": {
   "fmod": "FMOD_Sound_SetMode",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Combines ChannelMode flags.",
     "gated": false,
     "name": "setMode",
     "signature": "setMode(mode:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_setmusicchannelvolume": {
   "fmod": "FMOD_Sound_SetMusicChannelVolume",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Volume of one tracker channel, 0 to 1 (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setMusicChannelVolume",
     "signature": "setMusicChannelVolume(channel:Int, volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_setmusicspeed": {
   "fmod": "FMOD_Sound_SetMusicSpeed",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback speed of a tracker module, 1 is normal, 0.01 to 100 (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setMusicSpeed",
     "signature": "setMusicSpeed(speed:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "sound_setsoundgroup": {
   "fmod": "FMOD_Sound_SetSoundGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves this sound into a group (see haxefmod.core.SoundGroup).",
     "gated": false,
     "name": "setSoundGroup",
     "signature": "setSoundGroup(group:haxefmod.core.SoundGroup):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_setuserdata": {
   "fmod": "FMOD_Sound_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.PcmStream"
    },
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "sound_unlock": {
   "fmod": "FMOD_Sound_Unlock",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Writes the bytes from lock back into the sample buffer and closes the lock (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "unlock",
     "signature": "unlock(data:haxe.io.Bytes):FmodResult",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": true
  },
  "soundgroup_getmaxaudible": {
   "fmod": "FMOD_SoundGroup_GetMaxAudible",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMaxAudible",
     "signature": "getMaxAudible():Int",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getmaxaudiblebehavior": {
   "fmod": "FMOD_SoundGroup_GetMaxAudibleBehavior",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The current behavior, FAIL on failure.",
     "gated": false,
     "name": "getMaxAudibleBehavior",
     "signature": "getMaxAudibleBehavior():SoundGroupBehavior",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getmutefadespeed": {
   "fmod": "FMOD_SoundGroup_GetMuteFadeSpeed",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMuteFadeSpeed",
     "signature": "getMuteFadeSpeed():Float",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getname": {
   "fmod": "FMOD_SoundGroup_GetName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The name given at create(), \"FMOD master\" for the master group.",
     "gated": false,
     "name": "getName",
     "signature": "getName():String",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getnumplaying": {
   "fmod": "FMOD_SoundGroup_GetNumPlaying",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getPlayingCount under FMOD's name.",
     "gated": false,
     "name": "getNumPlaying",
     "signature": "getNumPlaying():Int",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    },
    {
     "direct": false,
     "doc": "Sounds from this group audible right now.",
     "gated": false,
     "name": "getPlayingCount",
     "signature": "getPlayingCount():Int",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getnumsounds": {
   "fmod": "FMOD_SoundGroup_GetNumSounds",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getSoundCount under FMOD's name.",
     "gated": false,
     "name": "getNumSounds",
     "signature": "getNumSounds():Int",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getSoundCount",
     "signature": "getSoundCount():Int",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getsound": {
   "fmod": "FMOD_SoundGroup_GetSound",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The sound at position index in this group (a known sound returns its existing handle).",
     "gated": false,
     "name": "getSound",
     "signature": "getSound(index:Int):haxefmod.core.Sound",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getsystemobject": {
   "fmod": "",
   "haxe": [],
   "heading": "SoundGroup::getSystemObject",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back."
   ]
  },
  "soundgroup_getuserdata": {
   "fmod": "FMOD_SoundGroup_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_getvolume": {
   "fmod": "FMOD_SoundGroup_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_release": {
   "fmod": "FMOD_SoundGroup_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Frees a group made with create() and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_setmaxaudible": {
   "fmod": "FMOD_SoundGroup_SetMaxAudible",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Most sounds from this group audible at once (-1 = unlimited).",
     "gated": false,
     "name": "setMaxAudible",
     "signature": "setMaxAudible(maxAudible:Int):FmodResult",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_setmaxaudiblebehavior": {
   "fmod": "FMOD_SoundGroup_SetMaxAudibleBehavior",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "What happens to a new sound once the group is at maxAudible.",
     "gated": false,
     "name": "setMaxAudibleBehavior",
     "signature": "setMaxAudibleBehavior(behavior:SoundGroupBehavior):FmodResult",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_setmutefadespeed": {
   "fmod": "FMOD_SoundGroup_SetMuteFadeSpeed",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Fade time in seconds when BEHAVIOR_MUTE kicks in (0 = instant).",
     "gated": false,
     "name": "setMuteFadeSpeed",
     "signature": "setMuteFadeSpeed(seconds:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_setuserdata": {
   "fmod": "FMOD_SoundGroup_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_setvolume": {
   "fmod": "FMOD_SoundGroup_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Volume scale over every sound in the group (linear, 1.0 = full).",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "soundgroup_stop": {
   "fmod": "FMOD_SoundGroup_Stop",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops every playing sound in the group.",
     "gated": false,
     "name": "stop",
     "signature": "stop():FmodResult",
     "static": false,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "studio_bank_getbuscount": {
   "fmod": "FMOD_Studio_Bank_GetBusCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getBusCount",
     "signature": "getBusCount():Int",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getbuslist": {
   "fmod": "FMOD_Studio_Bank_GetBusList",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Buses in the bank (up to Scratch.CAPACITY entries).",
     "gated": false,
     "name": "getBusList",
     "signature": "getBusList():Array<Bus>",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_geteventcount": {
   "fmod": "FMOD_Studio_Bank_GetEventCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of event descriptions in the bank.",
     "gated": false,
     "name": "getEventCount",
     "signature": "getEventCount():Int",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_geteventlist": {
   "fmod": "FMOD_Studio_Bank_GetEventList",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Event descriptions in the bank (up to Scratch.CAPACITY entries).",
     "gated": false,
     "name": "getEventList",
     "signature": "getEventList():Array<EventDescription>",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getid": {
   "fmod": "FMOD_Studio_Bank_GetID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The bank GUID.",
     "gated": false,
     "name": "getID",
     "signature": "getID():FmodGuid",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getloadingstate": {
   "fmod": "FMOD_Studio_Bank_GetLoadingState",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loading state of the bank metadata (poll after NONBLOCKING loads).",
     "gated": false,
     "name": "getLoadingState",
     "signature": "getLoadingState():FmodLoadingState",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getpath": {
   "fmod": "FMOD_Studio_Bank_GetPath",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The full bank path, e.g.",
     "gated": false,
     "name": "getPath",
     "signature": "getPath():String",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getsampleloadingstate": {
   "fmod": "FMOD_Studio_Bank_GetSampleLoadingState",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loading state of the bank's sample data.",
     "gated": false,
     "name": "getSampleLoadingState",
     "signature": "getSampleLoadingState():FmodLoadingState",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getstringcount": {
   "fmod": "FMOD_Studio_Bank_GetStringCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of entries in the bank's string table (strings banks only).",
     "gated": false,
     "name": "getStringCount",
     "signature": "getStringCount():Int",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getstringinfo": {
   "fmod": "FMOD_Studio_Bank_GetStringInfo",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A string table entry's GUID and path together, null for an index out of range.",
     "gated": false,
     "name": "getStringInfo",
     "signature": "getStringInfo(index:Int):Null<FmodBankStringInfo>",
     "static": false,
     "type": "haxefmod.studio.Bank"
    },
    {
     "direct": false,
     "doc": "String table GUID by index.",
     "gated": false,
     "name": "getStringGuid",
     "signature": "getStringGuid(index:Int):FmodGuid",
     "static": false,
     "type": "haxefmod.studio.Bank"
    },
    {
     "direct": false,
     "doc": "String table path by index (e.g.",
     "gated": false,
     "name": "getStringPath",
     "signature": "getStringPath(index:Int):String",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getuserdata": {
   "fmod": "FMOD_Studio_Bank_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getvcacount": {
   "fmod": "FMOD_Studio_Bank_GetVCACount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVCACount",
     "signature": "getVCACount():Int",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_getvcalist": {
   "fmod": "FMOD_Studio_Bank_GetVCAList",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "VCAs in the bank (up to Scratch.CAPACITY entries).",
     "gated": false,
     "name": "getVCAList",
     "signature": "getVCAList():Array<Vca>",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_isvalid": {
   "fmod": "FMOD_Studio_Bank_IsValid",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True if the handle resolves to a live FMOD bank.",
     "gated": false,
     "name": "isValid",
     "signature": "isValid():Bool",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_loadsampledata": {
   "fmod": "FMOD_Studio_Bank_LoadSampleData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loads all non-streaming sample data for the bank's events.",
     "gated": false,
     "name": "loadSampleData",
     "signature": "loadSampleData():FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_setuserdata": {
   "fmod": "FMOD_Studio_Bank_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_unload": {
   "fmod": "FMOD_Studio_Bank_Unload",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Unloads the bank and invalidates this handle (and every event description/instance handle that came from it).",
     "gated": false,
     "name": "unload",
     "signature": "unload():FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bank_unloadsampledata": {
   "fmod": "FMOD_Studio_Bank_UnloadSampleData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "unloadSampleData",
     "signature": "unloadSampleData():FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bank"
    }
   ],
   "html5": false
  },
  "studio_bus_getchannelgroup": {
   "fmod": "FMOD_Studio_Bus_GetChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The core channel group carrying this bus's audio, for attaching DSP effects to Studio-mixed sound.",
     "gated": false,
     "name": "getChannelGroup",
     "signature": "getChannelGroup():haxefmod.core.ChannelGroup",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getcpuusage": {
   "fmod": "FMOD_Studio_Bus_GetCPUUsage",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "CPU usage of this bus, or null on failure.",
     "gated": true,
     "name": "getCpuUsage",
     "signature": "getCpuUsage():Null<FmodCpuUsage>",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getid": {
   "fmod": "FMOD_Studio_Bus_GetID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The bus GUID.",
     "gated": false,
     "name": "getID",
     "signature": "getID():FmodGuid",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getmemoryusage": {
   "fmod": "FMOD_Studio_Bus_GetMemoryUsage",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Memory usage of this bus, or null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMemoryUsage",
     "signature": "getMemoryUsage():Null<FmodMemoryUsage>",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getmute": {
   "fmod": "FMOD_Studio_Bus_GetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getMute",
     "signature": "getMute():Bool",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getpath": {
   "fmod": "FMOD_Studio_Bus_GetPath",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The full bus path, e.g.",
     "gated": false,
     "name": "getPath",
     "signature": "getPath():String",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getpaused": {
   "fmod": "FMOD_Studio_Bus_GetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_getportindex": {
   "fmod": "FMOD_Studio_Bus_GetPortIndex",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The output port this bus is assigned to, FmodPortIndex.NONE when it plays through the main mix (unsupported in HTML5, NONE there).",
     "gated": true,
     "name": "getPortIndex",
     "signature": "getPortIndex():FmodPortIndex",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": true
  },
  "studio_bus_getvolume": {
   "fmod": "FMOD_Studio_Bus_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The volume as set by the API (linear: 0.0 = silent, 1.0 = full).",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.studio.Bus"
    },
    {
     "direct": false,
     "doc": "The final combined volume (set volume x snapshots/automation).",
     "gated": false,
     "name": "getFinalVolume",
     "signature": "getFinalVolume():Float",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_isvalid": {
   "fmod": "FMOD_Studio_Bus_IsValid",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True if the handle resolves to a live FMOD bus.",
     "gated": false,
     "name": "isValid",
     "signature": "isValid():Bool",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_lockchannelgroup": {
   "fmod": "FMOD_Studio_Bus_LockChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Forces the bus's core channel group to exist so effects can attach to it (see getChannelGroup).",
     "gated": false,
     "name": "lockChannelGroup",
     "signature": "lockChannelGroup():FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_setmute": {
   "fmod": "FMOD_Studio_Bus_SetMute",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setMute",
     "signature": "setMute(mute:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_setpaused": {
   "fmod": "FMOD_Studio_Bus_SetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_setportindex": {
   "fmod": "FMOD_Studio_Bus_SetPortIndex",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Assigns this bus to an output port, FmodPortIndex.NONE for the main mix (unsupported in HTML5).",
     "gated": true,
     "name": "setPortIndex",
     "signature": "setPortIndex(index:FmodPortIndex):FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": true
  },
  "studio_bus_setvolume": {
   "fmod": "FMOD_Studio_Bus_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_stopallevents": {
   "fmod": "FMOD_Studio_Bus_StopAllEvents",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops all events routed through this bus.",
     "gated": false,
     "name": "stopAllEvents",
     "signature": "stopAllEvents(stopMode:FmodStopMode = ALLOWFADEOUT):FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_bus_unlockchannelgroup": {
   "fmod": "FMOD_Studio_Bus_UnlockChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "unlockChannelGroup",
     "signature": "unlockChannelGroup():FmodResult",
     "static": false,
     "type": "haxefmod.studio.Bus"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getcommandattime": {
   "fmod": "FMOD_Studio_CommandReplay_GetCommandAtTime",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Index of the command playing at a time in seconds into the capture, -1 on failure.",
     "gated": false,
     "name": "getCommandAtTime",
     "signature": "getCommandAtTime(seconds:Float):Int",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getcommandcount": {
   "fmod": "FMOD_Studio_CommandReplay_GetCommandCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of commands in the capture, -1 on failure.",
     "gated": false,
     "name": "getCommandCount",
     "signature": "getCommandCount():Int",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getcommandinfo": {
   "fmod": "FMOD_Studio_CommandReplay_GetCommandInfo",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Details of the command at index, or null on failure.",
     "gated": false,
     "name": "getCommandInfo",
     "signature": "getCommandInfo(index:Int):Null<FmodCommandInfo>",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getcommandstring": {
   "fmod": "FMOD_Studio_CommandReplay_GetCommandString",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The command at index formatted the way FMOD's tools print it, or \"\" on failure.",
     "gated": false,
     "name": "getCommandString",
     "signature": "getCommandString(index:Int):String",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getcurrentcommand": {
   "fmod": "FMOD_Studio_CommandReplay_GetCurrentCommand",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The index of the command the replay is on and the playback time in seconds, or null on failure.",
     "gated": false,
     "name": "getCurrentCommand",
     "signature": "getCurrentCommand():Null<FmodReplayCommand>",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getlength": {
   "fmod": "FMOD_Studio_CommandReplay_GetLength",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Total capture length in seconds.",
     "gated": false,
     "name": "getLength",
     "signature": "getLength():Float",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getpaused": {
   "fmod": "FMOD_Studio_CommandReplay_GetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getplaybackstate": {
   "fmod": "FMOD_Studio_CommandReplay_GetPlaybackState",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Playback state of the replay, STOPPED on failure.",
     "gated": false,
     "name": "getPlaybackState",
     "signature": "getPlaybackState():FmodPlaybackState",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_getsystem": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::CommandReplay::getSystem",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod has one Studio system, and StudioSystem reaches it directly, so a replay never needs to hand it back."
   ]
  },
  "studio_commandreplay_getuserdata": {
   "fmod": "FMOD_Studio_CommandReplay_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_isvalid": {
   "fmod": "FMOD_Studio_CommandReplay_IsValid",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True while the handle points at a live FMOD replay object.",
     "gated": false,
     "name": "isValid",
     "signature": "isValid():Bool",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_release": {
   "fmod": "FMOD_Studio_CommandReplay_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Frees the replay and invalidates this handle.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_seektocommand": {
   "fmod": "FMOD_Studio_CommandReplay_SeekToCommand",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "seekToCommand",
     "signature": "seekToCommand(index:Int):FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_seektotime": {
   "fmod": "FMOD_Studio_CommandReplay_SeekToTime",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Moves playback to a time in seconds into the capture.",
     "gated": false,
     "name": "seekToTime",
     "signature": "seekToTime(seconds:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_setbankpath": {
   "fmod": "FMOD_Studio_CommandReplay_SetBankPath",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Directory the replay loads banks from when the captured paths no longer apply.",
     "gated": false,
     "name": "setBankPath",
     "signature": "setBankPath(path:String):FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_setcreateinstancecallback": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::CommandReplay::setCreateInstanceCallback",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread."
   ]
  },
  "studio_commandreplay_setframecallback": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::CommandReplay::setFrameCallback",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread."
   ]
  },
  "studio_commandreplay_setloadbankcallback": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::CommandReplay::setLoadBankCallback",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread."
   ]
  },
  "studio_commandreplay_setpaused": {
   "fmod": "FMOD_Studio_CommandReplay_SetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_setuserdata": {
   "fmod": "FMOD_Studio_CommandReplay_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_start": {
   "fmod": "FMOD_Studio_CommandReplay_Start",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "start",
     "signature": "start():FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_commandreplay_stop": {
   "fmod": "FMOD_Studio_CommandReplay_Stop",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "stop",
     "signature": "stop():FmodResult",
     "static": false,
     "type": "haxefmod.studio.CommandReplay"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_createinstance": {
   "fmod": "FMOD_Studio_EventDescription_CreateInstance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Creates a playable instance of this event.",
     "gated": false,
     "name": "createInstance",
     "signature": "createInstance():EventInstance",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getid": {
   "fmod": "FMOD_Studio_EventDescription_GetID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The event GUID.",
     "gated": false,
     "name": "getID",
     "signature": "getID():FmodGuid",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getinstancecount": {
   "fmod": "FMOD_Studio_EventDescription_GetInstanceCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of live instances of this event.",
     "gated": false,
     "name": "getInstanceCount",
     "signature": "getInstanceCount():Int",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getinstancelist": {
   "fmod": "FMOD_Studio_EventDescription_GetInstanceList",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Live instances of this event (up to Scratch.CAPACITY entries).",
     "gated": false,
     "name": "getInstanceList",
     "signature": "getInstanceList():Array<EventInstance>",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getlength": {
   "fmod": "FMOD_Studio_EventDescription_GetLength",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Timeline length in milliseconds.",
     "gated": false,
     "name": "getLength",
     "signature": "getLength():Int",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getminmaxdistance": {
   "fmod": "FMOD_Studio_EventDescription_GetMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Minimum and maximum attenuation distances, or null on failure.",
     "gated": false,
     "name": "getMinMaxDistance",
     "signature": "getMinMaxDistance():Null<FmodEventMinMaxDistance>",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getparameterdescriptionbyid": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::EventDescription::getParameterDescriptionByID",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with EventDescription.getParameterDescriptionByID()."
   ]
  },
  "studio_eventdescription_getparameterdescriptionbyindex": {
   "fmod": "FMOD_Studio_EventDescription_GetParameterDescriptionByIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Parameter description by index, or null on failure.",
     "gated": false,
     "name": "getParameterDescriptionByIndex",
     "signature": "getParameterDescriptionByIndex(index:Int):Null<FmodParameterDescription>",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getparameterdescriptionbyname": {
   "fmod": "FMOD_Studio_EventDescription_GetParameterDescriptionByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Parameter description by name, or null on failure.",
     "gated": false,
     "name": "getParameterDescriptionByName",
     "signature": "getParameterDescriptionByName(name:String):Null<FmodParameterDescription>",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getparameterdescriptioncount": {
   "fmod": "FMOD_Studio_EventDescription_GetParameterDescriptionCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of parameters on this event.",
     "gated": false,
     "name": "getParameterDescriptionCount",
     "signature": "getParameterDescriptionCount():Int",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getparameterlabelbyid": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::EventDescription::getParameterLabelByID",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with EventDescription.getParameterLabelByID()."
   ]
  },
  "studio_eventdescription_getparameterlabelbyindex": {
   "fmod": "FMOD_Studio_EventDescription_GetParameterLabelByIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Label text for a labeled parameter at a description index, \"\" when the index or the label is out of range.",
     "gated": false,
     "name": "getParameterLabelByIndex",
     "signature": "getParameterLabelByIndex(index:Int, labelIndex:Int):String",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getparameterlabelbyname": {
   "fmod": "FMOD_Studio_EventDescription_GetParameterLabelByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Label text for a labeled parameter named by name, the same call as getParameterLabel under FMOD's name.",
     "gated": false,
     "name": "getParameterLabelByName",
     "signature": "getParameterLabelByName(name:String, labelIndex:Int):String",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    },
    {
     "direct": false,
     "doc": "Label text for a labeled parameter's value index (e.g.",
     "gated": false,
     "name": "getParameterLabel",
     "signature": "getParameterLabel(parameterName:String, labelIndex:Int):String",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getpath": {
   "fmod": "FMOD_Studio_EventDescription_GetPath",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The full event path, e.g.",
     "gated": false,
     "name": "getPath",
     "signature": "getPath():String",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getsampleloadingstate": {
   "fmod": "FMOD_Studio_EventDescription_GetSampleLoadingState",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getSampleLoadingState",
     "signature": "getSampleLoadingState():FmodLoadingState",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getsoundsize": {
   "fmod": "FMOD_Studio_EventDescription_GetSoundSize",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Estimated non-streaming sample data size in bytes.",
     "gated": false,
     "name": "getSoundSize",
     "signature": "getSoundSize():Float",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getuserdata": {
   "fmod": "FMOD_Studio_EventDescription_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getuserproperty": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::EventDescription::getUserProperty",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. EventDescription.getUserProperty(name) walks the properties FMOD reports by index and returns the one with that name, so the same FmodUserProperty comes back as from FMOD's lookup by name."
   ]
  },
  "studio_eventdescription_getuserpropertybyindex": {
   "fmod": "FMOD_Studio_EventDescription_GetUserPropertyByIndex",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "User property by index, or null on failure.",
     "gated": false,
     "name": "getUserPropertyByIndex",
     "signature": "getUserPropertyByIndex(index:Int):Null<FmodUserProperty>",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_getuserpropertycount": {
   "fmod": "FMOD_Studio_EventDescription_GetUserPropertyCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of user properties authored on the event.",
     "gated": false,
     "name": "getUserPropertyCount",
     "signature": "getUserPropertyCount():Int",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_hassustainpoint": {
   "fmod": "FMOD_Studio_EventDescription_HasSustainPoint",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "hasSustainPoint",
     "signature": "hasSustainPoint():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_is3d": {
   "fmod": "FMOD_Studio_EventDescription_Is3D",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "is3D",
     "signature": "is3D():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_isdopplerenabled": {
   "fmod": "FMOD_Studio_EventDescription_IsDopplerEnabled",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isDopplerEnabled",
     "signature": "isDopplerEnabled():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_isoneshot": {
   "fmod": "FMOD_Studio_EventDescription_IsOneshot",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isOneshot",
     "signature": "isOneshot():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_issnapshot": {
   "fmod": "FMOD_Studio_EventDescription_IsSnapshot",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isSnapshot",
     "signature": "isSnapshot():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_isstream": {
   "fmod": "FMOD_Studio_EventDescription_IsStream",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isStream",
     "signature": "isStream():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_isvalid": {
   "fmod": "FMOD_Studio_EventDescription_IsValid",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isValid",
     "signature": "isValid():Bool",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_loadsampledata": {
   "fmod": "FMOD_Studio_EventDescription_LoadSampleData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loads non-streaming sample data ahead of time (refcounted by FMOD).",
     "gated": false,
     "name": "loadSampleData",
     "signature": "loadSampleData():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_releaseallinstances": {
   "fmod": "FMOD_Studio_EventDescription_ReleaseAllInstances",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops and releases all instances of this event.",
     "gated": false,
     "name": "releaseAllInstances",
     "signature": "releaseAllInstances():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_setcallback": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::EventDescription::setCallback",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with EventDescription.setCallback(handler, ?mask), which remembers a handler that createInstance installs on every instance made from the description from then on."
   ]
  },
  "studio_eventdescription_setuserdata": {
   "fmod": "FMOD_Studio_EventDescription_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventdescription_unloadsampledata": {
   "fmod": "FMOD_Studio_EventDescription_UnloadSampleData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "unloadSampleData",
     "signature": "unloadSampleData():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventDescription"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_get3dattributes": {
   "fmod": "FMOD_Studio_EventInstance_Get3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The instance's 3D attributes, or null on failure.",
     "gated": false,
     "name": "get3DAttributes",
     "signature": "get3DAttributes():Null<Fmod3DAttributes>",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getchannelgroup": {
   "fmod": "FMOD_Studio_EventInstance_GetChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The core channel group carrying this instance's audio, for attaching DSP effects to a single event.",
     "gated": false,
     "name": "getChannelGroup",
     "signature": "getChannelGroup():haxefmod.core.ChannelGroup",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getcpuusage": {
   "fmod": "FMOD_Studio_EventInstance_GetCPUUsage",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "CPU usage of this instance, or null on failure.",
     "gated": true,
     "name": "getCpuUsage",
     "signature": "getCpuUsage():Null<FmodCpuUsage>",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getdescription": {
   "fmod": "FMOD_Studio_EventInstance_GetDescription",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The description this instance was created from.",
     "gated": false,
     "name": "getDescription",
     "signature": "getDescription():EventDescription",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getlistenermask": {
   "fmod": "FMOD_Studio_EventInstance_GetListenerMask",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Bitmask of listeners this instance is audible to.",
     "gated": false,
     "name": "getListenerMask",
     "signature": "getListenerMask():Int",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getmemoryusage": {
   "fmod": "FMOD_Studio_EventInstance_GetMemoryUsage",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Memory usage of this instance, or null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMemoryUsage",
     "signature": "getMemoryUsage():Null<FmodMemoryUsage>",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getminmaxdistance": {
   "fmod": "FMOD_Studio_EventInstance_GetMinMaxDistance",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Minimum and maximum attenuation distances, or null on failure.",
     "gated": false,
     "name": "getMinMaxDistance",
     "signature": "getMinMaxDistance():Null<FmodEventMinMaxDistance>",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getparameterbyid": {
   "fmod": "FMOD_Studio_EventInstance_GetParameterByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getParameterByID",
     "signature": "getParameterByID(id:FmodParameterId):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameterByIDFinal",
     "signature": "getParameterByIDFinal(id:FmodParameterId):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getparameterbyname": {
   "fmod": "FMOD_Studio_EventInstance_GetParameterByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same parameter read as getParameter, under FMOD's name.",
     "gated": false,
     "name": "getParameterByName",
     "signature": "getParameterByName(name:String):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameter",
     "signature": "getParameter(name:String):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "The final value of a parameter after automation and seek speed, by name.",
     "gated": false,
     "name": "getParameterByNameFinal",
     "signature": "getParameterByNameFinal(name:String):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "The final parameter value after automation/seek speed.",
     "gated": false,
     "name": "getParameterFinal",
     "signature": "getParameterFinal(name:String):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getpaused": {
   "fmod": "FMOD_Studio_EventInstance_GetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPaused",
     "signature": "getPaused():Bool",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getpitch": {
   "fmod": "FMOD_Studio_EventInstance_GetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPitch",
     "signature": "getPitch():Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getFinalPitch",
     "signature": "getFinalPitch():Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getplaybackstate": {
   "fmod": "FMOD_Studio_EventInstance_GetPlaybackState",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getPlaybackState",
     "signature": "getPlaybackState():FmodPlaybackState",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getproperty": {
   "fmod": "FMOD_Studio_EventInstance_GetProperty",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "An overridable instance property (see FmodEventProperty).",
     "gated": false,
     "name": "getProperty",
     "signature": "getProperty(property:FmodEventProperty):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getreverblevel": {
   "fmod": "FMOD_Studio_EventInstance_GetReverbLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Core reverb send level for reverb instance 0-3.",
     "gated": false,
     "name": "getReverbLevel",
     "signature": "getReverbLevel(index:Int):Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getsystem": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::EventInstance::getSystem",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod has one Studio system, and StudioSystem reaches it directly, so an instance never needs to hand it back."
   ]
  },
  "studio_eventinstance_gettimelineposition": {
   "fmod": "FMOD_Studio_EventInstance_GetTimelinePosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Timeline position in milliseconds.",
     "gated": false,
     "name": "getTimelinePosition",
     "signature": "getTimelinePosition():Int",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getuserdata": {
   "fmod": "FMOD_Studio_EventInstance_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_getvolume": {
   "fmod": "FMOD_Studio_EventInstance_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "The final combined volume (set volume x event/snapshot automation).",
     "gated": false,
     "name": "getFinalVolume",
     "signature": "getFinalVolume():Float",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_isvalid": {
   "fmod": "FMOD_Studio_EventInstance_IsValid",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "isValid",
     "signature": "isValid():Bool",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_isvirtual": {
   "fmod": "FMOD_Studio_EventInstance_IsVirtual",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True if the instance has been virtualized (inaudible, not mixed).",
     "gated": false,
     "name": "isVirtual",
     "signature": "isVirtual():Bool",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_keyoff": {
   "fmod": "FMOD_Studio_EventInstance_KeyOff",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Advances past the current sustain point.",
     "gated": false,
     "name": "keyOff",
     "signature": "keyOff():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_release": {
   "fmod": "FMOD_Studio_EventInstance_Release",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Releases the instance.",
     "gated": false,
     "name": "release",
     "signature": "release():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_set3dattributes": {
   "fmod": "FMOD_Studio_EventInstance_Set3DAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "set3DAttributes",
     "signature": "set3DAttributes(attributes:Fmod3DAttributes):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "Convenience for 2D games: position only, unit forward/up.",
     "gated": false,
     "name": "setPosition2D",
     "signature": "setPosition2D(x:Float, y:Float, ?velocityX:Float = 0, ?velocityY:Float = 0):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setcallback": {
   "fmod": "FMOD_Studio_EventInstance_SetCallback",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Registers a typed payload callback for this instance (replaces any existing handler.",
     "name": "setCallback",
     "signature": "setCallback(handler:EventCallback, ?mask:Int):Void",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "Assigns the audio-table key (or file path fallback) this instance's programmer instrument should play (unsupported in HTML5).",
     "gated": true,
     "name": "assignProgrammerSound",
     "signature": "assignProgrammerSound(key:String):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "Maps one programmer instrument name to the audio table key or file path it should play (unsupported in HTML5).",
     "gated": true,
     "name": "assignProgrammerSoundForName",
     "signature": "assignProgrammerSoundForName(name:String, key:String):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "Hands a sound the game owns to this instance's programmer instrument (unsupported in HTML5).",
     "gated": true,
     "name": "assignProgrammerSoundFrom",
     "signature": "assignProgrammerSoundFrom(sound:haxefmod.core.Sound, subsoundIndex:Int = -1):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "Removes every programmer-sound assignment, key, game sound, and names (unsupported in HTML5, where nothing can be assigned).",
     "gated": true,
     "name": "clearProgrammerSound",
     "signature": "clearProgrammerSound():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": true
  },
  "studio_eventinstance_setlistenermask": {
   "fmod": "FMOD_Studio_EventInstance_SetListenerMask",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setListenerMask",
     "signature": "setListenerMask(mask:Int):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setparameterbyid": {
   "fmod": "FMOD_Studio_EventInstance_SetParameterByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setParameterByID",
     "signature": "setParameterByID(id:FmodParameterId, value:Float, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setparameterbyidwithlabel": {
   "fmod": "FMOD_Studio_EventInstance_SetParameterByIDWithLabel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setParameterByIDWithLabel",
     "signature": "setParameterByIDWithLabel(id:FmodParameterId, label:String, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setparameterbyname": {
   "fmod": "FMOD_Studio_EventInstance_SetParameterByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same parameter write as setParameter, under FMOD's name.",
     "gated": false,
     "name": "setParameterByName",
     "signature": "setParameterByName(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "setParameter",
     "signature": "setParameter(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setparameterbynamewithlabel": {
   "fmod": "FMOD_Studio_EventInstance_SetParameterByNameWithLabel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same labeled write as setParameterWithLabel, under FMOD's name.",
     "gated": false,
     "name": "setParameterByNameWithLabel",
     "signature": "setParameterByNameWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    },
    {
     "direct": false,
     "doc": "Sets a labeled parameter by label text (e.g.",
     "gated": false,
     "name": "setParameterWithLabel",
     "signature": "setParameterWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setparametersbyids": {
   "fmod": "FMOD_Studio_EventInstance_SetParametersByIDs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets several parameters on this instance in one call.",
     "gated": false,
     "name": "setParametersByIDs",
     "signature": "setParametersByIDs(ids:Array<FmodParameterId>, values:Array<Float>, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setpaused": {
   "fmod": "FMOD_Studio_EventInstance_SetPaused",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPaused",
     "signature": "setPaused(paused:Bool):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setpitch": {
   "fmod": "FMOD_Studio_EventInstance_SetPitch",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setPitch",
     "signature": "setPitch(pitch:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setproperty": {
   "fmod": "FMOD_Studio_EventInstance_SetProperty",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setProperty",
     "signature": "setProperty(property:FmodEventProperty, value:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setreverblevel": {
   "fmod": "FMOD_Studio_EventInstance_SetReverbLevel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setReverbLevel",
     "signature": "setReverbLevel(index:Int, level:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_settimelineposition": {
   "fmod": "FMOD_Studio_EventInstance_SetTimelinePosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setTimelinePosition",
     "signature": "setTimelinePosition(positionMs:Int):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setuserdata": {
   "fmod": "FMOD_Studio_EventInstance_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to this handle.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_setvolume": {
   "fmod": "FMOD_Studio_EventInstance_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_start": {
   "fmod": "FMOD_Studio_EventInstance_Start",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "start",
     "signature": "start():FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_eventinstance_stop": {
   "fmod": "FMOD_Studio_EventInstance_Stop",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "stop",
     "signature": "stop(stopMode:FmodStopMode = ALLOWFADEOUT):FmodResult",
     "static": false,
     "type": "haxefmod.studio.EventInstance"
    }
   ],
   "html5": false
  },
  "studio_parseid": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::parseID",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. FmodGuid.fromString parses the braced text into a FmodGuid, and a plain String converts on its own."
   ]
  },
  "studio_system_create": {
   "fmod": "FMOD_Studio_System_Create",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "studio_system_flushcommands": {
   "fmod": "FMOD_Studio_System_FlushCommands",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Blocks until all pending commands have executed.",
     "gated": false,
     "name": "flushCommands",
     "signature": "flushCommands():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_flushsampleloading": {
   "fmod": "FMOD_Studio_System_FlushSampleLoading",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Blocks until all sample loading/unloading has completed.",
     "gated": false,
     "name": "flushSampleLoading",
     "signature": "flushSampleLoading():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getadvancedsettings": {
   "fmod": "FMOD_Studio_System_GetAdvancedSettings",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "The studio advanced settings FMOD is running with, or null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getStudioAdvancedSettings",
     "signature": "getStudioAdvancedSettings():Null<FmodStudioAdvancedSettings>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "studio_system_getbank": {
   "fmod": "FMOD_Studio_System_GetBank",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Looks up a loaded bank by path (e.g.",
     "gated": false,
     "name": "getBank",
     "signature": "getBank(path:String):Bank",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getbankbyid": {
   "fmod": "FMOD_Studio_System_GetBankByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getBankByID",
     "signature": "getBankByID(guid:FmodGuid):Bank",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getbankcount": {
   "fmod": "FMOD_Studio_System_GetBankCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of loaded banks.",
     "gated": false,
     "name": "getBankCount",
     "signature": "getBankCount():Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getbanklist": {
   "fmod": "FMOD_Studio_System_GetBankList",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loaded banks (up to Scratch.CAPACITY entries).",
     "gated": false,
     "name": "getBankList",
     "signature": "getBankList():Array<Bank>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getbufferusage": {
   "fmod": "FMOD_Studio_System_GetBufferUsage",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Studio internal buffer usage, or null on failure.",
     "gated": false,
     "name": "getBufferUsage",
     "signature": "getBufferUsage():Null<FmodBufferUsage>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getbus": {
   "fmod": "FMOD_Studio_System_GetBus",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Looks up a bus by path (e.g.",
     "gated": false,
     "name": "getBus",
     "signature": "getBus(path:String):Bus",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "name": "GetBusMute",
     "signature": "GetBusMute(busPath:String):Bool",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "",
     "name": "GetBusVolume",
     "signature": "GetBusVolume(busPath:String):Float",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "",
     "name": "SetBusMute",
     "signature": "SetBusMute(busPath:String, mute:Bool):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "",
     "name": "SetBusVolume",
     "signature": "SetBusVolume(busPath:String, volume:Float):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "",
     "name": "StopAllSounds",
     "signature": "StopAllSounds():Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Mutes or unmutes the master bus.",
     "name": "muteAll",
     "signature": "muteAll(muted:Bool):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    },
    {
     "direct": false,
     "doc": "Pauses or unpauses everything routed through the master bus.",
     "name": "pauseAll",
     "signature": "pauseAll(paused:Bool):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "studio_system_getbusbyid": {
   "fmod": "FMOD_Studio_System_GetBusByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Looks up a bus by GUID.",
     "gated": false,
     "name": "getBusByID",
     "signature": "getBusByID(guid:FmodGuid):Bus",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getcoresystem": {
   "fmod": "FMOD_Studio_System_GetCoreSystem",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "studio_system_getcpuusage": {
   "fmod": "FMOD_Studio_System_GetCPUUsage",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "System-wide CPU usage, or null on failure.",
     "gated": false,
     "name": "getCpuUsage",
     "signature": "getCpuUsage():Null<FmodSystemCpuUsage>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getevent": {
   "fmod": "FMOD_Studio_System_GetEvent",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Looks up an event description by path (e.g.",
     "gated": false,
     "name": "getEvent",
     "signature": "getEvent(path:String):EventDescription",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Creates an instance of an event.",
     "name": "createInstance",
     "signature": "createInstance(eventPath:String):EventInstance",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "studio_system_geteventbyid": {
   "fmod": "FMOD_Studio_System_GetEventByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Looks up an event description by GUID.",
     "gated": false,
     "name": "getEventByID",
     "signature": "getEventByID(guid:FmodGuid):EventDescription",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getlistenerattributes": {
   "fmod": "FMOD_Studio_System_GetListenerAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "A listener's 3D attributes and its attenuation position, or null on failure.",
     "gated": false,
     "name": "getListenerAttributes",
     "signature": "getListenerAttributes(index:Int):Null<FmodListenerAttributes>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "name": "update",
     "signature": "update():Void",
     "static": false,
     "type": "haxefmod.runtime.EmitterTracker"
    }
   ],
   "html5": false
  },
  "studio_system_getlistenerweight": {
   "fmod": "FMOD_Studio_System_GetListenerWeight",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getListenerWeight",
     "signature": "getListenerWeight(index:Int):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getmemoryusage": {
   "fmod": "FMOD_Studio_System_GetMemoryUsage",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "System-wide memory usage, or null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getMemoryUsage",
     "signature": "getMemoryUsage():Null<FmodMemoryUsage>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getnumlisteners": {
   "fmod": "FMOD_Studio_System_GetNumListeners",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getNumListeners",
     "signature": "getNumListeners():Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getparameterbyid": {
   "fmod": "FMOD_Studio_System_GetParameterByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getParameterByID",
     "signature": "getParameterByID(id:FmodParameterId):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameterByIDFinal",
     "signature": "getParameterByIDFinal(id:FmodParameterId):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getparameterbyname": {
   "fmod": "FMOD_Studio_System_GetParameterByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same global parameter read as getParameter, under FMOD's name.",
     "gated": false,
     "name": "getParameterByName",
     "signature": "getParameterByName(name:String):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameter",
     "signature": "getParameter(name:String):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "The final value of a global parameter after automation and seek speed, by name.",
     "gated": false,
     "name": "getParameterByNameFinal",
     "signature": "getParameterByNameFinal(name:String):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getParameterFinal",
     "signature": "getParameterFinal(name:String):Float",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getparameterdescriptionbyid": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::System::getParameterDescriptionByID",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getParameterDescriptionByID()."
   ]
  },
  "studio_system_getparameterdescriptionbyname": {
   "fmod": "FMOD_Studio_System_GetParameterDescriptionByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Global parameter description by name, or null on failure.",
     "gated": false,
     "name": "getParameterDescriptionByName",
     "signature": "getParameterDescriptionByName(name:String):Null<FmodParameterDescription>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getparameterdescriptioncount": {
   "fmod": "FMOD_Studio_System_GetParameterDescriptionCount",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Number of global parameters.",
     "gated": false,
     "name": "getParameterDescriptionCount",
     "signature": "getParameterDescriptionCount():Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getparameterdescriptionlist": {
   "fmod": "FMOD_Studio_System_GetParameterDescriptionList",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Global parameter description by index, or null on failure.",
     "gated": false,
     "name": "getParameterDescriptionByIndex",
     "signature": "getParameterDescriptionByIndex(index:Int):Null<FmodParameterDescription>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getparameterlabelbyid": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::System::getParameterLabelByID",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getParameterLabelByID()."
   ]
  },
  "studio_system_getparameterlabelbyname": {
   "fmod": "FMOD_Studio_System_GetParameterLabelByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Label text for a labeled global parameter named by name, the same call as getParameterLabel under FMOD's name.",
     "gated": false,
     "name": "getParameterLabelByName",
     "signature": "getParameterLabelByName(name:String, labelIndex:Int):String",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Label text for a labeled global parameter's value index.",
     "gated": false,
     "name": "getParameterLabel",
     "signature": "getParameterLabel(parameterName:String, labelIndex:Int):String",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getsoundinfo": {
   "fmod": "FMOD_Studio_System_GetSoundInfo",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "What FMOD would load for an audio table key: the file it reports (empty for a bank held in memory), the ChannelMode flags, where the sample sits in that file, and the subsound index inside it.",
     "gated": false,
     "name": "getSoundInfo",
     "signature": "getSoundInfo(key:String):Null<FmodSoundInfo>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getuserdata": {
   "fmod": "FMOD_Studio_System_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getvca": {
   "fmod": "FMOD_Studio_System_GetVCA",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Looks up a VCA by path (e.g.",
     "gated": false,
     "name": "getVCA",
     "signature": "getVCA(path:String):Vca",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_getvcabyid": {
   "fmod": "FMOD_Studio_System_GetVCAByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getVCAByID",
     "signature": "getVCAByID(guid:FmodGuid):Vca",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_initialize": {
   "fmod": "FMOD_Studio_System_Initialize",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "heading": "Studio::System::initialize",
   "html5": false,
   "notes": [
    "No Haxe declaration, the library owns this choice. FmodManager.Initialize(settings) makes this call. maxchannels is FmodSettings.numChannels, studioflags come from liveUpdate and memoryTracking, flags come from the core fields (for example rightHanded3D and profiling), and extradriverdata is never passed."
   ]
  },
  "studio_system_isvalid": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::System::isValid",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with FmodManager.IsInitialized(), which reports true once the Studio system and the default banks are usable."
   ]
  },
  "studio_system_loadbankcustom": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::System::loadBankCustom",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD_STUDIO_BANK_INFO is declared as haxefmod.studio.Types.FmodStudioBankInfo (size, userData, userDataLength), but the load itself needs the four file callbacks the struct carries, and FMOD runs those on its streaming and loading threads, where no Haxe target can execute code. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths."
   ]
  },
  "studio_system_loadbankfile": {
   "fmod": "FMOD_Studio_System_LoadBankFile",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loads a bank file.",
     "gated": false,
     "name": "loadBankFile",
     "signature": "loadBankFile(path:String, flags:FmodLoadBankFlags = NORMAL):Bank",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_loadbankmemory": {
   "fmod": "FMOD_Studio_System_LoadBankMemory",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loads a bank from bytes (embedded, downloaded, or packed banks).",
     "gated": false,
     "name": "loadBankMemory",
     "signature": "loadBankMemory(data:haxe.io.Bytes, flags:FmodLoadBankFlags = NORMAL):Bank",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_loadcommandreplay": {
   "fmod": "FMOD_Studio_System_LoadCommandReplay",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Loads a capture file for playback.",
     "gated": false,
     "name": "loadCommandReplay",
     "signature": "loadCommandReplay(path:String, flags:FmodCommandReplayFlags = NORMAL):CommandReplay",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_lookupid": {
   "fmod": "FMOD_Studio_System_LookupID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Resolves a path to its GUID (\"\" on failure.",
     "gated": false,
     "name": "lookupID",
     "signature": "lookupID(path:String):FmodGuid",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_lookuppath": {
   "fmod": "FMOD_Studio_System_LookupPath",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Resolves a GUID to its path (\"\" on failure.",
     "gated": false,
     "name": "lookupPath",
     "signature": "lookupPath(guid:FmodGuid):String",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_registerplugin": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::System::registerPlugin",
   "html5": false,
   "notes": [
    "Cannot be bound. It takes a DSP description struct whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, which makes its effects available to Studio events."
   ]
  },
  "studio_system_release": {
   "fmod": "FMOD_Studio_System_Release",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "heading": "Studio::System::release",
   "html5": false,
   "notes": [
    "No Haxe declaration, the library owns this choice. There is no shutdown call. FmodManager.Initialize() creates the system once and FMOD is released when the process exits, so banks, instances, and handles need no teardown order at quit."
   ]
  },
  "studio_system_resetbufferusage": {
   "fmod": "FMOD_Studio_System_ResetBufferUsage",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "resetBufferUsage",
     "signature": "resetBufferUsage():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setadvancedsettings": {
   "fmod": "FMOD_Studio_System_SetAdvancedSettings",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "studio_system_setcallback": {
   "fmod": "FMOD_Studio_System_SetCallback",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Removes the system callback handler and both native callbacks.",
     "name": "clearSystemCallback",
     "signature": "clearSystemCallback():Void",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Installs a handler for system events (device changes from the core system, bank unloads and Live Update connections from Studio).",
     "name": "setSystemCallback",
     "signature": "setSystemCallback(handler:SystemCallback, ?coreMask:Int, ?studioMask:Int):Void",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Removes the handler and both native callbacks.",
     "gated": false,
     "name": "clear",
     "signature": "clear():Void",
     "static": true,
     "type": "haxefmod.studio.SystemCallbacks"
    },
    {
     "direct": false,
     "doc": "Installs the handler and tells FMOD which events to raise.",
     "gated": false,
     "name": "set",
     "signature": "set(handler:SystemCallback, ?coreMask:Int, ?studioMask:Int):Void",
     "static": true,
     "type": "haxefmod.studio.SystemCallbacks"
    },
    {
     "direct": false,
     "doc": "Removes every registered callback (song, sounds, descriptions, core channels, the system, and PCM streams).",
     "name": "ClearAllCallbacks",
     "signature": "ClearAllCallbacks():Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    }
   ],
   "html5": false
  },
  "studio_system_setlistenerattributes": {
   "fmod": "FMOD_Studio_System_SetListenerAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets a listener's 3D attributes.",
     "gated": false,
     "name": "setListenerAttributes",
     "signature": "setListenerAttributes(index:Int, attributes:Fmod3DAttributes, ?attenuationPosition:FmodVector):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Convenience for 2D games: listener position only, unit forward/up.",
     "gated": false,
     "name": "setListenerPosition2D",
     "signature": "setListenerPosition2D(index:Int, x:Float, y:Float, velocityX:Float = 0, velocityY:Float = 0):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Positions a listener in 2D space (index 0 unless using multiple listeners).",
     "name": "setListenerPosition",
     "signature": "setListenerPosition(index:Int, x:Float, y:Float):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    },
    {
     "direct": false,
     "doc": "",
     "name": "update",
     "signature": "update():Void",
     "static": false,
     "type": "haxefmod.runtime.ListenerTracker"
    }
   ],
   "html5": false
  },
  "studio_system_setlistenerweight": {
   "fmod": "FMOD_Studio_System_SetListenerWeight",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setListenerWeight",
     "signature": "setListenerWeight(index:Int, weight:Float):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setnumlisteners": {
   "fmod": "FMOD_Studio_System_SetNumListeners",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setNumListeners",
     "signature": "setNumListeners(count:Int):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setparameterbyid": {
   "fmod": "FMOD_Studio_System_SetParameterByID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setParameterByID",
     "signature": "setParameterByID(id:FmodParameterId, value:Float, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setparameterbyidwithlabel": {
   "fmod": "FMOD_Studio_System_SetParameterByIDWithLabel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setParameterByIDWithLabel",
     "signature": "setParameterByIDWithLabel(id:FmodParameterId, label:String, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setparameterbyname": {
   "fmod": "FMOD_Studio_System_SetParameterByName",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same global parameter write as setParameter, under FMOD's name.",
     "gated": false,
     "name": "setParameterByName",
     "signature": "setParameterByName(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "setParameter",
     "signature": "setParameter(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setparameterbynamewithlabel": {
   "fmod": "FMOD_Studio_System_SetParameterByNameWithLabel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same labeled write as setParameterWithLabel, under FMOD's name.",
     "gated": false,
     "name": "setParameterByNameWithLabel",
     "signature": "setParameterByNameWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "setParameterWithLabel",
     "signature": "setParameterWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setparametersbyids": {
   "fmod": "FMOD_Studio_System_SetParametersByIDs",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets several global parameters in one call.",
     "gated": false,
     "name": "setParametersByIDs",
     "signature": "setParametersByIDs(ids:Array<FmodParameterId>, values:Array<Float>, ignoreSeekSpeed:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_setuserdata": {
   "fmod": "FMOD_Studio_System_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to the studio system.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_startcommandcapture": {
   "fmod": "FMOD_Studio_System_StartCommandCapture",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Records every API command to a file until stopCommandCapture, for FMOD's analysis tools or replay through loadCommandReplay.",
     "gated": false,
     "name": "startCommandCapture",
     "signature": "startCommandCapture(path:String, flags:FmodCommandCaptureFlags = NORMAL):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_stopcommandcapture": {
   "fmod": "FMOD_Studio_System_StopCommandCapture",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "stopCommandCapture",
     "signature": "stopCommandCapture():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_unloadall": {
   "fmod": "FMOD_Studio_System_UnloadAll",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Unloads all banks.",
     "gated": false,
     "name": "unloadAll",
     "signature": "unloadAll():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "studio_system_unregisterplugin": {
   "fmod": "",
   "haxe": [],
   "heading": "Studio::System::unregisterPlugin",
   "html5": false,
   "notes": [
    "Cannot be bound. It names a plugin registered from a description struct, and that registration cannot be bound because its callbacks would run on FMOD's mixer thread. A plugin loaded with StudioSystem.loadPlugin is unloaded with StudioSystem.unloadPlugin."
   ]
  },
  "studio_system_update": {
   "fmod": "FMOD_Studio_System_Update",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Services FMOD: delivers callbacks, updates attached instances, and drives song transitions.",
     "name": "Update",
     "signature": "Update():Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": true,
     "doc": "Services FMOD: drains the callback queue and pushes attached-instance positions.",
     "gated": false,
     "name": "update",
     "signature": "update():Void",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "PauseSong",
     "signature": "PauseSong():Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    }
   ],
   "html5": false
  },
  "studio_vca_getid": {
   "fmod": "FMOD_Studio_VCA_GetID",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The VCA GUID.",
     "gated": false,
     "name": "getID",
     "signature": "getID():FmodGuid",
     "static": false,
     "type": "haxefmod.studio.Vca"
    }
   ],
   "html5": false
  },
  "studio_vca_getpath": {
   "fmod": "FMOD_Studio_VCA_GetPath",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The full VCA path, e.g.",
     "gated": false,
     "name": "getPath",
     "signature": "getPath():String",
     "static": false,
     "type": "haxefmod.studio.Vca"
    }
   ],
   "html5": false
  },
  "studio_vca_getvolume": {
   "fmod": "FMOD_Studio_VCA_GetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The volume as set by the API (linear: 0.0 = silent, 1.0 = full).",
     "gated": false,
     "name": "getVolume",
     "signature": "getVolume():Float",
     "static": false,
     "type": "haxefmod.studio.Vca"
    },
    {
     "direct": false,
     "doc": "The final combined volume (set volume x snapshots/automation).",
     "gated": false,
     "name": "getFinalVolume",
     "signature": "getFinalVolume():Float",
     "static": false,
     "type": "haxefmod.studio.Vca"
    }
   ],
   "html5": false
  },
  "studio_vca_isvalid": {
   "fmod": "FMOD_Studio_VCA_IsValid",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "True if the handle resolves to a live FMOD VCA.",
     "gated": false,
     "name": "isValid",
     "signature": "isValid():Bool",
     "static": false,
     "type": "haxefmod.studio.Vca"
    }
   ],
   "html5": false
  },
  "studio_vca_setvolume": {
   "fmod": "FMOD_Studio_VCA_SetVolume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "setVolume",
     "signature": "setVolume(volume:Float):FmodResult",
     "static": false,
     "type": "haxefmod.studio.Vca"
    }
   ],
   "html5": false
  },
  "system_attachchannelgrouptoport": {
   "fmod": "FMOD_System_AttachChannelGroupToPort",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Routes a channel group to a console output port (unsupported in HTML5, FMOD_ERR_UNSUPPORTED there).",
     "gated": true,
     "name": "attachChannelGroupToPort",
     "signature": "attachChannelGroupToPort(portType:FmodPortType, portIndex:FmodPortIndex, group:ChannelGroup, passThru:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": true
  },
  "system_attachfilesystem": {
   "fmod": "",
   "haxe": [],
   "heading": "System::attachFileSystem",
   "html5": false,
   "notes": [
    "Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths."
   ]
  },
  "system_close": {
   "fmod": "",
   "haxe": [],
   "heading": "System::close",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod owns this."
   ]
  },
  "system_create": {
   "fmod": "",
   "haxe": [],
   "heading": "System_Create",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod calls this for you."
   ]
  },
  "system_createchannelgroup": {
   "fmod": "FMOD_System_CreateChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates a custom group.",
     "gated": false,
     "name": "create",
     "signature": "create(name:String):ChannelGroup",
     "static": true,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "system_createdsp": {
   "fmod": "",
   "haxe": [],
   "heading": "System::createDSP",
   "html5": false,
   "notes": [
    "Cannot be bound. A DSP description is a struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can execute code there. All 33 built-in DSP types are created with Dsp.create(type), and a unit from a loaded plugin with Dsp.createByPlugin(handle)."
   ]
  },
  "system_createdspbyplugin": {
   "fmod": "FMOD_System_CreateDSPByPlugin",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates an effect unit from a plugin loaded with StudioSystem.loadPlugin (unsupported in HTML5, returns Dsp.NULL there).",
     "gated": true,
     "name": "createByPlugin",
     "signature": "createByPlugin(pluginHandle:Int):Dsp",
     "static": true,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "system_createdspbytype": {
   "fmod": "FMOD_System_CreateDSPByType",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates an effect unit.",
     "gated": false,
     "name": "create",
     "signature": "create(type:DspType):Dsp",
     "static": true,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "system_createdspconnection": {
   "fmod": "",
   "haxe": [],
   "heading": "System::createDSPConnection",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with Dsp.addInput(), which connects two units and returns the DspConnection for the link."
   ]
  },
  "system_creategeometry": {
   "fmod": "FMOD_System_CreateGeometry",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates an empty geometry with room for the given polygon and vertex counts (unsupported in HTML5).",
     "gated": true,
     "name": "create",
     "signature": "create(maxPolygons:Int, maxVertices:Int):Geometry",
     "static": true,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "system_createreverb3d": {
   "fmod": "FMOD_System_CreateReverb3D",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates a zone.",
     "gated": false,
     "name": "create",
     "signature": "create():Reverb3D",
     "static": true,
     "type": "haxefmod.core.Reverb3D"
    }
   ],
   "html5": false
  },
  "system_createsound": {
   "fmod": "FMOD_System_CreateSound",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates a stream.",
     "gated": false,
     "name": "create",
     "signature": "create(sampleRate:Int, channels:Int, ringBytes:Int = 0):PcmStream",
     "static": true,
     "type": "haxefmod.core.PcmStream"
    },
    {
     "direct": false,
     "doc": "Like create() but positional: the channel from play() accepts set3DAttributes and attenuates with distance from the listener.",
     "gated": false,
     "name": "create3d",
     "signature": "create3d(sampleRate:Int, channels:Int, ringBytes:Int = 0):PcmStream",
     "static": true,
     "type": "haxefmod.core.PcmStream"
    },
    {
     "direct": false,
     "doc": "Loads a sound file.",
     "gated": false,
     "name": "create",
     "signature": "create(path:String, loop:Bool = false, openOnly:Bool = false, mode:Int = 0, initialSubsound:Int = -1, ?exinfo:FmodCreateSoundExInfo):Sound",
     "static": true,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "An empty PCM16 sound of the given length for StudioSystem.recordStart to fill (unsupported in HTML5).",
     "gated": true,
     "name": "createRecordBuffer",
     "signature": "createRecordBuffer(sampleRate:Int, channels:Int, seconds:Int):Sound",
     "static": true,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "A sound from an encoded file image in memory (wav, ogg, mp3, fsb, anything Sound.create would load from disk).",
     "gated": false,
     "name": "fromMemory",
     "signature": "fromMemory(data:haxe.io.Bytes, mode:Int = 0, length:Int = -1, ?exinfo:FmodCreateSoundExInfo):Sound",
     "static": true,
     "type": "haxefmod.core.Sound"
    },
    {
     "direct": false,
     "doc": "A sound from raw 16-bit PCM in memory (interleaved when stereo).",
     "gated": false,
     "name": "fromPcm",
     "signature": "fromPcm(data:haxe.io.Bytes, sampleRate:Int, channels:Int, length:Int = -1):Sound",
     "static": true,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "system_createsoundgroup": {
   "fmod": "FMOD_System_CreateSoundGroup",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Creates a group.",
     "gated": false,
     "name": "create",
     "signature": "create(name:String):SoundGroup",
     "static": true,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "system_createstream": {
   "fmod": "",
   "haxe": [],
   "heading": "System::createStream",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers streams two ways."
   ]
  },
  "system_detachchannelgroupfromport": {
   "fmod": "FMOD_System_DetachChannelGroupFromPort",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Takes a channel group off its output port again (unsupported in HTML5, FMOD_ERR_UNSUPPORTED there).",
     "gated": true,
     "name": "detachChannelGroupFromPort",
     "signature": "detachChannelGroupFromPort(group:ChannelGroup):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": true
  },
  "system_get3dlistenerattributes": {
   "fmod": "",
   "haxe": [],
   "heading": "System::get3DListenerAttributes",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getListenerAttributes()."
   ]
  },
  "system_get3dnumlisteners": {
   "fmod": "",
   "haxe": [],
   "heading": "System::get3DNumListeners",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getNumListeners()."
   ]
  },
  "system_get3dsettings": {
   "fmod": "FMOD_System_Get3DSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "get3DSettings",
     "signature": "get3DSettings():Null<Fmod3DSettings>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getadvancedsettings": {
   "fmod": "FMOD_System_GetAdvancedSettings",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The core advanced settings FMOD is running with, or null on failure (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getAdvancedSettings",
     "signature": "getAdvancedSettings():Null<FmodAdvancedSettings>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_getchannel": {
   "fmod": "FMOD_System_GetChannel",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The pool channel at index (see Channel.getIndex).",
     "gated": false,
     "name": "getChannel",
     "signature": "getChannel(index:Int):Channel",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getchannelsplaying": {
   "fmod": "FMOD_System_GetChannelsPlaying",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Playing channel counts, or null on failure.",
     "gated": false,
     "name": "getChannelsPlaying",
     "signature": "getChannelsPlaying():Null<FmodChannelsPlaying>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getcpuusage": {
   "fmod": "",
   "haxe": [],
   "heading": "System::getCPUUsage",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getCpuUsage(), which returns the core mixer, stream, geometry, update, and convolution figures next to the Studio update time."
   ]
  },
  "system_getdefaultmixmatrix": {
   "fmod": "FMOD_System_GetDefaultMixMatrix",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "FMOD's default upmix or downmix matrix between two FMOD_SPEAKERMODE values, row-major with one row per target channel (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getDefaultMixMatrix",
     "signature": "getDefaultMixMatrix(sourceSpeakerMode:FmodSpeakerMode, targetSpeakerMode:FmodSpeakerMode, matrixHop:Int = 0):Null<Array<Float>>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getdriver": {
   "fmod": "FMOD_System_GetDriver",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "getDriver",
     "signature": "getDriver():Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getdriverinfo": {
   "fmod": "FMOD_System_GetDriverInfo",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Name, GUID, native rate, speaker mode, and channel count of an output driver (see getDriverCount).",
     "gated": false,
     "name": "getDriverInfo",
     "signature": "getDriverInfo(index:Int):Null<FmodDriverInfo>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getDriverName",
     "signature": "getDriverName(index:Int):String",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getdspbuffersize": {
   "fmod": "FMOD_System_GetDSPBufferSize",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The mixer buffer FMOD runs with, samples per buffer and buffer count, or null before init.",
     "gated": false,
     "name": "getDSPBufferSize",
     "signature": "getDSPBufferSize():Null<FmodDspBufferSize>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getdspinfobyplugin": {
   "fmod": "FMOD_System_GetDSPInfoByPlugin",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "The description a DSP plugin registered, its name, version, buffer counts and parameter count (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getPluginInfo",
     "signature": "getPluginInfo(pluginHandle:Int):Null<FmodDspDescriptionInfo>",
     "static": true,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "system_getdspinfobytype": {
   "fmod": "FMOD_System_GetDSPInfoByType",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The description FMOD registered for a built-in effect type, its name, version, buffer counts and parameter count (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getDspInfoByType",
     "signature": "getDspInfoByType(type:DspType):Null<FmodDspDescriptionInfo>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": true
  },
  "system_getfileusage": {
   "fmod": "FMOD_System_GetFileUsage",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Bytes FMOD has read from disk since init, split by sample loads, streams, and everything else (banks, plugins).",
     "gated": false,
     "name": "getFileUsage",
     "signature": "getFileUsage():Null<FmodFileUsage>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getgeometryocclusion": {
   "fmod": "FMOD_System_GetGeometryOcclusion",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "The occlusion every active geometry applies between a listener and a source position (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getOcclusion",
     "signature": "getOcclusion(listener:FmodVector, source:FmodVector):Null<FmodOcclusion>",
     "static": true,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "system_getgeometrysettings": {
   "fmod": "FMOD_System_GetGeometrySettings",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "The current world size, 0 on failure (unsupported in HTML5, 0 there).",
     "gated": true,
     "name": "getWorldSize",
     "signature": "getWorldSize():Float",
     "static": true,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "system_getmasterchannelgroup": {
   "fmod": "FMOD_System_GetMasterChannelGroup",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "The master group (the final mix).",
     "gated": false,
     "name": "master",
     "signature": "master():ChannelGroup",
     "static": true,
     "type": "haxefmod.core.ChannelGroup"
    }
   ],
   "html5": false
  },
  "system_getmastersoundgroup": {
   "fmod": "FMOD_System_GetMasterSoundGroup",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "The master group every sound starts in.",
     "gated": false,
     "name": "master",
     "signature": "master():SoundGroup",
     "static": true,
     "type": "haxefmod.core.SoundGroup"
    }
   ],
   "html5": false
  },
  "system_getnestedplugin": {
   "fmod": "FMOD_System_GetNestedPlugin",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The handle of one plugin inside a loaded library (unsupported in HTML5, 0 there).",
     "gated": true,
     "name": "getNestedPlugin",
     "signature": "getNestedPlugin(handle:Int, index:Int):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getnetworkproxy": {
   "fmod": "FMOD_System_GetNetworkProxy",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The proxy set by setNetworkProxy, \"\" when none is set or on failure.",
     "gated": false,
     "name": "getNetworkProxy",
     "signature": "getNetworkProxy():String",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getnetworktimeout": {
   "fmod": "FMOD_System_GetNetworkTimeout",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The network timeout in milliseconds, -1 on failure.",
     "gated": false,
     "name": "getNetworkTimeout",
     "signature": "getNetworkTimeout():Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getnumdrivers": {
   "fmod": "FMOD_System_GetNumDrivers",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getDriverCount under FMOD's name.",
     "gated": false,
     "name": "getNumDrivers",
     "signature": "getNumDrivers():Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    },
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "getDriverCount",
     "signature": "getDriverCount():Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getnumnestedplugins": {
   "fmod": "FMOD_System_GetNumNestedPlugins",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getNestedPluginCount under FMOD's name (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "getNumNestedPlugins",
     "signature": "getNumNestedPlugins(handle:Int):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "The number of plugins a loaded library contains, 1 for a plain plugin (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "getNestedPluginCount",
     "signature": "getNestedPluginCount(handle:Int):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getnumplugins": {
   "fmod": "FMOD_System_GetNumPlugins",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The same count as getPluginCount under FMOD's name (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "getNumPlugins",
     "signature": "getNumPlugins(type:FmodPluginType):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "The number of plugins of one type, built-in ones included (unsupported in HTML5, -1 there).",
     "gated": true,
     "name": "getPluginCount",
     "signature": "getPluginCount(type:FmodPluginType):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getoutput": {
   "fmod": "FMOD_System_GetOutput",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The active output type (FMOD_OUTPUTTYPE), -1 on failure.",
     "gated": false,
     "name": "getOutput",
     "signature": "getOutput():FmodOutputType",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getoutputbyplugin": {
   "fmod": "FMOD_System_GetOutputByPlugin",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The plugin handle of the output mode in use, 0 on failure.",
     "gated": false,
     "name": "getOutputByPlugin",
     "signature": "getOutputByPlugin():Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getoutputhandle": {
   "fmod": "",
   "haxe": [],
   "heading": "System::getOutputHandle",
   "html5": false,
   "notes": [
    "Cannot be bound. It returns a raw operating system pointer, which has no meaning in Haxe. Output device selection goes through CoreSystem.getDriverCount, getDriverName, and setDriver."
   ]
  },
  "system_getpluginhandle": {
   "fmod": "FMOD_System_GetPluginHandle",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The plugin handle at an index within one type (unsupported in HTML5, 0 there).",
     "gated": true,
     "name": "getPluginHandle",
     "signature": "getPluginHandle(type:FmodPluginType, index:Int):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getplugininfo": {
   "fmod": "FMOD_System_GetPluginInfo",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The name, type and version a plugin registered (unsupported in HTML5, null there).",
     "gated": true,
     "name": "getPluginInfo",
     "signature": "getPluginInfo(handle:Int):Null<FmodPluginInfo>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getrecorddriverinfo": {
   "fmod": "FMOD_System_GetRecordDriverInfo",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Name, GUID, and native format of a record driver (unsupported in HTML5, returns null there).",
     "gated": true,
     "name": "getRecordDriverInfo",
     "signature": "getRecordDriverInfo(id:Int):Null<FmodRecordDriverInfo>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_getrecordnumdrivers": {
   "fmod": "FMOD_System_GetRecordNumDrivers",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "Record drivers FMOD can see (unsupported in HTML5, returns null there).",
     "gated": true,
     "name": "getRecordDriverCount",
     "signature": "getRecordDriverCount():Null<FmodRecordDriverCount>",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_getrecordposition": {
   "fmod": "FMOD_System_GetRecordPosition",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "The record cursor in PCM samples, or -1 on failure (unsupported in HTML5, always -1 there).",
     "gated": true,
     "name": "getRecordPosition",
     "signature": "getRecordPosition(id:Int):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_getreverbproperties": {
   "fmod": "FMOD_System_GetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "get",
     "signature": "get(instance:Int):Null<ReverbProperties>",
     "static": true,
     "type": "haxefmod.core.Reverb"
    }
   ],
   "html5": false
  },
  "system_getsoftwarechannels": {
   "fmod": "FMOD_System_GetSoftwareChannels",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The audible voice cap FMOD runs with, 0 before init.",
     "gated": false,
     "name": "getSoftwareChannels",
     "signature": "getSoftwareChannels():Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getsoftwareformat": {
   "fmod": "FMOD_System_GetSoftwareFormat",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The mixer's output format, or null on failure.",
     "gated": false,
     "name": "getSoftwareFormat",
     "signature": "getSoftwareFormat():Null<FmodSoftwareFormat>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getspeakermodechannels": {
   "fmod": "FMOD_System_GetSpeakerModeChannels",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Speaker count of a speaker mode, 0 on failure.",
     "gated": false,
     "name": "getSpeakerModeChannels",
     "signature": "getSpeakerModeChannels(speakerMode:FmodSpeakerMode):Int",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getspeakerposition": {
   "fmod": "FMOD_System_GetSpeakerPosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The position set for one speaker (see setSpeakerPosition), or null on failure.",
     "gated": false,
     "name": "getSpeakerPosition",
     "signature": "getSpeakerPosition(speaker:FmodSpeaker):Null<FmodSpeakerPosition>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getstreambuffersize": {
   "fmod": "FMOD_System_GetStreamBufferSize",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The file stream buffer FMOD runs with and the unit it is in, or null before init.",
     "gated": false,
     "name": "getStreamBufferSize",
     "signature": "getStreamBufferSize():Null<FmodStreamBufferSize>",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_getuserdata": {
   "fmod": "FMOD_System_GetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The value attached with setUserData, or null.",
     "gated": false,
     "name": "getUserData",
     "signature": "getUserData():Dynamic",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_getversion": {
   "fmod": "FMOD_System_GetVersion",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "The linked FMOD version as \"2.03.12\", or \"\" on failure.",
     "gated": false,
     "name": "getVersion",
     "signature": "getVersion():String",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_init": {
   "fmod": "",
   "haxe": [],
   "heading": "System::init",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod calls this for you."
   ]
  },
  "system_isrecording": {
   "fmod": "FMOD_System_IsRecording",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "True while a driver is recording (unsupported in HTML5, always false there).",
     "gated": true,
     "name": "isRecording",
     "signature": "isRecording(id:Int):Bool",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_loadgeometry": {
   "fmod": "FMOD_System_LoadGeometry",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "Rebuilds a geometry from the bytes save() produced (unsupported in HTML5).",
     "gated": true,
     "name": "load",
     "signature": "load(data:haxe.io.Bytes):Geometry",
     "static": true,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": false
  },
  "system_loadplugin": {
   "fmod": "FMOD_System_LoadPlugin",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Loads a plugin shared library and returns FMOD's plugin handle (unsupported in HTML5, returns 0 there).",
     "gated": true,
     "name": "loadPlugin",
     "signature": "loadPlugin(path:String, priority:Int = 0):Int",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_lockdsp": {
   "fmod": "FMOD_System_LockDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Holds the mixer until unlockDsp so several graph edits (adding, removing, or reconnecting DSPs) land in one mixer update instead of being heard one at a time.",
     "gated": false,
     "name": "lockDsp",
     "signature": "lockDsp():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_mixerresume": {
   "fmod": "FMOD_System_MixerResume",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "",
     "gated": false,
     "name": "mixerResume",
     "signature": "mixerResume():FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_mixersuspend": {
   "fmod": "FMOD_System_MixerSuspend",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops the mixer entirely (for app backgrounding on platforms that demand silence).",
     "gated": false,
     "name": "mixerSuspend",
     "signature": "mixerSuspend():FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_playdsp": {
   "fmod": "FMOD_System_PlayDSP",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Plays this DSP as a sound source (e.g.",
     "gated": false,
     "name": "play",
     "signature": "play(startPaused:Bool = false, ?group:ChannelGroup):Channel",
     "static": false,
     "type": "haxefmod.core.Dsp"
    }
   ],
   "html5": false
  },
  "system_playsound": {
   "fmod": "FMOD_System_PlaySound",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Starts playback.",
     "gated": false,
     "name": "play",
     "signature": "play(startPaused:Bool = false, ?group:ChannelGroup):Channel",
     "static": false,
     "type": "haxefmod.core.PcmStream"
    },
    {
     "direct": false,
     "doc": "Starts playback.",
     "gated": false,
     "name": "play",
     "signature": "play(startPaused:Bool = false, ?group:haxefmod.core.ChannelGroup):haxefmod.core.Channel",
     "static": false,
     "type": "haxefmod.core.Sound"
    }
   ],
   "html5": false
  },
  "system_recordstart": {
   "fmod": "FMOD_System_RecordStart",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Starts recording a driver into a sound from Sound.createRecordBuffer (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "recordStart",
     "signature": "recordStart(id:Int, sound:Sound, loop:Bool = false):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_recordstop": {
   "fmod": "FMOD_System_RecordStop",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Stops recording on a driver (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "recordStop",
     "signature": "recordStop(id:Int):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_registercodec": {
   "fmod": "",
   "haxe": [],
   "heading": "System::registerCodec",
   "html5": false,
   "notes": [
    "Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create."
   ]
  },
  "system_registerdsp": {
   "fmod": "",
   "haxe": [],
   "heading": "System::registerDSP",
   "html5": false,
   "notes": [
    "Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create."
   ]
  },
  "system_registeroutput": {
   "fmod": "",
   "haxe": [],
   "heading": "System::registerOutput",
   "html5": false,
   "notes": [
    "Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create."
   ]
  },
  "system_release": {
   "fmod": "",
   "haxe": [],
   "heading": "System::release",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod owns this."
   ]
  },
  "system_set3dlistenerattributes": {
   "fmod": "",
   "haxe": [],
   "heading": "System::set3DListenerAttributes",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.setListenerPosition2D() for 2D games and StudioSystem.setListenerAttributes() for the full struct."
   ]
  },
  "system_set3dnumlisteners": {
   "fmod": "",
   "haxe": [],
   "heading": "System::set3DNumListeners",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.setNumListeners()."
   ]
  },
  "system_set3drolloffcallback": {
   "fmod": "",
   "haxe": [],
   "heading": "System::set3DRolloffCallback",
   "html5": false,
   "notes": [
    "Cannot be bound. FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Channel.set3DCustomRolloff takes a curve of points instead, and the built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode."
   ]
  },
  "system_set3dsettings": {
   "fmod": "FMOD_System_Set3DSettings",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Global 3D scale factors: doppler strength, world units per meter, and how aggressively sounds attenuate with distance.",
     "gated": false,
     "name": "set3DSettings",
     "signature": "set3DSettings(dopplerScale:Float, distanceFactor:Float, rolloffScale:Float):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_setadvancedsettings": {
   "fmod": "FMOD_System_SetAdvancedSettings",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "system_setcallback": {
   "fmod": "FMOD_System_SetCallback",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Removes the system callback handler and both native callbacks.",
     "name": "clearSystemCallback",
     "signature": "clearSystemCallback():Void",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Installs a handler for system events (device changes from the core system, bank unloads and Live Update connections from Studio).",
     "name": "setSystemCallback",
     "signature": "setSystemCallback(handler:SystemCallback, ?coreMask:Int, ?studioMask:Int):Void",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    },
    {
     "direct": false,
     "doc": "Removes the handler and both native callbacks.",
     "gated": false,
     "name": "clear",
     "signature": "clear():Void",
     "static": true,
     "type": "haxefmod.studio.SystemCallbacks"
    },
    {
     "direct": false,
     "doc": "Installs the handler and tells FMOD which events to raise.",
     "gated": false,
     "name": "set",
     "signature": "set(handler:SystemCallback, ?coreMask:Int, ?studioMask:Int):Void",
     "static": true,
     "type": "haxefmod.studio.SystemCallbacks"
    },
    {
     "direct": false,
     "doc": "Removes every registered callback (song, sounds, descriptions, core channels, the system, and PCM streams).",
     "name": "ClearAllCallbacks",
     "signature": "ClearAllCallbacks():Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    }
   ],
   "html5": false
  },
  "system_setdriver": {
   "fmod": "FMOD_System_SetDriver",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Switches the output device (see getDriverCount/getDriverName).",
     "gated": false,
     "name": "setDriver",
     "signature": "setDriver(index:Int):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_setdspbuffersize": {
   "fmod": "FMOD_System_SetDSPBufferSize",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "system_setfilesystem": {
   "fmod": "",
   "haxe": [],
   "heading": "System::setFileSystem",
   "html5": false,
   "notes": [
    "Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths."
   ]
  },
  "system_setgeometrysettings": {
   "fmod": "FMOD_System_SetGeometrySettings",
   "gated": true,
   "haxe": [
    {
     "direct": false,
     "doc": "The largest world size the occlusion calculation handles (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setWorldSize",
     "signature": "setWorldSize(maxWorldSize:Float):FmodResult",
     "static": true,
     "type": "haxefmod.core.Geometry"
    }
   ],
   "html5": true
  },
  "system_setnetworkproxy": {
   "fmod": "FMOD_System_SetNetworkProxy",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Proxy for FMOD's own network streams, as \"host:port\" (\"user:pass@host:port\" with credentials).",
     "gated": false,
     "name": "setNetworkProxy",
     "signature": "setNetworkProxy(proxy:String):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_setnetworktimeout": {
   "fmod": "FMOD_System_SetNetworkTimeout",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Timeout in milliseconds for FMOD's own network streams.",
     "gated": false,
     "name": "setNetworkTimeout",
     "signature": "setNetworkTimeout(ms:Int):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_setoutput": {
   "fmod": "FMOD_System_SetOutput",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "system_setoutputbyplugin": {
   "fmod": "FMOD_System_SetOutputByPlugin",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Selects the output mode by plugin handle.",
     "gated": false,
     "name": "setOutputByPlugin",
     "signature": "setOutputByPlugin(handle:Int):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_setpluginpath": {
   "fmod": "FMOD_System_SetPluginPath",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Sets the directory FMOD searches for plugins given by file name (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "setPluginPath",
     "signature": "setPluginPath(path:String):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_setreverbproperties": {
   "fmod": "FMOD_System_SetReverbProperties",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "",
     "gated": false,
     "name": "set",
     "signature": "set(instance:Int, properties:ReverbProperties):FmodResult",
     "static": true,
     "type": "haxefmod.core.Reverb"
    }
   ],
   "html5": false
  },
  "system_setsoftwarechannels": {
   "fmod": "FMOD_System_SetSoftwareChannels",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "system_setsoftwareformat": {
   "fmod": "FMOD_System_SetSoftwareFormat",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "system_setspeakerposition": {
   "fmod": "FMOD_System_SetSpeakerPosition",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Where one output speaker sits for panning, as x (left -1 to right 1) and y (back -1 to front 1), and whether it is fed at all.",
     "gated": false,
     "name": "setSpeakerPosition",
     "signature": "setSpeakerPosition(speaker:FmodSpeaker, x:Float, y:Float, active:Bool):FmodResult",
     "static": true,
     "type": "haxefmod.core.CoreSystem"
    }
   ],
   "html5": false
  },
  "system_setstreambuffersize": {
   "fmod": "FMOD_System_SetStreamBufferSize",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": false
  },
  "system_setuserdata": {
   "fmod": "FMOD_System_SetUserData",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Attaches a Haxe value to the studio system.",
     "gated": false,
     "name": "setUserData",
     "signature": "setUserData(value:Dynamic):Void",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_unloadplugin": {
   "fmod": "FMOD_System_UnloadPlugin",
   "gated": true,
   "haxe": [
    {
     "direct": true,
     "doc": "Unloads a plugin from loadPlugin (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED).",
     "gated": true,
     "name": "unloadPlugin",
     "signature": "unloadPlugin(handle:Int):FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": true
  },
  "system_unlockdsp": {
   "fmod": "FMOD_System_UnlockDSP",
   "gated": false,
   "haxe": [
    {
     "direct": true,
     "doc": "Releases the mixer held by lockDsp.",
     "gated": false,
     "name": "unlockDsp",
     "signature": "unlockDsp():FmodResult",
     "static": true,
     "type": "haxefmod.studio.StudioSystem"
    }
   ],
   "html5": false
  },
  "system_update": {
   "fmod": "",
   "haxe": [],
   "heading": "System::update",
   "html5": false,
   "notes": [
    "No Haxe declaration, another call plays this role. haxefmod calls this for you."
   ]
  },
  "thread_setattributes": {
   "fmod": "FMOD_Thread_SetAttributes",
   "gated": false,
   "haxe": [
    {
     "direct": false,
     "doc": "Initializes FMOD.",
     "name": "Initialize",
     "signature": "Initialize(?settings:FmodSettings):Void",
     "static": true,
     "type": "haxefmod.FmodManager"
    },
    {
     "direct": false,
     "doc": "Initializes FMOD with the given settings (see FmodSettings for the define-driven defaults).",
     "gated": false,
     "name": "init",
     "signature": "init(?settings:FmodSettings):FmodResult",
     "static": true,
     "type": "haxefmod.runtime.FmodRuntime"
    }
   ],
   "html5": true
  }
 },
 "fmod": "2.03.12",
 "haxefmod": "3.0.0"
};

// Generated by ci/haxe-catalog.py from extension/haxe/*.md.
// Do not edit by hand.
const HAXEFMOD_EXAMPLES = {
 "advanced-core-api-topics": {
  "10.2 Extracting PCM Data from a Sound": {
   "code": "var sound = Sound.create(\"drumloop.wav\", false, true); // openOnly, like FMOD_OPENONLY\nvar length = sound.getLength(FmodTimeUnit.RAWBYTES);\n\nvar buffer = haxe.io.Bytes.alloc(length);\nvar read = sound.readData(buffer);",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.studio.Types",
   "verdict": "bound"
  },
  "10.7.1 3D Reverbs": {
   "code": "var reverb = Reverb3D.create();\nvar prop2 = Reverb.PRESET_CONCERTHALL;\nreverb.setProperties(prop2);",
   "notes": [],
   "type": "haxefmod.core.Reverb, haxefmod.core.Reverb3D",
   "verdict": "bound"
  },
  "10.7.1 3D Reverbs#2": {
   "code": "var reverb = Reverb3D.create();\nvar pos = {x: -10.0, y: 0.0, z: 0.0};\nvar mindist = 10.0;\nvar maxdist = 20.0;\nreverb.set3DAttributes(pos.x, pos.y, pos.z, mindist, maxdist);",
   "notes": [],
   "type": "haxefmod.core.Reverb3D",
   "verdict": "bound"
  },
  "10.7.1 3D Reverbs#3": {
   "code": "var listenerpos = {x: 0.0, y: 0.0, z: -1.0};\nStudioSystem.setListenerAttributes(0, {\n    position: listenerpos,\n    velocity: {x: 0.0, y: 0.0, z: 0.0},\n    forward: {x: 0.0, y: 0.0, z: 1.0},\n    up: {x: 0.0, y: 1.0, z: 0.0}\n});",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "10.7.2 Using Multiple Reverbs": {
   "code": "var prop1 = Reverb.PRESET_HALLWAY;\nvar prop2 = Reverb.PRESET_SEWERPIPE;\nvar prop3 = Reverb.PRESET_PARKINGLOT;\nvar prop4 = Reverb.PRESET_CONCERTHALL;",
   "notes": [],
   "type": "haxefmod.core.Reverb",
   "verdict": "bound"
  },
  "10.7.2 Using Multiple Reverbs#2": {
   "code": "var result = Reverb.set(0, prop1);\nresult = Reverb.set(1, prop2);\nresult = Reverb.set(2, prop3);\nresult = Reverb.set(3, prop4);",
   "notes": [],
   "type": "haxefmod.core.Reverb",
   "verdict": "bound"
  },
  "10.7.2 Using Multiple Reverbs#3": {
   "code": "var prop = Reverb.get(3);",
   "notes": [],
   "type": "haxefmod.core.Reverb",
   "verdict": "bound"
  },
  "10.7.2 Using Multiple Reverbs#4": {
   "code": "var result = channel.setReverbWet(1, 0.0);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "10.7.2 Using Multiple Reverbs#5": {
   "code": "var result = channel.setReverbWet(1, 1.0);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "Added new DSP effects": {
   "code": "package haxefmod.core;\n\nenum abstract DspType(Int) from Int to Int {\n    var UNKNOWN = 0;\n    var MIXER = 1;\n    var OSCILLATOR = 2;\n    var LOWPASS = 3;\n    var ITLOWPASS = 4;\n    var HIGHPASS = 5;\n    var ECHO = 6;\n    var FADER = 7;\n    var FLANGE = 8;\n    var DISTORTION = 9;\n    var NORMALIZE = 10;\n    var LIMITER = 11;\n    var PARAMEQ = 12;\n    var PITCHSHIFT = 13;\n    var CHORUS = 14;\n    var ITECHO = 15;\n    var COMPRESSOR = 16;\n    var SFXREVERB = 17;\n    var LOWPASS_SIMPLE = 18;\n    var DELAY = 19;\n    var TREMOLO = 20;\n    var SEND = 21;\n    var RETURN = 22;\n    var HIGHPASS_SIMPLE = 23;\n    var PAN = 24;\n    var THREE_EQ = 25;\n    var FFT = 26;\n    var LOUDNESS_METER = 27;\n    var CONVOLUTIONREVERB = 28;\n    var CHANNELMIX = 29;\n    var TRANSCEIVER = 30;\n    var OBJECTPAN = 31;\n    var MULTIBAND_EQ = 32;\n    var MULTIBAND_DYNAMICS = 33;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "Codec Example": {
   "code": null,
   "notes": [
    "Cannot be bound. registerCodec takes a description of callbacks that FMOD runs on its own threads, and no Haxe target can run code there. A codec built as a shared library loads with StudioSystem.loadPlugin, shown in the second Codec Example."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Codec Example#2": {
   "code": "var handle = StudioSystem.loadPlugin(\"example_codec.dll\");\n\n// example.xyz is a file encoded with the codec's corresponding encoder\nvar sound = Sound.create(\"example.xyz\");",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  },
  "DSP Example": {
   "code": null,
   "notes": [
    "Cannot be bound. registerDSP takes a description of callbacks that FMOD runs on its mixer thread, and no Haxe target can run code there. A DSP plug-in built as a shared library loads with StudioSystem.loadPlugin and Dsp.createByPlugin makes a unit from it, shown in the second DSP Example."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "DSP Example#2": {
   "code": "var handle = StudioSystem.loadPlugin(\"example_dsp.dll\");\nvar channel = sound.play();\nvar dsp = Dsp.createByPlugin(handle);\nvar result = channel.addDsp(0, dsp);\nvar result = channel.addDsp(0, dsp);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.Sound",
   "verdict": "bound"
  },
  "Output Example": {
   "code": null,
   "notes": [
    "Cannot be bound. registerOutput takes a description of callbacks that FMOD runs on its own threads, and no Haxe target can run code there. An output plug-in built as a shared library loads with StudioSystem.loadPlugin and CoreSystem.setOutputByPlugin selects it, shown in the second Output Example."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Output Example#2": {
   "code": "var handle = StudioSystem.loadPlugin(\"example_output.dll\");\nvar result = CoreSystem.setOutputByPlugin(handle);",
   "notes": [],
   "type": "haxefmod.core.CoreSystem",
   "verdict": "bound"
  }
 },
 "core-api-channelcontrol": {
  "ChannelControl::addFadePoint": {
   "code": "// Example. Ramp from full volume to half volume over the next 4096 samples\nvar clocks = channel.getDspClock();\nif (clocks != null) {\n    var parentclock = clocks.parent;\n    channel.addFadePoint(parentclock,        1.0);\n    channel.addFadePoint(parentclock + 4096, 0.5);\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "ChannelControl::set3DCustomRolloff": {
   "code": "// Defining a custom array of points\nvar curve:Array<FmodVector> = [\n    {x: 0.0,  y: 1.0, z: 0.0},\n    {x: 2.0,  y: 0.2, z: 0.0},\n    {x: 20.0, y: 0.0, z: 0.0}\n];",
   "notes": [],
   "type": "haxefmod.studio.Types.FmodVector",
   "verdict": "bound"
  },
  "FMOD_CHANNELCONTROL_CALLBACK": {
   "code": "package haxefmod.core;\n\ntypedef ChannelCallback = ChannelEvent->Void;",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_CHANNELCONTROL_CALLBACK_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodChannelControlCallbackType(Int) from Int to Int {\n    var END = 0;\n    var VIRTUALVOICE = 1;\n    var SYNCPOINT = 2;\n    var OCCLUSION = 3;\n    var MAX = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_CHANNELCONTROL_DSP_INDEX": {
   "code": "package haxefmod.studio;\n\nenum abstract ChannelControlDspIndex(Int) from Int to Int {\n    var HEAD = -1;\n    var FADER = -2;\n    var TAIL = -3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_CHANNELCONTROL_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodChannelControlType(Int) from Int to Int {\n    var CHANNEL = 0;\n    var CHANNELGROUP = 1;\n    var MAX = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "core-api-common": {
  "FMOD_3D_ATTRIBUTES": {
   "code": "package haxefmod.studio;\n\ntypedef Fmod3DAttributes = {\n    var position:FmodVector;\n    var velocity:FmodVector;\n    var forward:FmodVector;\n    var up:FmodVector;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_CHANNELMASK": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodChannelMask(Int) from Int to Int {\n    var FRONT_LEFT = 0x00000001;\n    var FRONT_RIGHT = 0x00000002;\n    var FRONT_CENTER = 0x00000004;\n    var LOW_FREQUENCY = 0x00000008;\n    var SURROUND_LEFT = 0x00000010;\n    var SURROUND_RIGHT = 0x00000020;\n    var BACK_LEFT = 0x00000040;\n    var BACK_RIGHT = 0x00000080;\n    var BACK_CENTER = 0x00000100;\n    var MONO = 0x00000001;\n    var STEREO = 0x00000003;\n    var LRC = 0x00000007;\n    var QUAD = 0x00000033;\n    var SURROUND = 0x00000037;\n    var _5POINT1 = 0x0000003F;\n    var _5POINT1_REARS = 0x000000CF;\n    var _7POINT0 = 0x000000F7;\n    var _7POINT1 = 0x000000FF;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_CHANNELORDER": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodChannelOrder(Int) from Int to Int {\n    var DEFAULT = 0;\n    var WAVEFORMAT = 1;\n    var PROTOOLS = 2;\n    var ALLMONO = 3;\n    var ALLSTEREO = 4;\n    var ALSA = 5;\n    var MAX = 6;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_CPU_USAGE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodSystemCpuUsage = {\n    var studioUpdate:Float;\n    var dsp:Float;\n    var stream:Float;\n    var geometry:Float;\n    var update:Float;\n    var convolution1:Float;\n    var convolution2:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DEBUG_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD calls it on whichever of its threads logs, no Haxe target can run code there. The log goes to the platform's standard output at the level set by FmodSettings.logLevel, or to the file named by FmodSettings.logFile on native targets."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DEBUG_FLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDebugFlags(Int) from Int to Int {\n    var LEVEL_NONE = 0x00000000;\n    var LEVEL_ERROR = 0x00000001;\n    var LEVEL_WARNING = 0x00000002;\n    var LEVEL_LOG = 0x00000004;\n    var TYPE_MEMORY = 0x00000100;\n    var TYPE_FILE = 0x00000200;\n    var TYPE_CODEC = 0x00000400;\n    var TYPE_TRACE = 0x00000800;\n    var TYPE_VIRTUAL = 0x00001000;\n    var DISPLAY_TIMESTAMPS = 0x00010000;\n    var DISPLAY_LINENUMBERS = 0x00020000;\n    var DISPLAY_THREAD = 0x00040000;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DEBUG_MODE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDebugMode(Int) from Int to Int {\n    var TTY = 0;\n    var FILE = 1;\n    var CALLBACK = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_GUID": {
   "code": "package haxefmod.studio;\n\nabstract FmodGuid(String) from String to String {\n    /** The all-zero GUID, what a failed lookup returns. */\n    public static inline var NULL:FmodGuid = cast \"{00000000-0000-0000-0000-000000000000}\";\n\n    inline function new(text:String) this = text;\n\n    /**\n     * Builds one from text, with or without braces, any case. Returns\n     * NULL for anything that is not five hex groups of 8-4-4-4-12.\n     */\n    public static function fromString(text:String):FmodGuid {\n        var digits = hexDigits(text);\n        if (digits == null) return NULL;\n        return new FmodGuid(\"{\" + digits.substr(0, 8) + \"-\" + digits.substr(8, 4) + \"-\" + digits.substr(12, 4)\n            + \"-\" + digits.substr(16, 4) + \"-\" + digits.substr(20, 12) + \"}\");\n    }\n\n    /** Builds one from the four C fields, data4 being eight bytes. */\n    public static function fromFields(data1:Int, data2:Int, data3:Int, data4:Array<Int>):FmodGuid {\n        var text = StringTools.hex(data1, 8) + \"-\" + StringTools.hex(data2 & 0xFFFF, 4) + \"-\" + StringTools.hex(data3 & 0xFFFF, 4) + \"-\";\n        for (i in 0...8) {\n            if (i == 2) text += \"-\";\n            text += StringTools.hex(data4 != null && i < data4.length ? data4[i] & 0xFF : 0, 2);\n        }\n        return fromString(text);\n    }\n\n    /** The braced lower-case text. */\n    public inline function toString():String return this;\n\n    /** The Data1 field, the first 32 bits. */\n    public var data1(get, never):Int;\n    function get_data1():Int return readHex(0, 8);\n\n    /** The Data2 field, the next 16 bits. */\n    public var data2(get, never):Int;\n    function get_data2():Int return readHex(8, 4);\n\n    /** The Data3 field, the 16 bits after Data2. */\n    public var data3(get, never):Int;\n    function get_data3():Int return readHex(12, 4);\n\n    /** The Data4 field, the last eight bytes in order. */\n    public var data4(get, never):Array<Int>;\n    function get_data4():Array<Int> return [for (i in 0...8) readHex(16 + i * 2, 2)];\n\n    /** True for NULL, an empty string, or text that is not a GUID. */\n    public function isNull():Bool {\n        var digits = hexDigits(this);\n        if (digits == null) return true;\n        for (i in 0...digits.length) if (digits.charCodeAt(i) != \"0\".code) return false;\n        return true;\n    }\n\n    /** True when the hex digits match, braces and case aside. */\n    public function equals(other:FmodGuid):Bool {\n        var a = hexDigits(this);\n        var b = hexDigits(other);\n        if (a == null || b == null) return a == b && this == (other : String);\n        return a == b;\n    }\n\n    @:op(A == B) static inline function eq(a:FmodGuid, b:FmodGuid):Bool return a.equals(b);\n    @:op(A != B) static inline function neq(a:FmodGuid, b:FmodGuid):Bool return !a.equals(b);\n\n    function readHex(start:Int, count:Int):Int {\n        var digits = hexDigits(this);\n        if (digits == null) return 0;\n        return Std.parseInt(\"0x\" + digits.substr(start, count));\n    }\n\n    /** The 32 hex digits in lower case, or null when the text is not a GUID. */\n    static function hexDigits(text:String):Null<String> {\n        if (text == null) return null;\n        var s = StringTools.trim(text).toLowerCase();\n        if (s.length > 0 && s.charAt(0) == \"{\") {\n            if (s.charAt(s.length - 1) != \"}\") return null;\n            s = s.substr(1, s.length - 2);\n        }\n        var groups = s.split(\"-\");\n        var widths = [8, 4, 4, 4, 12];\n        if (groups.length != 5) return null;\n        var out = \"\";\n        for (i in 0...5) {\n            var g = groups[i];\n            if (g.length != widths[i]) return null;\n            for (j in 0...g.length) {\n                var c = g.charCodeAt(j);\n                var hex = (c >= \"0\".code && c <= \"9\".code) || (c >= \"a\".code && c <= \"f\".code);\n                if (!hex) return null;\n            }\n            out += g;\n        }\n        return out;\n    }\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_MAX_CHANNEL_WIDTH": {
   "code": "package haxefmod.studio;\n\nclass FmodLimits {\n    /** FMOD_MAX_CHANNEL_WIDTH, the widest mix matrix and channel format. */\n    public static inline var MAX_CHANNEL_WIDTH = 32;\n    /** FMOD_MAX_SYSTEMS, how many FMOD systems one process may create. haxefmod creates one. */\n    public static inline var MAX_SYSTEMS = 8;\n    /** FMOD_MAX_LISTENERS, the cap on StudioSystem.setNumListeners. */\n    public static inline var MAX_LISTENERS = 8;\n    /** FMOD_REVERB_MAXINSTANCES, the number of reverb instance slots. */\n    public static inline var REVERB_MAXINSTANCES = 4;\n    /** FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT, the alignment loadBankMemory needs in point mode. */\n    public static inline var STUDIO_LOAD_MEMORY_ALIGNMENT = 32;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_MAX_LISTENERS": {
   "code": "package haxefmod.studio;\n\nclass FmodLimits {\n    /** FMOD_MAX_CHANNEL_WIDTH, the widest mix matrix and channel format. */\n    public static inline var MAX_CHANNEL_WIDTH = 32;\n    /** FMOD_MAX_SYSTEMS, how many FMOD systems one process may create. haxefmod creates one. */\n    public static inline var MAX_SYSTEMS = 8;\n    /** FMOD_MAX_LISTENERS, the cap on StudioSystem.setNumListeners. */\n    public static inline var MAX_LISTENERS = 8;\n    /** FMOD_REVERB_MAXINSTANCES, the number of reverb instance slots. */\n    public static inline var REVERB_MAXINSTANCES = 4;\n    /** FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT, the alignment loadBankMemory needs in point mode. */\n    public static inline var STUDIO_LOAD_MEMORY_ALIGNMENT = 32;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_MAX_SYSTEMS": {
   "code": "package haxefmod.studio;\n\nclass FmodLimits {\n    /** FMOD_MAX_CHANNEL_WIDTH, the widest mix matrix and channel format. */\n    public static inline var MAX_CHANNEL_WIDTH = 32;\n    /** FMOD_MAX_SYSTEMS, how many FMOD systems one process may create. haxefmod creates one. */\n    public static inline var MAX_SYSTEMS = 8;\n    /** FMOD_MAX_LISTENERS, the cap on StudioSystem.setNumListeners. */\n    public static inline var MAX_LISTENERS = 8;\n    /** FMOD_REVERB_MAXINSTANCES, the number of reverb instance slots. */\n    public static inline var REVERB_MAXINSTANCES = 4;\n    /** FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT, the alignment loadBankMemory needs in point mode. */\n    public static inline var STUDIO_LOAD_MEMORY_ALIGNMENT = 32;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_MEMORY_ALLOC_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_MEMORY_FREE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_MEMORY_REALLOC_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_MEMORY_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodMemoryType(Int) from Int to Int {\n    var NORMAL = 0x00000000;\n    var STREAM_FILE = 0x00000001;\n    var STREAM_DECODE = 0x00000002;\n    var SAMPLEDATA = 0x00000004;\n    var DSP_BUFFER = 0x00000008;\n    var PLUGIN = 0x00000010;\n    var PERSISTENT = 0x00200000;\n    var ALL = 0xFFFFFFFF;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_MODE": {
   "code": "package haxefmod.core;\n\nclass ChannelMode {\n    public static inline var DEFAULT:Int = 0x00000000;\n    public static inline var LOOP_OFF:Int = 0x00000001;\n    public static inline var LOOP_NORMAL:Int = 0x00000002;\n    public static inline var LOOP_BIDI:Int = 0x00000004;\n    public static inline var MODE_2D:Int = 0x00000008;\n    public static inline var MODE_3D:Int = 0x00000010;\n    public static inline var CREATESTREAM:Int = 0x00000080;\n    public static inline var CREATESAMPLE:Int = 0x00000100;\n    public static inline var CREATECOMPRESSEDSAMPLE:Int = 0x00000200;\n    public static inline var OPENUSER:Int = 0x00000400;\n    public static inline var OPENMEMORY:Int = 0x00000800;\n    public static inline var OPENMEMORY_POINT:Int = 0x10000000;\n    public static inline var OPENRAW:Int = 0x00001000;\n    public static inline var OPENONLY:Int = 0x00002000;\n    public static inline var ACCURATETIME:Int = 0x00004000;\n    public static inline var MPEGSEARCH:Int = 0x00008000;\n    public static inline var NONBLOCKING:Int = 0x00010000;\n    public static inline var UNIQUE:Int = 0x00020000;\n    public static inline var MODE_3D_HEADRELATIVE:Int = 0x00040000;\n    public static inline var MODE_3D_WORLDRELATIVE:Int = 0x00080000;\n    public static inline var MODE_3D_INVERSEROLLOFF:Int = 0x00100000;\n    public static inline var MODE_3D_LINEARROLLOFF:Int = 0x00200000;\n    public static inline var MODE_3D_LINEARSQUAREROLLOFF:Int = 0x00400000;\n    public static inline var MODE_3D_INVERSETAPEREDROLLOFF:Int = 0x00800000;\n    public static inline var MODE_3D_CUSTOMROLLOFF:Int = 0x04000000;\n    public static inline var MODE_3D_IGNOREGEOMETRY:Int = 0x40000000;\n    public static inline var IGNORETAGS:Int = 0x02000000;\n    public static inline var LOWMEM:Int = 0x08000000;\n    public static inline var VIRTUAL_PLAYFROMSTART:Int = 0x80000000;\n\n    /** The names haxefmod 2.0.0 gave the 3D flags, the same bits. */\n    public static inline var HEAD_RELATIVE_3D:Int = MODE_3D_HEADRELATIVE;\n    public static inline var WORLD_RELATIVE_3D:Int = MODE_3D_WORLDRELATIVE;\n    public static inline var INVERSE_ROLLOFF_3D:Int = MODE_3D_INVERSEROLLOFF;\n    public static inline var LINEAR_ROLLOFF_3D:Int = MODE_3D_LINEARROLLOFF;\n    public static inline var LINEAR_SQUARE_ROLLOFF_3D:Int = MODE_3D_LINEARSQUAREROLLOFF;\n    public static inline var INVERSE_TAPERED_ROLLOFF_3D:Int = MODE_3D_INVERSETAPEREDROLLOFF;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_RESULT": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodResult(Int) from Int to Int {\n    var FMOD_OK = 0;\n    var FMOD_ERR_BADCOMMAND = 1;\n    var FMOD_ERR_CHANNEL_ALLOC = 2;\n    var FMOD_ERR_CHANNEL_STOLEN = 3;\n    var FMOD_ERR_DMA = 4;\n    var FMOD_ERR_DSP_CONNECTION = 5;\n    var FMOD_ERR_DSP_DONTPROCESS = 6;\n    var FMOD_ERR_DSP_FORMAT = 7;\n    var FMOD_ERR_DSP_INUSE = 8;\n    var FMOD_ERR_DSP_NOTFOUND = 9;\n    var FMOD_ERR_DSP_RESERVED = 10;\n    var FMOD_ERR_DSP_SILENCE = 11;\n    var FMOD_ERR_DSP_TYPE = 12;\n    var FMOD_ERR_FILE_BAD = 13;\n    var FMOD_ERR_FILE_COULDNOTSEEK = 14;\n    var FMOD_ERR_FILE_DISKEJECTED = 15;\n    var FMOD_ERR_FILE_EOF = 16;\n    var FMOD_ERR_FILE_ENDOFDATA = 17;\n    var FMOD_ERR_FILE_NOTFOUND = 18;\n    var FMOD_ERR_FORMAT = 19;\n    var FMOD_ERR_HEADER_MISMATCH = 20;\n    var FMOD_ERR_HTTP = 21;\n    var FMOD_ERR_HTTP_ACCESS = 22;\n    var FMOD_ERR_HTTP_PROXY_AUTH = 23;\n    var FMOD_ERR_HTTP_SERVER_ERROR = 24;\n    var FMOD_ERR_HTTP_TIMEOUT = 25;\n    var FMOD_ERR_INITIALIZATION = 26;\n    var FMOD_ERR_INITIALIZED = 27;\n    var FMOD_ERR_INTERNAL = 28;\n    var FMOD_ERR_INVALID_FLOAT = 29;\n    var FMOD_ERR_INVALID_HANDLE = 30;\n    var FMOD_ERR_INVALID_PARAM = 31;\n    var FMOD_ERR_INVALID_POSITION = 32;\n    var FMOD_ERR_INVALID_SPEAKER = 33;\n    var FMOD_ERR_INVALID_SYNCPOINT = 34;\n    var FMOD_ERR_INVALID_THREAD = 35;\n    var FMOD_ERR_INVALID_VECTOR = 36;\n    var FMOD_ERR_MAXAUDIBLE = 37;\n    var FMOD_ERR_MEMORY = 38;\n    var FMOD_ERR_MEMORY_CANTPOINT = 39;\n    var FMOD_ERR_NEEDS3D = 40;\n    var FMOD_ERR_NEEDSHARDWARE = 41;\n    var FMOD_ERR_NET_CONNECT = 42;\n    var FMOD_ERR_NET_SOCKET_ERROR = 43;\n    var FMOD_ERR_NET_URL = 44;\n    var FMOD_ERR_NET_WOULD_BLOCK = 45;\n    var FMOD_ERR_NOTREADY = 46;\n    var FMOD_ERR_OUTPUT_ALLOCATED = 47;\n    var FMOD_ERR_OUTPUT_CREATEBUFFER = 48;\n    var FMOD_ERR_OUTPUT_DRIVERCALL = 49;\n    var FMOD_ERR_OUTPUT_FORMAT = 50;\n    var FMOD_ERR_OUTPUT_INIT = 51;\n    var FMOD_ERR_OUTPUT_NODRIVERS = 52;\n    var FMOD_ERR_PLUGIN = 53;\n    var FMOD_ERR_PLUGIN_MISSING = 54;\n    var FMOD_ERR_PLUGIN_RESOURCE = 55;\n    var FMOD_ERR_PLUGIN_VERSION = 56;\n    var FMOD_ERR_RECORD = 57;\n    var FMOD_ERR_REVERB_CHANNELGROUP = 58;\n    var FMOD_ERR_REVERB_INSTANCE = 59;\n    var FMOD_ERR_SUBSOUNDS = 60;\n    var FMOD_ERR_SUBSOUND_ALLOCATED = 61;\n    var FMOD_ERR_SUBSOUND_CANTMOVE = 62;\n    var FMOD_ERR_TAGNOTFOUND = 63;\n    var FMOD_ERR_TOOMANYCHANNELS = 64;\n    var FMOD_ERR_TRUNCATED = 65;\n    var FMOD_ERR_UNIMPLEMENTED = 66;\n    var FMOD_ERR_UNINITIALIZED = 67;\n    var FMOD_ERR_UNSUPPORTED = 68;\n    var FMOD_ERR_VERSION = 69;\n    var FMOD_ERR_EVENT_ALREADY_LOADED = 70;\n    var FMOD_ERR_EVENT_LIVEUPDATE_BUSY = 71;\n    var FMOD_ERR_EVENT_LIVEUPDATE_MISMATCH = 72;\n    var FMOD_ERR_EVENT_LIVEUPDATE_TIMEOUT = 73;\n    var FMOD_ERR_EVENT_NOTFOUND = 74;\n    var FMOD_ERR_STUDIO_UNINITIALIZED = 75;\n    var FMOD_ERR_STUDIO_NOT_LOADED = 76;\n    var FMOD_ERR_INVALID_STRING = 77;\n    var FMOD_ERR_ALREADY_LOCKED = 78;\n    var FMOD_ERR_NOT_LOCKED = 79;\n    var FMOD_ERR_RECORD_DISCONNECTED = 80;\n    var FMOD_ERR_TOOMANYSAMPLES = 81;\n\n    public inline function isOk():Bool {\n        return this == 0;\n    }\n\n    public function toString():String {\n        var name = names[this];\n        return name != null ? name : 'FMOD_RESULT($this)';\n    }\n\n    static var names:Array<String> = [\n        \"FMOD_OK\", \"FMOD_ERR_BADCOMMAND\", \"FMOD_ERR_CHANNEL_ALLOC\", \"FMOD_ERR_CHANNEL_STOLEN\",\n        \"FMOD_ERR_DMA\", \"FMOD_ERR_DSP_CONNECTION\", \"FMOD_ERR_DSP_DONTPROCESS\", \"FMOD_ERR_DSP_FORMAT\",\n        \"FMOD_ERR_DSP_INUSE\", \"FMOD_ERR_DSP_NOTFOUND\", \"FMOD_ERR_DSP_RESERVED\", \"FMOD_ERR_DSP_SILENCE\",\n        \"FMOD_ERR_DSP_TYPE\", \"FMOD_ERR_FILE_BAD\", \"FMOD_ERR_FILE_COULDNOTSEEK\", \"FMOD_ERR_FILE_DISKEJECTED\",\n        \"FMOD_ERR_FILE_EOF\", \"FMOD_ERR_FILE_ENDOFDATA\", \"FMOD_ERR_FILE_NOTFOUND\", \"FMOD_ERR_FORMAT\",\n        \"FMOD_ERR_HEADER_MISMATCH\", \"FMOD_ERR_HTTP\", \"FMOD_ERR_HTTP_ACCESS\", \"FMOD_ERR_HTTP_PROXY_AUTH\",\n        \"FMOD_ERR_HTTP_SERVER_ERROR\", \"FMOD_ERR_HTTP_TIMEOUT\", \"FMOD_ERR_INITIALIZATION\", \"FMOD_ERR_INITIALIZED\",\n        \"FMOD_ERR_INTERNAL\", \"FMOD_ERR_INVALID_FLOAT\", \"FMOD_ERR_INVALID_HANDLE\", \"FMOD_ERR_INVALID_PARAM\",\n        \"FMOD_ERR_INVALID_POSITION\", \"FMOD_ERR_INVALID_SPEAKER\", \"FMOD_ERR_INVALID_SYNCPOINT\", \"FMOD_ERR_INVALID_THREAD\",\n        \"FMOD_ERR_INVALID_VECTOR\", \"FMOD_ERR_MAXAUDIBLE\", \"FMOD_ERR_MEMORY\", \"FMOD_ERR_MEMORY_CANTPOINT\",\n        \"FMOD_ERR_NEEDS3D\", \"FMOD_ERR_NEEDSHARDWARE\", \"FMOD_ERR_NET_CONNECT\", \"FMOD_ERR_NET_SOCKET_ERROR\",\n        \"FMOD_ERR_NET_URL\", \"FMOD_ERR_NET_WOULD_BLOCK\", \"FMOD_ERR_NOTREADY\", \"FMOD_ERR_OUTPUT_ALLOCATED\",\n        \"FMOD_ERR_OUTPUT_CREATEBUFFER\", \"FMOD_ERR_OUTPUT_DRIVERCALL\", \"FMOD_ERR_OUTPUT_FORMAT\", \"FMOD_ERR_OUTPUT_INIT\",\n        \"FMOD_ERR_OUTPUT_NODRIVERS\", \"FMOD_ERR_PLUGIN\", \"FMOD_ERR_PLUGIN_MISSING\", \"FMOD_ERR_PLUGIN_RESOURCE\",\n        \"FMOD_ERR_PLUGIN_VERSION\", \"FMOD_ERR_RECORD\", \"FMOD_ERR_REVERB_CHANNELGROUP\", \"FMOD_ERR_REVERB_INSTANCE\",\n        \"FMOD_ERR_SUBSOUNDS\", \"FMOD_ERR_SUBSOUND_ALLOCATED\", \"FMOD_ERR_SUBSOUND_CANTMOVE\", \"FMOD_ERR_TAGNOTFOUND\",\n        \"FMOD_ERR_TOOMANYCHANNELS\", \"FMOD_ERR_TRUNCATED\", \"FMOD_ERR_UNIMPLEMENTED\", \"FMOD_ERR_UNINITIALIZED\",\n        \"FMOD_ERR_UNSUPPORTED\", \"FMOD_ERR_VERSION\", \"FMOD_ERR_EVENT_ALREADY_LOADED\", \"FMOD_ERR_EVENT_LIVEUPDATE_BUSY\",\n        \"FMOD_ERR_EVENT_LIVEUPDATE_MISMATCH\", \"FMOD_ERR_EVENT_LIVEUPDATE_TIMEOUT\", \"FMOD_ERR_EVENT_NOTFOUND\",\n        \"FMOD_ERR_STUDIO_UNINITIALIZED\", \"FMOD_ERR_STUDIO_NOT_LOADED\", \"FMOD_ERR_INVALID_STRING\",\n        \"FMOD_ERR_ALREADY_LOCKED\", \"FMOD_ERR_NOT_LOCKED\", \"FMOD_ERR_RECORD_DISCONNECTED\", \"FMOD_ERR_TOOMANYSAMPLES\"\n    ];\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SPEAKER": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodSpeaker(Int) from Int to Int {\n    var NONE = -1;\n    var FRONT_LEFT = 0;\n    var FRONT_RIGHT = 1;\n    var FRONT_CENTER = 2;\n    var LOW_FREQUENCY = 3;\n    var SURROUND_LEFT = 4;\n    var SURROUND_RIGHT = 5;\n    var BACK_LEFT = 6;\n    var BACK_RIGHT = 7;\n    var TOP_FRONT_LEFT = 8;\n    var TOP_FRONT_RIGHT = 9;\n    var TOP_BACK_LEFT = 10;\n    var TOP_BACK_RIGHT = 11;\n    var MAX = 12;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SPEAKERMODE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodSpeakerMode(Int) from Int to Int {\n    var DEFAULT = 0;\n    var RAW = 1;\n    var MONO = 2;\n    var STEREO = 3;\n    var QUAD = 4;\n    var SURROUND = 5;\n    var _5POINT1 = 6;\n    var _7POINT1 = 7;\n    var _7POINT1POINT4 = 8;\n    var MAX = 9;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SYNCPOINT": {
   "code": "package haxefmod.core;\n\nabstract FmodSyncPoint(Int) from Int to Int {\n    /** The invalid handle, what a failed addSyncPoint or getSyncPoint returns. */\n    public static inline var NULL:FmodSyncPoint = cast -1;\n\n    /** The index in offset order this handle stands for. */\n    public inline function index():Int return this;\n\n    public inline function isNull():Bool return this < 0;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_THREAD_AFFINITY": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodThreadAffinity(Int) from Int to Int {\n    var CORE_ALL = 0;\n    var CORE_0 = 0x00000001;\n    var CORE_1 = 0x00000002;\n    var CORE_2 = 0x00000004;\n    var CORE_3 = 0x00000008;\n    var CORE_4 = 0x00000010;\n    var CORE_5 = 0x00000020;\n    var CORE_6 = 0x00000040;\n    var CORE_7 = 0x00000080;\n    var CORE_8 = 0x00000100;\n    var CORE_9 = 0x00000200;\n    var CORE_10 = 0x00000400;\n    var CORE_11 = 0x00000800;\n    var CORE_12 = 0x00001000;\n    var CORE_13 = 0x00002000;\n    var CORE_14 = 0x00004000;\n    var CORE_15 = 0x00008000;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_THREAD_PRIORITY": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodThreadPriority(Int) from Int to Int {\n    var PLATFORM_MIN = -32768;\n    var PLATFORM_MAX = 32768;\n    var DEFAULT = -32769;\n    var LOW = -32770;\n    var MEDIUM = -32771;\n    var HIGH = -32772;\n    var VERY_HIGH = -32773;\n    var EXTREME = -32774;\n    var CRITICAL = -32775;\n    var MIXER = -32774;\n    var FEEDER = -32775;\n    var STREAM = -32773;\n    var FILE = -32772;\n    var NONBLOCKING = -32772;\n    var RECORD = -32772;\n    var GEOMETRY = -32770;\n    var PROFILER = -32771;\n    var STUDIO_UPDATE = -32771;\n    var STUDIO_LOAD_BANK = -32771;\n    var STUDIO_LOAD_SAMPLE = -32771;\n    var CONVOLUTION1 = -32773;\n    var CONVOLUTION2 = -32773;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_THREAD_STACK_SIZE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodThreadStackSize(Int) from Int to Int {\n    var DEFAULT = 0;\n    var MIXER = 81920;\n    var FEEDER = 16384;\n    var STREAM = 98304;\n    var FILE = 65536;\n    var NONBLOCKING = 114688;\n    var RECORD = 16384;\n    var GEOMETRY = 49152;\n    var PROFILER = 131072;\n    var STUDIO_UPDATE = 98304;\n    var STUDIO_LOAD_BANK = 98304;\n    var STUDIO_LOAD_SAMPLE = 98304;\n    var CONVOLUTION1 = 16384;\n    var CONVOLUTION2 = 16384;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_THREAD_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodThreadType(Int) from Int to Int {\n    var MIXER = 0;\n    var FEEDER = 1;\n    var STREAM = 2;\n    var FILE = 3;\n    var NONBLOCKING = 4;\n    var RECORD = 5;\n    var GEOMETRY = 6;\n    var PROFILER = 7;\n    var STUDIO_UPDATE = 8;\n    var STUDIO_LOAD_BANK = 9;\n    var STUDIO_LOAD_SAMPLE = 10;\n    var CONVOLUTION1 = 11;\n    var CONVOLUTION2 = 12;\n    var MAX = 13;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_TIMEUNIT": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodTimeUnit(Int) from Int to Int {\n    var MS = 0x00000001;\n    var PCM = 0x00000002;\n    var PCMBYTES = 0x00000004;\n    var RAWBYTES = 0x00000008;\n    var PCMFRACTION = 0x00000010;\n    var MODORDER = 0x00000100;\n    var MODROW = 0x00000200;\n    var MODPATTERN = 0x00000400;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_VECTOR": {
   "code": "package haxefmod.studio;\n\ntypedef FmodVector = {\n    var x:Float;\n    var y:Float;\n    var z:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_VERSION": {
   "code": "package haxefmod.studio;\n\nclass FmodVersion {\n    /** FMOD_VERSION of the linked SDK, 2.03.12. */\n    public static inline var VERSION = 0x00020312;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "core-api-common-dsp-effects": {
  "FMOD_DSP_CHANNELMIX": {
   "code": "package haxefmod.core;\n\nenum abstract DspChannelMix(Int) from Int to Int {\n    var OUTPUTGROUPING = 0;\n    var GAIN_CH0 = 1;\n    var GAIN_CH1 = 2;\n    var GAIN_CH2 = 3;\n    var GAIN_CH3 = 4;\n    var GAIN_CH4 = 5;\n    var GAIN_CH5 = 6;\n    var GAIN_CH6 = 7;\n    var GAIN_CH7 = 8;\n    var GAIN_CH8 = 9;\n    var GAIN_CH9 = 10;\n    var GAIN_CH10 = 11;\n    var GAIN_CH11 = 12;\n    var GAIN_CH12 = 13;\n    var GAIN_CH13 = 14;\n    var GAIN_CH14 = 15;\n    var GAIN_CH15 = 16;\n    var GAIN_CH16 = 17;\n    var GAIN_CH17 = 18;\n    var GAIN_CH18 = 19;\n    var GAIN_CH19 = 20;\n    var GAIN_CH20 = 21;\n    var GAIN_CH21 = 22;\n    var GAIN_CH22 = 23;\n    var GAIN_CH23 = 24;\n    var GAIN_CH24 = 25;\n    var GAIN_CH25 = 26;\n    var GAIN_CH26 = 27;\n    var GAIN_CH27 = 28;\n    var GAIN_CH28 = 29;\n    var GAIN_CH29 = 30;\n    var GAIN_CH30 = 31;\n    var GAIN_CH31 = 32;\n    var OUTPUT_CH0 = 33;\n    var OUTPUT_CH1 = 34;\n    var OUTPUT_CH2 = 35;\n    var OUTPUT_CH3 = 36;\n    var OUTPUT_CH4 = 37;\n    var OUTPUT_CH5 = 38;\n    var OUTPUT_CH6 = 39;\n    var OUTPUT_CH7 = 40;\n    var OUTPUT_CH8 = 41;\n    var OUTPUT_CH9 = 42;\n    var OUTPUT_CH10 = 43;\n    var OUTPUT_CH11 = 44;\n    var OUTPUT_CH12 = 45;\n    var OUTPUT_CH13 = 46;\n    var OUTPUT_CH14 = 47;\n    var OUTPUT_CH15 = 48;\n    var OUTPUT_CH16 = 49;\n    var OUTPUT_CH17 = 50;\n    var OUTPUT_CH18 = 51;\n    var OUTPUT_CH19 = 52;\n    var OUTPUT_CH20 = 53;\n    var OUTPUT_CH21 = 54;\n    var OUTPUT_CH22 = 55;\n    var OUTPUT_CH23 = 56;\n    var OUTPUT_CH24 = 57;\n    var OUTPUT_CH25 = 58;\n    var OUTPUT_CH26 = 59;\n    var OUTPUT_CH27 = 60;\n    var OUTPUT_CH28 = 61;\n    var OUTPUT_CH29 = 62;\n    var OUTPUT_CH30 = 63;\n    var OUTPUT_CH31 = 64;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_CHANNELMIX_OUTPUT": {
   "code": "package haxefmod.core;\n\nenum abstract DspChannelMixOutput(Int) from Int to Int {\n    var DEFAULT = 0;\n    var ALLMONO = 1;\n    var ALLSTEREO = 2;\n    var ALLQUAD = 3;\n    var ALL5POINT1 = 4;\n    var ALL7POINT1 = 5;\n    var ALLLFE = 6;\n    var ALL7POINT1POINT4 = 7;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_CHORUS": {
   "code": "package haxefmod.core;\n\nenum abstract DspChorus(Int) from Int to Int {\n    var MIX = 0;\n    var RATE = 1;\n    var DEPTH = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_COMPRESSOR": {
   "code": "package haxefmod.core;\n\nenum abstract DspCompressor(Int) from Int to Int {\n    var THRESHOLD = 0;\n    var RATIO = 1;\n    var ATTACK = 2;\n    var RELEASE = 3;\n    var GAINMAKEUP = 4;\n    var USESIDECHAIN = 5;\n    var LINKED = 6;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_CONVOLUTION_REVERB": {
   "code": "package haxefmod.core;\n\nenum abstract DspConvolutionReverb(Int) from Int to Int {\n    var PARAM_IR = 0;\n    var PARAM_WET = 1;\n    var PARAM_DRY = 2;\n    var PARAM_LINKED = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_DELAY": {
   "code": "package haxefmod.core;\n\nenum abstract DspDelay(Int) from Int to Int {\n    var CH0 = 0;\n    var CH1 = 1;\n    var CH2 = 2;\n    var CH3 = 3;\n    var CH4 = 4;\n    var CH5 = 5;\n    var CH6 = 6;\n    var CH7 = 7;\n    var CH8 = 8;\n    var CH9 = 9;\n    var CH10 = 10;\n    var CH11 = 11;\n    var CH12 = 12;\n    var CH13 = 13;\n    var CH14 = 14;\n    var CH15 = 15;\n    var MAXDELAY = 16;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_DISTORTION": {
   "code": "package haxefmod.core;\n\nenum abstract DspDistortion(Int) from Int to Int {\n    var LEVEL = 0;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_ECHO": {
   "code": "package haxefmod.core;\n\nenum abstract DspEcho(Int) from Int to Int {\n    var DELAY = 0;\n    var FEEDBACK = 1;\n    var DRYLEVEL = 2;\n    var WETLEVEL = 3;\n    var DELAYCHANGEMODE = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_ECHO_DELAYCHANGEMODE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspEchoDelayChangeMode(Int) from Int to Int {\n    var FADE = 0;\n    var LERP = 1;\n    var NONE = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_FADER": {
   "code": "package haxefmod.core;\n\nenum abstract DspFader(Int) from Int to Int {\n    var GAIN = 0;\n    var OVERALL_GAIN = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_FFT": {
   "code": "package haxefmod.core;\n\nenum abstract DspFft(Int) from Int to Int {\n    var WINDOWSIZE = 0;\n    var WINDOW = 1;\n    var BAND_START_FREQ = 2;\n    var BAND_STOP_FREQ = 3;\n    var SPECTRUMDATA = 4;\n    var RMS = 5;\n    var SPECTRAL_CENTROID = 6;\n    var IMMEDIATE_MODE = 7;\n    var DOWNMIX = 8;\n    var CHANNEL = 9;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_FFT_DOWNMIX_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspFftDownmix(Int) from Int to Int {\n    var NONE = 0;\n    var MONO = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_FFT_WINDOW_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspFftWindow(Int) from Int to Int {\n    var RECT = 0;\n    var TRIANGLE = 1;\n    var HAMMING = 2;\n    var HANNING = 3;\n    var BLACKMAN = 4;\n    var BLACKMANHARRIS = 5;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_FLANGE": {
   "code": "package haxefmod.core;\n\nenum abstract DspFlange(Int) from Int to Int {\n    var MIX = 0;\n    var DEPTH = 1;\n    var RATE = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_HIGHPASS": {
   "code": "package haxefmod.core;\n\nenum abstract DspHighpass(Int) from Int to Int {\n    var CUTOFF = 0;\n    var RESONANCE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_HIGHPASS#2": {
   "code": "// Configure a single band (band A) as a highpass (all other bands default to off).\n// 12dB roll-off to approximate the old effect curve.\n// Cutoff frequency can be used the same as with the old effect.\n// Resonance can be applied by setting the 'Q' value of the new effect.\nmultiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.HIGHPASS_12DB);\nmultiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);\nmultiband.setParameter(DspMultibandEq.A_Q, resonance);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType, haxefmod.core.DspParameters.DspMultibandEq, haxefmod.core.DspEnums.DspMultibandEqFilter",
   "verdict": "bound"
  },
  "FMOD_DSP_HIGHPASS_SIMPLE": {
   "code": "package haxefmod.core;\n\nenum abstract DspHighpassSimple(Int) from Int to Int {\n    var CUTOFF = 0;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_HIGHPASS_SIMPLE#2": {
   "code": "// Configure a single band (band A) as a highpass (all other bands default to off).\n// 12dB roll-off to approximate the old effect curve.\n// Cutoff frequency can be used the same as with the old effect.\n// Resonance / 'Q' should remain at default 0.707.\nmultiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.HIGHPASS_12DB);\nmultiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType, haxefmod.core.DspParameters.DspMultibandEq, haxefmod.core.DspEnums.DspMultibandEqFilter",
   "verdict": "bound"
  },
  "FMOD_DSP_ITECHO": {
   "code": "package haxefmod.core;\n\nenum abstract DspItEcho(Int) from Int to Int {\n    var WETDRYMIX = 0;\n    var FEEDBACK = 1;\n    var LEFTDELAY = 2;\n    var RIGHTDELAY = 3;\n    var PANDELAY = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_ITLOWPASS": {
   "code": "package haxefmod.core;\n\nenum abstract DspItLowpass(Int) from Int to Int {\n    var CUTOFF = 0;\n    var RESONANCE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LIMITER": {
   "code": "package haxefmod.core;\n\nenum abstract DspLimiter(Int) from Int to Int {\n    var RELEASETIME = 0;\n    var CEILING = 1;\n    var MAXIMIZERGAIN = 2;\n    var MODE = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOUDNESS_METER": {
   "code": "package haxefmod.core;\n\nenum abstract DspLoudnessMeter(Int) from Int to Int {\n    var STATE = 0;\n    var WEIGHTING = 1;\n    var INFO = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOUDNESS_METER_INFO_TYPE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspLoudnessMeterInfo = {\n    var momentaryLoudness:Float;\n    var shortTermLoudness:Float;\n    var integratedLoudness:Float;\n    var loudness10thPercentile:Float;\n    var loudness95thPercentile:Float;\n    var loudnessHistogram:Array<Float>;\n    var maxTruePeak:Float;\n    var maxMomentaryLoudness:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOUDNESS_METER_STATE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspLoudnessMeterState(Int) from Int to Int {\n    var RESET_INTEGRATED = -3;\n    var RESET_MAXPEAK = -2;\n    var RESET_ALL = -1;\n    var PAUSED = 0;\n    var ANALYZING = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspLoudnessMeterWeightingType = {\n    var channelWeight:Array<Float>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOWPASS": {
   "code": "package haxefmod.core;\n\nenum abstract DspLowpass(Int) from Int to Int {\n    var CUTOFF = 0;\n    var RESONANCE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOWPASS#2": {
   "code": "// Configure a single band (band A) as a lowpass (all other bands default to off).\n// 24dB roll-off to approximate the old effect curve.\n// Cutoff frequency can be used the same as with the old effect.\n// Resonance can be applied by setting the 'Q' value of the new effect.\nmultiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.LOWPASS_24DB);\nmultiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);\nmultiband.setParameter(DspMultibandEq.A_Q, resonance);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType, haxefmod.core.DspParameters.DspMultibandEq, haxefmod.core.DspEnums.DspMultibandEqFilter",
   "verdict": "bound"
  },
  "FMOD_DSP_LOWPASS_SIMPLE": {
   "code": "package haxefmod.core;\n\nenum abstract DspLowpassSimple(Int) from Int to Int {\n    var CUTOFF = 0;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_LOWPASS_SIMPLE#2": {
   "code": "// Configure a single band (band A) as a lowpass (all other bands default to off).\n// 12dB roll-off to approximate the old effect curve.\n// Cutoff frequency can be used the same as with the old effect.\n// Resonance / 'Q' should remain at default 0.707.\nmultiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.LOWPASS_12DB);\nmultiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType, haxefmod.core.DspParameters.DspMultibandEq, haxefmod.core.DspEnums.DspMultibandEqFilter",
   "verdict": "bound"
  },
  "FMOD_DSP_MULTIBAND_DYNAMICS": {
   "code": "package haxefmod.core;\n\nenum abstract DspMultibandDynamics(Int) from Int to Int {\n    var LOWER_FREQUENCY = 0;\n    var UPPER_FREQUENCY = 1;\n    var LINKED = 2;\n    var USE_SIDECHAIN = 3;\n    var A_MODE = 4;\n    var A_GAIN = 5;\n    var A_THRESHOLD = 6;\n    var A_RATIO = 7;\n    var A_ATTACK = 8;\n    var A_RELEASE = 9;\n    var A_GAIN_MAKEUP = 10;\n    var A_RESPONSE_DATA = 11;\n    var B_MODE = 12;\n    var B_GAIN = 13;\n    var B_THRESHOLD = 14;\n    var B_RATIO = 15;\n    var B_ATTACK = 16;\n    var B_RELEASE = 17;\n    var B_GAIN_MAKEUP = 18;\n    var B_RESPONSE_DATA = 19;\n    var C_MODE = 20;\n    var C_GAIN = 21;\n    var C_THRESHOLD = 22;\n    var C_RATIO = 23;\n    var C_ATTACK = 24;\n    var C_RELEASE = 25;\n    var C_GAIN_MAKEUP = 26;\n    var C_RESPONSE_DATA = 27;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_MULTIBAND_DYNAMICS_MODE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspMultibandDynamicsMode(Int) from Int to Int {\n    var DISABLED = 0;\n    var COMPRESS_UP = 1;\n    var COMPRESS_DOWN = 2;\n    var EXPAND_UP = 3;\n    var EXPAND_DOWN = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_MULTIBAND_EQ": {
   "code": "package haxefmod.core;\n\nenum abstract DspMultibandEq(Int) from Int to Int {\n    var A_FILTER = 0;\n    var A_FREQUENCY = 1;\n    var A_Q = 2;\n    var A_GAIN = 3;\n    var B_FILTER = 4;\n    var B_FREQUENCY = 5;\n    var B_Q = 6;\n    var B_GAIN = 7;\n    var C_FILTER = 8;\n    var C_FREQUENCY = 9;\n    var C_Q = 10;\n    var C_GAIN = 11;\n    var D_FILTER = 12;\n    var D_FREQUENCY = 13;\n    var D_Q = 14;\n    var D_GAIN = 15;\n    var E_FILTER = 16;\n    var E_FREQUENCY = 17;\n    var E_Q = 18;\n    var E_GAIN = 19;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspMultibandEqFilter(Int) from Int to Int {\n    var DISABLED = 0;\n    var LOWPASS_12DB = 1;\n    var LOWPASS_24DB = 2;\n    var LOWPASS_48DB = 3;\n    var HIGHPASS_12DB = 4;\n    var HIGHPASS_24DB = 5;\n    var HIGHPASS_48DB = 6;\n    var LOWSHELF = 7;\n    var HIGHSHELF = 8;\n    var PEAKING = 9;\n    var BANDPASS = 10;\n    var NOTCH = 11;\n    var ALLPASS = 12;\n    var LOWPASS_6DB = 13;\n    var HIGHPASS_6DB = 14;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_NORMALIZE": {
   "code": "package haxefmod.core;\n\nenum abstract DspNormalize(Int) from Int to Int {\n    var FADETIME = 0;\n    var THRESHOLD = 1;\n    var MAXAMP = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_OBJECTPAN": {
   "code": "package haxefmod.core;\n\nenum abstract DspObjectPan(Int) from Int to Int {\n    var _3D_POSITION = 0;\n    var _3D_ROLLOFF = 1;\n    var _3D_MIN_DISTANCE = 2;\n    var _3D_MAX_DISTANCE = 3;\n    var _3D_EXTENT_MODE = 4;\n    var _3D_SOUND_SIZE = 5;\n    var _3D_MIN_EXTENT = 6;\n    var OVERALL_GAIN = 7;\n    var OUTPUTGAIN = 8;\n    var ATTENUATION_RANGE = 9;\n    var OVERRIDE_RANGE = 10;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_OSCILLATOR": {
   "code": "package haxefmod.core;\n\nenum abstract DspOscillator(Int) from Int to Int {\n    var TYPE = 0;\n    var RATE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PAN": {
   "code": "package haxefmod.core;\n\nenum abstract DspPan(Int) from Int to Int {\n    var MODE = 0;\n    var _2D_STEREO_POSITION = 1;\n    var _2D_DIRECTION = 2;\n    var _2D_EXTENT = 3;\n    var _2D_ROTATION = 4;\n    var _2D_LFE_LEVEL = 5;\n    var _2D_STEREO_MODE = 6;\n    var _2D_STEREO_SEPARATION = 7;\n    var _2D_STEREO_AXIS = 8;\n    var ENABLED_SPEAKERS = 9;\n    var _3D_POSITION = 10;\n    var _3D_ROLLOFF = 11;\n    var _3D_MIN_DISTANCE = 12;\n    var _3D_MAX_DISTANCE = 13;\n    var _3D_EXTENT_MODE = 14;\n    var _3D_SOUND_SIZE = 15;\n    var _3D_MIN_EXTENT = 16;\n    var _3D_PAN_BLEND = 17;\n    var LFE_UPMIX_ENABLED = 18;\n    var OVERALL_GAIN = 19;\n    var SURROUND_SPEAKER_MODE = 20;\n    var _2D_HEIGHT_BLEND = 21;\n    var ATTENUATION_RANGE = 22;\n    var OVERRIDE_RANGE = 23;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PAN#2": {
   "code": null,
   "notes": [
    "No Haxe declaration, another call plays this role. this block is prose about how a rotating 3D source is panned, in Haxe the source is positioned through Channel.set3DAttributes and the same panning applies"
   ],
   "type": null,
   "verdict": "covered"
  },
  "FMOD_DSP_PAN_2D_STEREO_MODE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspPan2DStereoModeType(Int) from Int to Int {\n    var DISTRIBUTED = 0;\n    var DISCRETE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PAN_3D_EXTENT_MODE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspPan3DExtentModeType(Int) from Int to Int {\n    var AUTO = 0;\n    var USER = 1;\n    var OFF = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PAN_3D_ROLLOFF_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspPan3DRolloffType(Int) from Int to Int {\n    var LINEARSQUARED = 0;\n    var LINEAR = 1;\n    var INVERSE = 2;\n    var INVERSETAPERED = 3;\n    var CUSTOM = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PAN_MODE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspPanModeType(Int) from Int to Int {\n    var MONO = 0;\n    var STEREO = 1;\n    var SURROUND = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMEQ": {
   "code": "package haxefmod.core;\n\nenum abstract DspParamEq(Int) from Int to Int {\n    var CENTER = 0;\n    var BANDWIDTH = 1;\n    var GAIN = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMEQ#2": {
   "code": "// Configure a single band (band A) as a peaking EQ (all other bands default to off).\n// Center frequency can be used as with the old effect.\n// Bandwidth can be applied by setting the 'Q' value of the new effect.\n// Gain at the center frequency can be used the same as with the old effect.\nmultiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.PEAKING);\nmultiband.setParameter(DspMultibandEq.A_FREQUENCY, center);\nmultiband.setParameter(DspMultibandEq.A_Q, bandwidth);\nmultiband.setParameter(DspMultibandEq.A_GAIN, gain);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType, haxefmod.core.DspParameters.DspMultibandEq, haxefmod.core.DspEnums.DspMultibandEqFilter",
   "verdict": "bound"
  },
  "FMOD_DSP_PITCHSHIFT": {
   "code": "package haxefmod.core;\n\nenum abstract DspPitchShift(Int) from Int to Int {\n    var PITCH = 0;\n    var FFTSIZE = 1;\n    var OVERLAP = 2;\n    var MAXCHANNELS = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_RETURN": {
   "code": "package haxefmod.core;\n\nenum abstract DspReturn(Int) from Int to Int {\n    var ID = 0;\n    var INPUT_SPEAKER_MODE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_SEND": {
   "code": "package haxefmod.core;\n\nenum abstract DspSend(Int) from Int to Int {\n    var RETURNID = 0;\n    var LEVEL = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_SFXREVERB": {
   "code": "package haxefmod.core;\n\nenum abstract DspSfxReverb(Int) from Int to Int {\n    var DECAYTIME = 0;\n    var EARLYDELAY = 1;\n    var LATEDELAY = 2;\n    var HFREFERENCE = 3;\n    var HFDECAYRATIO = 4;\n    var DIFFUSION = 5;\n    var DENSITY = 6;\n    var LOWSHELFFREQUENCY = 7;\n    var LOWSHELFGAIN = 8;\n    var HIGHCUT = 9;\n    var EARLYLATEMIX = 10;\n    var WETLEVEL = 11;\n    var DRYLEVEL = 12;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_THREE_EQ": {
   "code": "package haxefmod.core;\n\nenum abstract DspThreeEq(Int) from Int to Int {\n    var LOWGAIN = 0;\n    var MIDGAIN = 1;\n    var HIGHGAIN = 2;\n    var LOWCROSSOVER = 3;\n    var HIGHCROSSOVER = 4;\n    var CROSSOVERSLOPE = 5;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspThreeEqCrossoverSlope(Int) from Int to Int {\n    var _12DB = 0;\n    var _24DB = 1;\n    var _48DB = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_TRANSCEIVER": {
   "code": "package haxefmod.core;\n\nenum abstract DspTransceiver(Int) from Int to Int {\n    var TRANSMIT = 0;\n    var GAIN = 1;\n    var CHANNEL = 2;\n    var TRANSMITSPEAKERMODE = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_TRANSCEIVER_SPEAKERMODE": {
   "code": "package haxefmod.core;\n\nenum abstract DspTransceiverSpeakerMode(Int) from Int to Int {\n    var AUTO = -1;\n    var MONO = 0;\n    var STEREO = 1;\n    var SURROUND = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_TREMOLO": {
   "code": "package haxefmod.core;\n\nenum abstract DspTremolo(Int) from Int to Int {\n    var FREQUENCY = 0;\n    var DEPTH = 1;\n    var SHAPE = 2;\n    var SKEW = 3;\n    var DUTY = 4;\n    var SQUARE = 5;\n    var PHASE = 6;\n    var SPREAD = 7;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_TYPE": {
   "code": "package haxefmod.core;\n\nenum abstract DspType(Int) from Int to Int {\n    var UNKNOWN = 0;\n    var MIXER = 1;\n    var OSCILLATOR = 2;\n    var LOWPASS = 3;\n    var ITLOWPASS = 4;\n    var HIGHPASS = 5;\n    var ECHO = 6;\n    var FADER = 7;\n    var FLANGE = 8;\n    var DISTORTION = 9;\n    var NORMALIZE = 10;\n    var LIMITER = 11;\n    var PARAMEQ = 12;\n    var PITCHSHIFT = 13;\n    var CHORUS = 14;\n    var ITECHO = 15;\n    var COMPRESSOR = 16;\n    var SFXREVERB = 17;\n    var LOWPASS_SIMPLE = 18;\n    var DELAY = 19;\n    var TREMOLO = 20;\n    var SEND = 21;\n    var RETURN = 22;\n    var HIGHPASS_SIMPLE = 23;\n    var PAN = 24;\n    var THREE_EQ = 25;\n    var FFT = 26;\n    var LOUDNESS_METER = 27;\n    var CONVOLUTIONREVERB = 28;\n    var CHANNELMIX = 29;\n    var TRANSCEIVER = 30;\n    var OBJECTPAN = 31;\n    var MULTIBAND_EQ = 32;\n    var MULTIBAND_DYNAMICS = 33;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "core-api-dsp": {
  "FMOD_DSP_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD calls it on its mixer thread, no Haxe target can run code there. Dsp.setParameterData copies its bytes, so no release callback is needed."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_CALLBACK_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspCallbackType(Int) from Int to Int {\n    var DATAPARAMETERRELEASE = 0;\n    var MAX = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_DATA_PARAMETER_INFO": {
   "code": null,
   "notes": [
    "Cannot be bound. the payload of a DSP callback, which runs on the mixer thread. Dsp.setParameterData copies its bytes so nothing needs releasing."
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "core-api-dspconnection": {
  "FMOD_DSPCONNECTION_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract DspConnectionType(Int) from Int to Int {\n    var STANDARD = 0;\n    var SIDECHAIN = 1;\n    var SEND = 2;\n    var SEND_SIDECHAIN = 3;\n    var PREALLOCATED = 4;\n    var MAX = 5;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "core-api-platform-android": {
  "FMOD_Android_JNI_Init": {
   "code": null,
   "notes": [
    "Cannot be bound. Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "core-api-platform-html5": {
  "Example usage.": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. the library fetches bank files into the browser's virtual filesystem itself. The names in FmodSettings.autoLoadBanks are fetched during FmodManager.Initialize, and FmodRuntime.banks.loadAsync(path) fetches any other bank and loads it once loadingState(path) reports LOADED. StudioSystem.loadBankFile only sees files already placed there."
   ],
   "type": null,
   "verdict": "library"
  },
  "Example usage.#2": {
   "code": "var bytes = haxe.io.Bytes.alloc(0); // the bank file fetched by the game\nvar bank:Bank = StudioSystem.loadBankMemory(bytes, FmodLoadBankFlags.NONBLOCKING);",
   "notes": [],
   "type": "haxefmod.studio.Bank, haxefmod.studio.Types",
   "verdict": "bound"
  },
  "Example usage.#3": {
   "code": null,
   "notes": [
    "Cannot be bound. this is the read callback of a custom DSP working on FMOD's mix buffers through raw heap addresses. haxefmod exposes no custom DSP callback on any target. Dsp.create(DspType) gives the built-in effects."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Example usage.#4": {
   "code": null,
   "notes": [
    "Cannot be bound. this is the read callback of a custom DSP working on FMOD's mix buffers through raw heap addresses. haxefmod exposes no custom DSP callback on any target. Dsp.create(DspType) gives the built-in effects."
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "core-api-platform-ios": {
  "FMOD_AUDIOQUEUE_CODECPOLICY": {
   "code": null,
   "notes": [
    "Cannot be bound. iOS is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only, and this enum exists only in the iOS headers"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "core-api-sound": {
  "FMOD_OPENSTATE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodOpenState(Int) from Int to Int {\n    var READY = 0;\n    var LOADING = 1;\n    var ERROR = 2;\n    var CONNECTING = 3;\n    var BUFFERING = 4;\n    var SEEKING = 5;\n    var PLAYING = 6;\n    var SETPOSITION = 7;\n    var MAX = 8;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SOUND_FORMAT": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodSoundFormat(Int) from Int to Int {\n    var NONE = 0;\n    var PCM8 = 1;\n    var PCM16 = 2;\n    var PCM24 = 3;\n    var PCM32 = 4;\n    var PCMFLOAT = 5;\n    var BITSTREAM = 6;\n    var MAX = 7;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SOUND_NONBLOCK_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. It runs on FMOD's file thread, where no Haxe code can run. Sound.create with ChannelMode.NONBLOCKING starts the load and Sound.getOpenState reports READY or ERROR when it finishes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_SOUND_PCMREAD_CALLBACK": {
   "code": "package haxefmod.core;\n\ntypedef PcmReadCallback = (stream:PcmStream, data:haxe.io.Bytes, dataLen:Int)->FmodResult;",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SOUND_PCMSETPOS_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. It runs on FMOD's mixer thread, where no Haxe code can run. A PcmStream has no seekable position, so a game that needs to jump changes what it writes into the ring."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_SOUND_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodSoundType(Int) from Int to Int {\n    var UNKNOWN = 0;\n    var AIFF = 1;\n    var ASF = 2;\n    var DLS = 3;\n    var FLAC = 4;\n    var FSB = 5;\n    var IT = 6;\n    var MIDI = 7;\n    var MOD = 8;\n    var MPEG = 9;\n    var OGGVORBIS = 10;\n    var PLAYLIST = 11;\n    var RAW = 12;\n    var S3M = 13;\n    var USER = 14;\n    var WAV = 15;\n    var XM = 16;\n    var XMA = 17;\n    var AUDIOQUEUE = 18;\n    var AT9 = 19;\n    var VORBIS = 20;\n    var MEDIA_FOUNDATION = 21;\n    var MEDIACODEC = 22;\n    var FADPCM = 23;\n    var OPUS = 24;\n    var MAX = 25;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_TAG": {
   "code": "package haxefmod.studio;\n\ntypedef FmodTag = {\n    var name:String;\n    var type:FmodTagType;\n    var dataType:FmodTagDataType;\n    /** True until the tag has been read once through getTag. */\n    var updated:Bool;\n    /** Payload size in bytes, reported for every data type. */\n    var length:Int;\n    /** The payload of an INT tag. 0 otherwise. */\n    var intValue:Int;\n    /** The payload of a FLOAT tag. 0 otherwise. */\n    var floatValue:Float;\n    /** The payload of a STRING or STRING_UTF8 tag. \"\" otherwise, UTF16 and binary payloads are not copied. */\n    var stringValue:String;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_TAGDATATYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodTagDataType(Int) from Int to Int {\n    var BINARY = 0;\n    var INT = 1;\n    var FLOAT = 2;\n    var STRING = 3;\n    var STRING_UTF16 = 4;\n    var STRING_UTF16BE = 5;\n    var STRING_UTF8 = 6;\n    var MAX = 7;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_TAGTYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodTagType(Int) from Int to Int {\n    var UNKNOWN = 0;\n    var ID3V1 = 1;\n    var ID3V2 = 2;\n    var VORBISCOMMENT = 3;\n    var SHOUTCAST = 4;\n    var ICECAST = 5;\n    var ASF = 6;\n    var MIDI = 7;\n    var PLAYLIST = 8;\n    var FMOD = 9;\n    var USER = 10;\n    var MAX = 11;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "Sound::getTag": {
   "code": "var tag = sound.getTag(null, -1);\nwhile (tag != null) {\n    if (tag.type == FmodTagType.FMOD) {\n        /* When a song changes, the sample rate may also change, so compensate here. */\n        if (tag.name == \"Sample Rate Change\" && !channel.isNull()) {\n            var frequency = tag.floatValue;\n\n            channel.setFrequency(frequency);\n        }\n    }\n    tag = sound.getTag(null, -1);\n}",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.studio.Types",
   "verdict": "bound"
  },
  "Sound::set3DCustomRolloff": {
   "code": "// Defining a custom array of points\nvar curve:Array<FmodVector> = [\n    {x: 0.0, y: 1.0, z: 0.0},\n    {x: 2.0, y: 0.2, z: 0.0},\n    {x: 20.0, y: 0.0, z: 0.0}\n];",
   "notes": [],
   "type": "haxefmod.studio.Types.FmodVector",
   "verdict": "bound"
  },
  "Sound::setDefaults": {
   "code": "var defaults = sound.getDefaults();\nsound.setDefaults(48000, defaults.priority);",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  }
 },
 "core-api-soundgroup": {
  "FMOD_SOUNDGROUP_BEHAVIOR": {
   "code": "package haxefmod.studio;\n\nenum abstract SoundGroupBehavior(Int) from Int to Int {\n    var FAIL = 0;\n    var MUTE = 1;\n    var STEALLOWEST = 2;\n    var MAX = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "core-api-system": {
  "FMOD_3D_ROLLOFF_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's mixer thread and no Haxe target can execute code there. A curve of points passed to set3DCustomRolloff on Sound, Channel, or ChannelGroup shapes the rolloff instead, and the rolloff flags of ChannelMode select the built-in curves."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_ADVANCEDSETTINGS": {
   "code": "package haxefmod.studio;\n\ntypedef FmodAdvancedSettings = {\n    var maxMPEGCodecs:Int;\n    var maxVorbisCodecs:Int;\n    var maxFADPCMCodecs:Int;\n    var vol0VirtualVol:Float;\n    var defaultDecodeBufferSize:Int;\n    var profilePort:Int;\n    var geometryMaxFadeTime:Int;\n    var distanceFilterCenterFreq:Float;\n    var randomSeed:Int;\n    var resamplerMethod:FmodDspResampler;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_ASYNCREADINFO": {
   "code": null,
   "notes": [
    "Cannot be bound. The struct is handed to the async file callbacks, which run on FMOD's file threads, and custom file systems are not exposed. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CREATESOUNDEXINFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodCreateSoundExInfo = {\n    /** Bytes to read from a memory image or a file, 0 for the whole thing. fromMemory sets it to the buffer length when left out. */\n    @:optional var length:Int;\n    /** Byte offset to start reading a file at. */\n    @:optional var fileOffset:Int;\n    /** Channel count of raw PCM (ChannelMode.OPENRAW). */\n    @:optional var numChannels:Int;\n    /** Sample rate of raw PCM (ChannelMode.OPENRAW). */\n    @:optional var defaultFrequency:Int;\n    /** Sample format of raw PCM (ChannelMode.OPENRAW). */\n    @:optional var format:FmodSoundFormat;\n    /** Decode buffer size in samples for a stream. */\n    @:optional var decodeBufferSize:Int;\n    /** The subsound an FSB or multi-stream file starts on. */\n    @:optional var initialSubsound:Int;\n    /** Subsound count for a user-created container sound. */\n    @:optional var numSubsounds:Int;\n    /** Subsound indices to load, the rest stay unloaded. */\n    @:optional var inclusionList:Array<Int>;\n    /** DLS sound bank file for MIDI playback. */\n    @:optional var dlsName:String;\n    /** Key for an encrypted FSB. */\n    @:optional var encryptionKey:String;\n    /** Voice cap for a MIDI or tracker sound. */\n    @:optional var maxPolyphony:Int;\n    /** The codec to try first, skipping FMOD's format sniffing. */\n    @:optional var suggestedSoundType:FmodSoundType;\n    /** Buffer size in bytes for the file reader of a stream. */\n    @:optional var fileBufferSize:Int;\n    /** Speaker order of the source data. */\n    @:optional var channelOrder:FmodChannelOrder;\n    /** The group the new sound joins, SoundGroup.master() when left out. */\n    @:optional var initialSoundGroup:haxefmod.core.SoundGroup;\n    /** Where a stream starts, in initialSeekPosType units. */\n    @:optional var initialSeekPosition:Int;\n    /** The unit of initialSeekPosition, milliseconds when left out. */\n    @:optional var initialSeekPosType:FmodTimeUnit;\n    /** Nonzero reads the file through the platform file system even when a custom one is installed. */\n    @:optional var ignoreSetFileSystem:Int;\n    /** iOS AudioQueue codec policy. */\n    @:optional var audioQueuePolicy:Int;\n    /** Granularity in milliseconds of MIDI note timing. */\n    @:optional var minMidiGranularity:Int;\n    /** Which of FMOD's nonblocking threads handles a ChannelMode.NONBLOCKING load, 0 to 4. */\n    @:optional var nonBlockThreadId:Int;\n    /** The GUID of the FSB subsound to load, for FSB files that carry GUIDs. */\n    @:optional var fsbGuid:FmodGuid;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DRIVER_STATE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDriverState(Int) from Int to Int {\n    var CONNECTED = 0x00000001;\n    var DEFAULT = 0x00000002;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_RESAMPLER": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspResampler(Int) from Int to Int {\n    var DEFAULT = 0;\n    var NOINTERP = 1;\n    var LINEAR = 2;\n    var CUBIC = 3;\n    var SPLINE = 4;\n    var MAX = 5;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_ERRORCALLBACK_INFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodErrorCallbackInfo = {\n    /** The result the failing call returned. */\n    var result:FmodResult;\n    /** The kind of object the call was made on. */\n    var instanceType:FmodErrorCallbackInstanceType;\n    /** The handle of that object, castable to its abstract type, 0 when unknown. */\n    var instance:Int;\n    /** The FMOD function that failed, for example \"System::createSound\". */\n    var functionName:String;\n    /** The arguments as FMOD prints them, cut at 127 characters. */\n    var functionParams:String;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_ERRORCALLBACK_INSTANCETYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodErrorCallbackInstanceType(Int) from Int to Int {\n    var NONE = 0;\n    var SYSTEM = 1;\n    var CHANNEL = 2;\n    var CHANNELGROUP = 3;\n    var CHANNELCONTROL = 4;\n    var SOUND = 5;\n    var SOUNDGROUP = 6;\n    var DSP = 7;\n    var DSPCONNECTION = 8;\n    var GEOMETRY = 9;\n    var REVERB3D = 10;\n    var STUDIO_SYSTEM = 11;\n    var STUDIO_EVENTDESCRIPTION = 12;\n    var STUDIO_EVENTINSTANCE = 13;\n    var STUDIO_PARAMETERINSTANCE = 14;\n    var STUDIO_BUS = 15;\n    var STUDIO_VCA = 16;\n    var STUDIO_BANK = 17;\n    var STUDIO_COMMANDREPLAY = 18;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_FILE_ASYNCCANCEL_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_FILE_ASYNCDONE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. The function is called from FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_FILE_ASYNCREAD_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_FILE_CLOSE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_FILE_OPEN_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_FILE_READ_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_FILE_SEEK_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_INITFLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodInitFlags(Int) from Int to Int {\n    var NORMAL = 0x00000000;\n    var STREAM_FROM_UPDATE = 0x00000001;\n    var MIX_FROM_UPDATE = 0x00000002;\n    var _3D_RIGHTHANDED = 0x00000004;\n    var CLIP_OUTPUT = 0x00000008;\n    var CHANNEL_LOWPASS = 0x00000100;\n    var CHANNEL_DISTANCEFILTER = 0x00000200;\n    var PROFILE_ENABLE = 0x00010000;\n    var VOL0_BECOMES_VIRTUAL = 0x00020000;\n    var GEOMETRY_USECLOSEST = 0x00040000;\n    var PREFER_DOLBY_DOWNMIX = 0x00080000;\n    var THREAD_UNSAFE = 0x00100000;\n    var PROFILE_METER_ALL = 0x00200000;\n    var MEMORY_TRACKING = 0x00400000;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_OUTPUTTYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodOutputType(Int) from Int to Int {\n    var AUTODETECT = 0;\n    var UNKNOWN = 1;\n    var NOSOUND = 2;\n    var WAVWRITER = 3;\n    var NOSOUND_NRT = 4;\n    var WAVWRITER_NRT = 5;\n    var WASAPI = 6;\n    var ASIO = 7;\n    var PULSEAUDIO = 8;\n    var ALSA = 9;\n    var COREAUDIO = 10;\n    var AUDIOTRACK = 11;\n    var OPENSL = 12;\n    var AUDIOOUT = 13;\n    var AUDIO3D = 14;\n    var WEBAUDIO = 15;\n    var NNAUDIO = 16;\n    var WINSONIC = 17;\n    var AAUDIO = 18;\n    var AUDIOWORKLET = 19;\n    var PHASE = 20;\n    var OHAUDIO = 21;\n    var MAX = 22;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_PLUGINLIST": {
   "code": "package haxefmod.studio;\n\ntypedef FmodPluginList = {\n    var type:FmodPluginType;\n    /** The address of the plugin description, always 0 on the Haxe side. */\n    var description:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_PLUGINTYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodPluginType(Int) from Int to Int {\n    var OUTPUT = 0;\n    var CODEC = 1;\n    var DSP = 2;\n    var MAX = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_PORT_INDEX": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodPortIndex(Int) from Int to Int {\n    var NONE = -1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_PORT_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodPortType(Int) from Int to Int {\n    var MUSIC = 0;\n    var COPYRIGHT_MUSIC = 1;\n    var VOICE = 2;\n    var CONTROLLER = 3;\n    var PERSONAL = 4;\n    var VIBRATION = 5;\n    var AUX = 6;\n    var PASSTHROUGH = 7;\n    var VR_VIBRATION = 8;\n    var MAX = 9;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_REVERB_MAXINSTANCES": {
   "code": "package haxefmod.studio;\n\nclass FmodLimits {\n    /** FMOD_MAX_CHANNEL_WIDTH, the widest mix matrix and channel format. */\n    public static inline var MAX_CHANNEL_WIDTH = 32;\n    /** FMOD_MAX_SYSTEMS, how many FMOD systems one process may create. haxefmod creates one. */\n    public static inline var MAX_SYSTEMS = 8;\n    /** FMOD_MAX_LISTENERS, the cap on StudioSystem.setNumListeners. */\n    public static inline var MAX_LISTENERS = 8;\n    /** FMOD_REVERB_MAXINSTANCES, the number of reverb instance slots. */\n    public static inline var REVERB_MAXINSTANCES = 4;\n    /** FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT, the alignment loadBankMemory needs in point mode. */\n    public static inline var STUDIO_LOAD_MEMORY_ALIGNMENT = 32;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_REVERB_PRESETS": {
   "code": "package haxefmod.core;\n\nclass ReverbPresets {\n    public static var OFF(get, never):ReverbProperties;\n    static function get_OFF() return Reverb.PRESET_OFF;\n    public static var GENERIC(get, never):ReverbProperties;\n    static function get_GENERIC() return Reverb.PRESET_GENERIC;\n    public static var PADDEDCELL(get, never):ReverbProperties;\n    static function get_PADDEDCELL() return Reverb.PRESET_PADDEDCELL;\n    public static var ROOM(get, never):ReverbProperties;\n    static function get_ROOM() return Reverb.PRESET_ROOM;\n    public static var BATHROOM(get, never):ReverbProperties;\n    static function get_BATHROOM() return Reverb.PRESET_BATHROOM;\n    public static var LIVINGROOM(get, never):ReverbProperties;\n    static function get_LIVINGROOM() return Reverb.PRESET_LIVINGROOM;\n    public static var STONEROOM(get, never):ReverbProperties;\n    static function get_STONEROOM() return Reverb.PRESET_STONEROOM;\n    public static var AUDITORIUM(get, never):ReverbProperties;\n    static function get_AUDITORIUM() return Reverb.PRESET_AUDITORIUM;\n    public static var CONCERTHALL(get, never):ReverbProperties;\n    static function get_CONCERTHALL() return Reverb.PRESET_CONCERTHALL;\n    public static var CAVE(get, never):ReverbProperties;\n    static function get_CAVE() return Reverb.PRESET_CAVE;\n    public static var ARENA(get, never):ReverbProperties;\n    static function get_ARENA() return Reverb.PRESET_ARENA;\n    public static var HANGAR(get, never):ReverbProperties;\n    static function get_HANGAR() return Reverb.PRESET_HANGAR;\n    public static var CARPETTEDHALLWAY(get, never):ReverbProperties;\n    static function get_CARPETTEDHALLWAY() return Reverb.PRESET_CARPETTEDHALLWAY;\n    public static var HALLWAY(get, never):ReverbProperties;\n    static function get_HALLWAY() return Reverb.PRESET_HALLWAY;\n    public static var STONECORRIDOR(get, never):ReverbProperties;\n    static function get_STONECORRIDOR() return Reverb.PRESET_STONECORRIDOR;\n    public static var ALLEY(get, never):ReverbProperties;\n    static function get_ALLEY() return Reverb.PRESET_ALLEY;\n    public static var FOREST(get, never):ReverbProperties;\n    static function get_FOREST() return Reverb.PRESET_FOREST;\n    public static var CITY(get, never):ReverbProperties;\n    static function get_CITY() return Reverb.PRESET_CITY;\n    public static var MOUNTAINS(get, never):ReverbProperties;\n    static function get_MOUNTAINS() return Reverb.PRESET_MOUNTAINS;\n    public static var QUARRY(get, never):ReverbProperties;\n    static function get_QUARRY() return Reverb.PRESET_QUARRY;\n    public static var PLAIN(get, never):ReverbProperties;\n    static function get_PLAIN() return Reverb.PRESET_PLAIN;\n    public static var PARKINGLOT(get, never):ReverbProperties;\n    static function get_PARKINGLOT() return Reverb.PRESET_PARKINGLOT;\n    public static var SEWERPIPE(get, never):ReverbProperties;\n    static function get_SEWERPIPE() return Reverb.PRESET_SEWERPIPE;\n    public static var UNDERWATER(get, never):ReverbProperties;\n    static function get_UNDERWATER() return Reverb.PRESET_UNDERWATER;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_REVERB_PROPERTIES": {
   "code": "package haxefmod.core;\n\ntypedef ReverbProperties = {\n    /** Reverberation decay time (ms). */\n    var decayTime:Float;\n    /** Initial reflection delay (ms). */\n    var earlyDelay:Float;\n    /** Late reverberation delay relative to the initial reflection (ms). */\n    var lateDelay:Float;\n    /** Reference high frequency (Hz). */\n    var hfReference:Float;\n    /** High-frequency to mid-frequency decay time ratio (%). */\n    var hfDecayRatio:Float;\n    /** Echo density in the late reverberation decay (%). */\n    var diffusion:Float;\n    /** Modal density in the late reverberation decay (%). */\n    var density:Float;\n    /** Transition frequency of the low-shelf filter (Hz). */\n    var lowShelfFrequency:Float;\n    /** Gain of the low-shelf filter (dB). */\n    var lowShelfGain:Float;\n    /** Cutoff frequency of the low-pass filter (Hz). */\n    var highCut:Float;\n    /** Blend of late reverberation into early reflections (%). */\n    var earlyLateMix:Float;\n    /** Reverb signal level (dB). */\n    var wetLevel:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SYSTEM_CALLBACK": {
   "code": "package haxefmod.studio;\n\ntypedef SystemCallback = SystemEvent->Void;",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_SYSTEM_CALLBACK_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodSystemCallbackType(Int) from Int to Int {\n    var DEVICELISTCHANGED = 0x00000001;\n    var DEVICELOST = 0x00000002;\n    var MEMORYALLOCATIONFAILED = 0x00000004;\n    var THREADCREATED = 0x00000008;\n    var BADDSPCONNECTION = 0x00000010;\n    var PREMIX = 0x00000020;\n    var POSTMIX = 0x00000040;\n    var ERROR = 0x00000080;\n    var THREADDESTROYED = 0x00000100;\n    var PREUPDATE = 0x00000200;\n    var POSTUPDATE = 0x00000400;\n    var RECORDLISTCHANGED = 0x00000800;\n    var BUFFEREDNOMIX = 0x00001000;\n    var DEVICEREINITIALIZE = 0x00002000;\n    var OUTPUTUNDERRUN = 0x00004000;\n    var RECORDPOSITIONCHANGED = 0x00008000;\n    var ALL = 0xFFFFFFFF;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "System::setDSPBufferSize": {
   "code": "var mixer = CoreSystem.getDSPBufferSize();\nvar blocksize = mixer.bufferLength;\nvar numblocks = mixer.numBuffers;\nvar frequency = CoreSystem.getSoftwareFormat().sampleRate;\n\nvar ms = blocksize * 1000.0 / frequency;\n\ntrace('Mixer blocksize        = $ms ms');\ntrace('Mixer Total buffersize = ${ms * numblocks} ms');\ntrace('Mixer Average Latency  = ${ms * (numblocks - 1.5)} ms');",
   "notes": [],
   "type": "haxefmod.core.CoreSystem",
   "verdict": "bound"
  },
  "System::setSpeakerPosition": {
   "code": "CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, -1.0, 0.0, true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_RIGHT, 1.0, 0.0, true);",
   "notes": [],
   "type": "haxefmod.core.CoreSystem, haxefmod.studio.Types.FmodSpeaker",
   "verdict": "bound"
  },
  "System::setSpeakerPosition#3": {
   "code": "CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, Math.sin(degtorad(-30)), Math.cos(degtorad(-30)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_RIGHT, Math.sin(degtorad(30)), Math.cos(degtorad(30)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_CENTER, Math.sin(degtorad(0)), Math.cos(degtorad(0)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.LOW_FREQUENCY, Math.sin(degtorad(0)), Math.cos(degtorad(0)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.SURROUND_LEFT, Math.sin(degtorad(-90)), Math.cos(degtorad(-90)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.SURROUND_RIGHT, Math.sin(degtorad(90)), Math.cos(degtorad(90)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.BACK_LEFT, Math.sin(degtorad(-150)), Math.cos(degtorad(-150)), true);\nCoreSystem.setSpeakerPosition(FmodSpeaker.BACK_RIGHT, Math.sin(degtorad(150)), Math.cos(degtorad(150)), true);",
   "notes": [],
   "type": "haxefmod.core.CoreSystem, haxefmod.studio.Types.FmodSpeaker",
   "verdict": "bound"
  }
 },
 "dsp-plugin-api-guide": {
  "18.2.1 Building a Plug-in": {
   "code": null,
   "notes": [
    "Cannot be bound. The exported description function is part of a plug-in library written in C, and its callbacks run on FMOD's mixer thread where no Haxe target can run code. The built library loads with StudioSystem.loadPlugin."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "18.2.1 Building a Plug-in#2": {
   "code": null,
   "notes": [
    "Cannot be bound. The exported description function is part of a plug-in library written in C, and its callbacks run on FMOD's mixer thread where no Haxe target can run code. The built library loads with StudioSystem.loadPlugin."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "18.2.2 Loading the Plug-in in the Game": {
   "code": null,
   "notes": [
    "Cannot be bound. Registering from a description struct cannot be bound, because the struct carries callbacks that FMOD runs on its mixer thread and no Haxe target can run code there. A plug-in built into a shared library loads with StudioSystem.loadPlugin, which makes its effects available to Studio events and to Dsp.createByPlugin."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "18.2.2 Loading the Plug-in in the Game#2": {
   "code": "var handle = StudioSystem.loadPlugin(filename, 0);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "18.2.2 Loading the Plug-in in the Game#3": {
   "code": "var result = StudioSystem.setPluginPath(path);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "18.2.2 Loading the Plug-in in the Game#4": {
   "code": "// Studio::System::unregisterPlugin stays C side with plug-in registration (see 18.2.2).\nvar result = StudioSystem.unloadPlugin(handle);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "18.4 The Plug-in Descriptor": {
   "code": null,
   "notes": [
    "Cannot be bound. The descriptor is a C struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can run code there. A compiled plug-in loads with StudioSystem.loadPlugin and Dsp.getPluginInfo reads the name, version, and buffer counts it registered."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "18.7 Multiple Plug-ins Within One File": {
   "code": null,
   "notes": [
    "Cannot be bound. The plug-in list and the descriptors it points to are C code inside the plug-in library. A library that exports a list loads as one handle with StudioSystem.loadPlugin, and getNestedPluginCount and getNestedPlugin reach the plug-ins inside it."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "18.7 Multiple Plug-ins Within One File#2": {
   "code": "var baseHandle = StudioSystem.loadPlugin(\"plugin_name.dll\");\nif (baseHandle == 0) {\n    trace('loadPlugin failed: ${StudioSystem.lastResult()}');\n}\nvar count = StudioSystem.getNestedPluginCount(baseHandle);\nfor (index in 0...count) {\n    var handle = StudioSystem.getNestedPlugin(baseHandle, index);\n    var info = StudioSystem.getPluginInfo(handle);\n    if (info != null) {\n        var type = info.type;\n        // We have an output plug-in, a DSP plug-in, or a codec plug-in here.\n    }\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "fsbank-api": {
  "20.10 FSBANK_MEMORY_ALLOC_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. an allocator hook for the FSBank offline encoder, which is a separate tool library outside the FMOD runtime and is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.11 FSBANK_MEMORY_FREE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. an allocator hook for the FSBank offline encoder, which is a separate tool library outside the FMOD runtime and is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.12 FSBANK_MEMORY_REALLOC_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. an allocator hook for the FSBank offline encoder, which is a separate tool library outside the FMOD runtime and is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.13 FSBANK_INITFLAGS": {
   "code": null,
   "notes": [
    "Cannot be bound. init flags of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.14 FSBANK_BUILDFLAGS": {
   "code": null,
   "notes": [
    "Cannot be bound. build flags of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.15 FSBANK_FORMAT": {
   "code": null,
   "notes": [
    "Cannot be bound. the encoding formats of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.16 FSBANK_FSBVERSION": {
   "code": null,
   "notes": [
    "Cannot be bound. the output version of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.17 FSBANK_PROGRESSITEM": {
   "code": null,
   "notes": [
    "Cannot be bound. a build progress record of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.18 FSBANK_RESULT": {
   "code": null,
   "notes": [
    "Cannot be bound. the result codes of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.19 FSBANK_STATE": {
   "code": null,
   "notes": [
    "Cannot be bound. the build states of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.20 FSBANK_STATEDATA_FAILED": {
   "code": null,
   "notes": [
    "Cannot be bound. a build failure record of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.21 FSBANK_STATEDATA_WARNING": {
   "code": null,
   "notes": [
    "Cannot be bound. a build warning record of the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "20.22 FSBANK_SUBSOUND": {
   "code": null,
   "notes": [
    "Cannot be bound. the input description for the FSBank offline encoder, a separate tool library outside the FMOD runtime that is not bound"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "glossary": {
  "22.33 Reading Sound Data": {
   "code": "var sound:Sound;\nvar length:Int;\nvar buffer:haxe.io.Bytes;\n\nsound = Sound.create(\"drumloop.wav\", false, true); // openOnly is FMOD_OPENONLY\nlength = sound.getLength(FmodTimeUnit.RAWBYTES);\n\nbuffer = haxe.io.Bytes.alloc(length);\nvar read = sound.readData(buffer, length);\n\nbuffer = null;",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.studio.Types",
   "verdict": "bound"
  },
  "22.49 User Data": {
   "code": "{\n    var userData = \"Hello User Data!\";\n    sound.setUserData(userData);\n}\n{\n    var userData:String = sound.getUserData();\n}",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  }
 },
 "loading-and-playing-sounds-in-the-core-api": {
  "4.1.1 Non-blocking Sound Creation": {
   "code": "var sound = Sound.create(\"../media/wave.mp3\", false, false, ChannelMode.CREATESTREAM | ChannelMode.NONBLOCKING); // Returns at once, the stream opens on FMOD's thread.\nif (sound.isNull()) {\n    trace('load failed: ${StudioSystem.lastResult()}');\n}",
   "notes": [],
   "type": "haxefmod.core.ChannelMode, haxefmod.core.Sound",
   "verdict": "bound"
  },
  "4.1.1 Non-blocking Sound Creation#2": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD calls the callback on its async loader thread, no Haxe target can run code there. Poll Sound.getOpenState each frame instead, it reports READY once the sound can play and ERROR when the load failed."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "4.1.1 Non-blocking Sound Creation#3": {
   "code": "var sound = Sound.create(\"../media/wave.mp3\", false, false, ChannelMode.CREATESTREAM | ChannelMode.NONBLOCKING);\nif (sound.isNull()) {\n    trace(StudioSystem.lastResult());\n}\n\n// There is no nonblock callback to host, poll each frame until the sound is ready\nif (sound.getOpenState() == FmodOpenState.READY) {\n    startGame();\n}",
   "notes": [],
   "type": "haxefmod.core.ChannelMode, haxefmod.core.Sound, haxefmod.studio.Types.FmodOpenState",
   "verdict": "bound"
  },
  "4.2 Playing a sound": {
   "code": "var sound:Sound;\nvar channel:Channel;\n\nsound = Sound.create(\"../media/wave.mp3\");\nif (sound.isNull()) {\n    trace('load failed: ${StudioSystem.lastResult()}');\n}\n\nchannel = sound.play();\nif (channel.isNull()) {\n    trace('play failed: ${StudioSystem.lastResult()}');\n}",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.core.Channel",
   "verdict": "bound"
  },
  "4.3.1 Creating a Sound from memory": {
   "code": "var sound:Sound;\nvar buffer:haxe.io.Bytes = null;\n\n//\n// Load your file image (wav, ogg, mp3, fsb) into the \"buffer\" bytes here\n//\n\nsound = Sound.fromMemory(buffer); // The buffer's length is the length of the file image in bytes\n// The audio data stored in \"buffer\" has been duplicated into FMOD's buffers, and can now be freed",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  },
  "4.3.1 Creating a Sound from memory#2": {
   "code": null,
   "notes": [
    "No Haxe declaration, another call plays this role. there is no point-to-memory mode. Sound.fromMemory and Sound.fromPcm always copy the bytes, so nothing stays pinned and the buffer is free after the call."
   ],
   "type": null,
   "verdict": "covered"
  },
  "4.3.2 Creating a Sound from PCM data": {
   "code": "var sound:Sound;\nvar raw = sys.io.File.getBytes(\"./Your/File/Path/Here.raw\");\n\nsound = Sound.fromPcm(raw,\n    44100,   // Playback rate of sound\n    2);      // Number of channels in the sound",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  },
  "4.3.3 Creating a Sound by manually providing sample data": {
   "code": "var stream = PcmStream.create(\n    44100,                   // Playback rate of sound\n    2,                       // Number of channels in the sound\n    44100 * 2 * 2 * 5);      // Ring size in bytes. 2 = bytes per sample and 5 = seconds\n\n// Each frame, write sample data instead of a read callback\nvar buffer = haxe.io.Bytes.alloc(stream.space());\nfor (i in 0...Std.int(buffer.length / 2)) {\n    buffer.setUInt16(i * 2, nextSample() & 0xFFFF);\n}\nstream.write(buffer);",
   "notes": [],
   "type": "haxefmod.core.PcmStream",
   "verdict": "bound"
  },
  "4.3.4 Creating the Sound as a Streamed FSB File": {
   "code": "var sound:Sound;\n\nsound = Sound.create(\"../media/sounds.fsb\", false, false, ChannelMode.CREATESTREAM | ChannelMode.NONBLOCKING, 1);\nif (sound.isNull()) {\n    trace('load failed: ${StudioSystem.lastResult()}');\n}",
   "notes": [],
   "type": "haxefmod.core.ChannelMode, haxefmod.core.Sound",
   "verdict": "bound"
  },
  "4.5.1 Setup : Override FMOD's file system with callbacks": {
   "code": null,
   "notes": [
    "Cannot be bound. file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "4.5.1 Setup : Override FMOD's file system with callbacks#2": {
   "code": null,
   "notes": [
    "Cannot be bound. async file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "4.5.2 Defining the basics - opening and closing the file handle.": {
   "code": null,
   "notes": [
    "Cannot be bound. file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "4.5.3 Defining 'userasyncread'": {
   "code": null,
   "notes": [
    "Cannot be bound. async file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "4.5.4 Defining 'userasynccancel'": {
   "code": null,
   "notes": [
    "Cannot be bound. async file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "4.5.5 Filling out the FMOD_ASYNCREADINFO structure when performing a deferred read": {
   "code": null,
   "notes": [
    "Cannot be bound. the payload of an async read callback, which runs on FMOD's file threads and carries raw buffer pointers. Custom file systems are not exposed."
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "managing-resources-in-the-core-api": {
  "9.5.1 Use a Fixed-size Memory Pool.": {
   "code": "FmodManager.Initialize({memoryPoolSize: 4 * 1024 * 1024}); // allocate 4mb and pass it to the FMOD Engine to use.",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "platforms-android": {
  "Application Lifecycle Management": {
   "code": null,
   "notes": [
    "Cannot be bound. Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Application Lifecycle Management#2": {
   "code": "function onStart():Void {\n    CoreSystem.mixerResume();\n}\n\nfunction onStop():Void {\n    CoreSystem.mixerSuspend();\n}\n\nfunction onDestroy():Void {\n    CoreSystem.mixerResume();\n}",
   "notes": [],
   "type": "haxefmod.core.CoreSystem",
   "verdict": "bound"
  },
  "Java": {
   "code": null,
   "notes": [
    "Cannot be bound. Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Java#2": {
   "code": null,
   "notes": [
    "Cannot be bound. Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "platforms-html5": {
  "Application setup": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. FmodManager.Initialize does this through jaxe.js, which sets preRun, onRuntimeInitialized, and a 64 MB INITIAL_MEMORY on the FMOD object and calls FMODModule, the game's main becomes FmodManager.IsInitialized() polled from a loading scene or a handler passed to FmodRuntime.onceReady"
   ],
   "type": null,
   "verdict": "library"
  },
  "Audio Stability (Stuttering)": {
   "code": "FmodManager.Initialize({dspBufferSize: 2048, dspNumBuffers: 2});",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "CPU Overhead": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. jaxe.js does this at init, it reads the driver's rate with getDriverInfo and passes it to setSoftwareFormat when the sampleRate setting is 0 (the default), a game that wants another rate passes FmodManager.Initialize({sampleRate: 48000}) or sets -D haxefmod_sample_rate and reads the rate in use from CoreSystem.getSoftwareFormat()"
   ],
   "type": null,
   "verdict": "library"
  },
  "Direct from host, via FMOD's filesystem": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. the library fetches banks itself, FmodRuntime.banks.load (and the autoLoadBanks list in FmodSettings, resolved against bankFolder) fetches the path relative to the page and writes it into FMOD's virtual filesystem before calling loadBankFile, and loose audio files are not preloaded because the web build decodes FSB only"
   ],
   "type": null,
   "verdict": "library"
  },
  "Direct from host, via FMOD's filesystem#2": {
   "code": "var sound = Sound.create(\"/lion.wav\", false);\nif (sound.isNull()) {\n    trace(StudioSystem.lastResult());\n}",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  },
  "Flags using WASM pthread build": {
   "code": null,
   "notes": [
    "Cannot be bound. Emscripten link flags for a C or C++ program compiled against FMOD, a Haxe HTML5 build compiles to JavaScript and runs FMOD's prebuilt fmodstudio.js, there is nothing to link"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Libraries": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. the post-build step (haxefmod.tools.PostBuild) copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB into the output's lib folder and jaxe.js loads them, a Haxe project adds no script tag"
   ],
   "type": null,
   "verdict": "library"
  },
  "Libraries#2": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. the post-build step (haxefmod.tools.PostBuild) copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB into the output's lib folder and jaxe.js loads them, a Haxe project adds no script tag"
   ],
   "type": null,
   "verdict": "library"
  },
  "Overriding FMOD's 'window' handle.": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. jaxe.js runs in the page's own window and calls FMODModule from it, so the module sees the right window and nothing is overridden"
   ],
   "type": null,
   "verdict": "library"
  },
  "Setting and getting": {
   "code": "var name:String; // to store name of sound.\n\nname = sound.getName(); // the returned value. Assign it to the variable we want to keep.\n\ntrace(name);",
   "notes": [],
   "type": "haxefmod.core.Sound",
   "verdict": "bound"
  },
  "Using FMOD with C/C++": {
   "code": null,
   "notes": [
    "Cannot be bound. Emscripten link flags for a C or C++ program compiled against FMOD, a Haxe HTML5 build compiles to JavaScript and runs FMOD's prebuilt fmodstudio.js, there is nothing to link"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Using structures": {
   "code": null,
   "notes": [
    "No Haxe declaration, another call plays this role. FMOD_GUID is FmodGuid, the text form FMOD Studio shows, returned by EventDescription.getID and taken by StudioSystem.getEventByID, and FMOD_STUDIO_BANK_INFO is not exposed because StudioSystem.loadBankFile and StudioSystem.loadBankMemory load banks without file callbacks"
   ],
   "type": null,
   "verdict": "covered"
  },
  "Via callbacks": {
   "code": null,
   "notes": [
    "Cannot be bound. file callbacks run on FMOD's file threads and custom file systems are not exposed, fetch the bytes yourself and hand them to StudioSystem.loadBankMemory"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Via callbacks#2": {
   "code": null,
   "notes": [
    "Cannot be bound. file callbacks run on FMOD's file threads and custom file systems are not exposed, fetch the bytes yourself and hand them to StudioSystem.loadBankMemory"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Via callbacks#3": {
   "code": null,
   "notes": [
    "Cannot be bound. file callbacks run on FMOD's file threads and custom file systems are not exposed, fetch the bytes yourself and hand them to StudioSystem.loadBankMemory"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Via memory": {
   "code": "var sound = Sound.fromMemory(chars, ChannelMode.LOOP_OFF | ChannelMode.CREATESTREAM, chars.length);\nif (sound.isNull()) {\n    trace(StudioSystem.lastResult());\n}",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.core.ChannelMode",
   "verdict": "bound"
  }
 },
 "platforms-ios": {
  "Handling Interruptions": {
   "code": null,
   "notes": [
    "Cannot be bound. iOS is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only, on desktop CoreSystem.mixerSuspend and mixerResume play the role of the suspend callback"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Latency": {
   "code": null,
   "notes": [
    "Cannot be bound. iOS is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only, the matching sample rate and buffer size are set through FmodManager.Initialize settings"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "Multi-channel Output": {
   "code": null,
   "notes": [
    "Cannot be bound. iOS is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "platforms-mac": {
  "Latency": {
   "code": null,
   "notes": [
    "Cannot be bound. the output handle is a raw AudioUnit pointer used with CoreAudio calls in C, which Haxe code cannot hold or make. FmodSettings.dspBufferSize is the latency setting the library exposes"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "platforms-openharmony": {
  "JavaScript": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, this declares the ArkTS types of the platform's native module."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "JavaScript#2": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, this is the platform module's package manifest."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "JavaScript#3": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, this is an OpenHarmony project dependency entry."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "JavaScript#4": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, this imports the platform's native module."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "JavaScript#5": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, fmod.init here is the platform module's ability hook, not FMOD's System init."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "JavaScript#6": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, fmod.close here is the platform module's ability hook, not FMOD's System release."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "JavaScript#7": {
   "code": null,
   "notes": [
    "Cannot be bound. OpenHarmony is not a haxefmod target, this is the OpenHarmony window stage lifecycle callback."
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "platforms-uwp": {
  "Background Music": {
   "code": "var bgm = ChannelGroup.create(\"BGM\");\nCoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, bgm);\n\nvar channel = music.play(false, bgm);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup, haxefmod.core.CoreSystem, haxefmod.studio.Types",
   "verdict": "bound"
  },
  "Pass Through": {
   "code": "var passthrough = ChannelGroup.create(\"PASSTHROUGH\");\nCoreSystem.attachChannelGroupToPort(FmodPortType.PASSTHROUGH, FmodPortIndex.NONE, passthrough);\n\nvar channel = your_non_diegetic_sound.play(false, passthrough);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup, haxefmod.core.CoreSystem, haxefmod.studio.Types",
   "verdict": "bound"
  }
 },
 "platforms-win": {
  "ASIO and C#": {
   "code": "FmodManager.Initialize({output: FmodOutputType.ASIO, numChannels: 32});",
   "notes": [],
   "type": "haxefmod.studio.Types",
   "verdict": "bound"
  },
  "Background Music": {
   "code": "var bgm = ChannelGroup.create(\"BGM\");\nCoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, bgm);\n\nvar channel = music.play(false, bgm);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup, haxefmod.core.CoreSystem, haxefmod.studio.Types",
   "verdict": "bound"
  },
  "Pass Through": {
   "code": "var passthrough = ChannelGroup.create(\"PASSTHROUGH\");\nCoreSystem.attachChannelGroupToPort(FmodPortType.PASSTHROUGH, FmodPortIndex.NONE, passthrough);\n\nvar channel = your_non_diegetic_sound.play(false, passthrough);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup, haxefmod.core.CoreSystem, haxefmod.studio.Types",
   "verdict": "bound"
  }
 },
 "plugin-api-codec": {
  "FMOD_CODEC_ALLOC_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_CLOSE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_DESCRIPTION": {
   "code": null,
   "notes": [
    "Cannot be bound. codec plugins are written in C, Sound.create loads every format FMOD decodes and PcmStream feeds decoded audio"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_FILE_READ_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_FILE_SEEK_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_FILE_SIZE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_FILE_TELL_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_FREE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_GETLENGTH_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_GETPOSITION_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_GETWAVEFORMAT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_LOG_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_METADATA_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_OPEN_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_PLUGIN_VERSION": {
   "code": null,
   "notes": [
    "Cannot be bound. a codec plugin is built in C against this version, a prebuilt codec plugin binary loads with StudioSystem.loadPlugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_READ_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_SEEK_METHOD": {
   "code": null,
   "notes": [
    "Cannot be bound. only a codec plugin's seek function receives it, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_SETPOSITION_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_SOUNDCREATE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's threads inside a codec plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_STATE": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD hands it to codec plugin callbacks on its own threads, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_STATE_FUNCTIONS": {
   "code": null,
   "notes": [
    "Cannot be bound. codec plugins are written in C, Sound.create loads every format FMOD decodes and PcmStream feeds decoded audio"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_CODEC_WAVEFORMAT": {
   "code": null,
   "notes": [
    "Cannot be bound. a codec plugin fills it in C, game code reads a loaded sound's format through Sound.getFormat"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "plugin-api-dsp": {
  "FMOD_COMPLEX": {
   "code": null,
   "notes": [
    "Cannot be bound. the sample type of the plugin DFT helpers, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_ALLOC_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_BUFFER_ARRAY": {
   "code": null,
   "notes": [
    "Cannot be bound. the mixer buffers received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_BUFFER_ARRAY#2": {
   "code": null,
   "notes": [
    "Cannot be bound. the square wave is written into the mixer buffers inside a plugin's process callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create(DspType.OSCILLATOR) is the built-in square wave source"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_CREATE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_DESCRIPTION": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_DESCRIPTION#2": {
   "code": null,
   "notes": [
    "Cannot be bound. a plugin names itself in its description, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.getName reads the name of a created unit"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_DESCRIPTION#4": {
   "code": null,
   "notes": [
    "Cannot be bound. a plugin names itself in its description, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.getName reads the name of a created unit"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_DFT_FFTREAL_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_DFT_IFFTREAL_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_FREE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETBLOCKSIZE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETCLOCK_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETLISTENERATTRIBUTES_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETPARAM_BOOL_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETPARAM_DATA_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETPARAM_FLOAT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETPARAM_INT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETPARAM_VALUESTR_LENGTH": {
   "code": null,
   "notes": [
    "Cannot be bound. the size of the value string received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETSAMPLERATE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETSPEAKERMODE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_GETUSERDATA_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_LOG_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_METERING_INFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspMeteringInfo = {\n    var numSamples:Int;\n    var peakLevel:Array<Float>;\n    var rmsLevel:Array<Float>;\n    var numChannels:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PAN_SUMMONOMATRIX_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PAN_SURROUND_FLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspPanSurroundFlags(Int) from Int to Int {\n    var DEFAULT = 0;\n    var ROTATION_NOT_BIASED = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_3DATTRIBUTES": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameter3DAttributes = {\n    var relative:Fmod3DAttributes;\n    var absolute:Fmod3DAttributes;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameter3DAttributesMulti = {\n    var numListeners:Int;\n    var relative:Array<Fmod3DAttributes>;\n    var weight:Array<Float>;\n    var absolute:Fmod3DAttributes;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_ATTENUATION_RANGE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterAttenuationRange = {\n    var min:Float;\n    var max:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DATA_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspParameterDataType(Int) from Int to Int {\n    var USER = 0;\n    var OVERALLGAIN = -1;\n    var _3DATTRIBUTES = -2;\n    var SIDECHAIN = -3;\n    var FFT = -4;\n    var _3DATTRIBUTES_MULTI = -5;\n    var ATTENUATION_RANGE = -6;\n    var DYNAMIC_RESPONSE = -7;\n    var FINITE_LENGTH = -8;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DESC": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterDesc = {\n    var type:FmodDspParameterType;\n    var name:String;\n    var label:String;\n    var description:String;\n    var floatDesc:Null<FmodDspParameterDescFloat>;\n    var intDesc:Null<FmodDspParameterDescInt>;\n    var boolDesc:Null<FmodDspParameterDescBool>;\n    var dataDesc:Null<FmodDspParameterDescData>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DESC_BOOL": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterDescBool = {\n    var defaultVal:Bool;\n    var valueNames:Null<Array<String>>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DESC_DATA": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterDescData = {\n    var dataType:FmodDspParameterDataType;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DESC_FLOAT": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterDescFloat = {\n    var min:Float;\n    var max:Float;\n    var defaultVal:Float;\n    var mapping:FmodDspParameterFloatMapping;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DESC_INT": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterDescInt = {\n    var min:Int;\n    var max:Int;\n    var defaultVal:Int;\n    var goesToInf:Bool;\n    var valueNames:Null<Array<String>>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterDynamicResponse = {\n    var numChannels:Int;\n    var rms:Array<Float>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_FFT": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterFft = {\n    var length:Int;\n    var numChannels:Int;\n    var spectrum:Array<Array<Float>>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_FINITE_LENGTH": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterFiniteLength = {\n    var finite:Bool;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_FLOAT_MAPPING": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterFloatMapping = {\n    var type:FmodDspParameterFloatMappingType;\n    var piecewiseLinearMapping:FmodDspParameterFloatMappingPiecewiseLinear;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterFloatMappingPiecewiseLinear = {\n    var numPoints:Int;\n    var pointParamValues:Array<Float>;\n    var pointPositions:Array<Float>;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspParameterFloatMappingType(Int) from Int to Int {\n    var LINEAR = 0;\n    var AUTO = 1;\n    var PIECEWISE_LINEAR = 2;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_OVERALLGAIN": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterOverallGain = {\n    var linearGain:Float;\n    var linearGainAdditive:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_SIDECHAIN": {
   "code": "package haxefmod.studio;\n\ntypedef FmodDspParameterSidechain = {\n    var sidechainEnable:Bool;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PARAMETER_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspParameterType(Int) from Int to Int {\n    var FLOAT = 0;\n    var INT = 1;\n    var BOOL = 2;\n    var DATA = 3;\n    var MAX = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_PROCESS_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PROCESS_CALLBACK#2": {
   "code": null,
   "notes": [
    "Cannot be bound. the body of a DSP callback FMOD runs on its mixer thread, which Haxe code cannot host. Dsp.create and the built-in DspType units cover using effects, authoring one stays in C."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_PROCESS_OPERATION": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodDspProcessOperation(Int) from Int to Int {\n    var PERFORM = 0;\n    var QUERY = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_DSP_READ_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_READ_CALLBACK#2": {
   "code": null,
   "notes": [
    "Cannot be bound. the body of a DSP callback FMOD runs on its mixer thread, which Haxe code cannot host. Dsp.create and the built-in DspType units cover using effects, authoring one stays in C."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_REALLOC_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_RELEASE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_RESET_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SETPARAM_BOOL_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SETPARAM_DATA_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SETPARAM_FLOAT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SETPARAM_INT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SETPOSITION_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SHOULDIPROCESS_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SHOULDIPROCESS_CALLBACK#2": {
   "code": null,
   "notes": [
    "Cannot be bound. the question is received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.isIdle reports from game code whether a unit's inputs went idle"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_STATE": {
   "code": null,
   "notes": [
    "Cannot be bound. the per instance state received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_STATE#2": {
   "code": null,
   "notes": [
    "Cannot be bound. a plugin read callback keeping its phase in plugindata, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, the built-in oscillator unit (Dsp.create(DspType.OSCILLATOR)) plays the same tone from game code"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_STATE_DFT_FUNCTIONS": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_STATE_FUNCTIONS": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_STATE_PAN_FUNCTIONS": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SYSTEM_MIX_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_DSP_SYSTEM_REGISTER_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_PLUGIN_SDK_VERSION": {
   "code": null,
   "notes": [
    "Cannot be bound. the SDK version a compiled plugin is built against, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, StudioSystem.getPluginInfo reports a loaded plugin's version"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "plugin-api-output": {
  "FMOD_OUTPUT_ALLOC_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_CLOSEPORT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_CLOSE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_COPYPORT_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_DESCRIPTION": {
   "code": null,
   "notes": [
    "Cannot be bound. output plugins are written in C, FMOD initializes the platform's default output and StudioSystem.loadPlugin with CoreSystem.setOutputByPlugin selects a compiled one"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_DESCRIPTION#2": {
   "code": null,
   "notes": [
    "Cannot be bound. FMODGetOutputDescription is the export of a compiled plugin library, a plugin built this way is loaded with StudioSystem.loadPlugin and selected with CoreSystem.setOutputByPlugin"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_DEVICELISTCHANGED_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_FREE_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_GETDRIVERINFO_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_GETHANDLE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_GETNUMDRIVERS_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_INIT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_LOG_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_METHOD": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodOutputMethod(Int) from Int to Int {\n    var MIX_DIRECT = 0;\n    var MIX_BUFFERED = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_OUTPUT_MIXER_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_OBJECT3DALLOC_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_OBJECT3DFREE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_OBJECT3DGETINFO_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_OBJECT3DINFO": {
   "code": null,
   "notes": [
    "Cannot be bound. filled by FMOD for an output plugin's object3dupdate callback on the mixer thread, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_OBJECT3DUPDATE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_OPENPORT_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_PLUGIN_VERSION": {
   "code": null,
   "notes": [
    "Cannot be bound. the apiversion a compiled output plugin reports in its C description, no Haxe code writes one"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_READFROMMIXER_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_REQUESTRESET_FUNC": {
   "code": null,
   "notes": [
    "Cannot be bound. a helper FMOD hands to an output plugin through FMOD_OUTPUT_STATE, only plugin C code can call it"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_START_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_STATE": {
   "code": null,
   "notes": [
    "Cannot be bound. the per instance state FMOD passes to an output plugin's C callbacks, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_STOP_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_OUTPUT_UPDATE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. runs on FMOD's mixer thread inside an output plugin, plugin authoring is C only"
   ],
   "type": null,
   "verdict": "cannot"
  }
 },
 "running-the-core-api": {
  "3.1 Initializing the Core API": {
   "code": "var result:FmodResult;\n\nFmodManager.Initialize({numChannels: 512}); // Create the main system object and initialize FMOD.\nresult = StudioSystem.lastResult();\nif (result != FmodResult.FMOD_OK)\n{\n    trace('FMOD error! (${(result : Int)}) $result');\n}",
   "notes": [],
   "type": "haxefmod.studio.FmodResult",
   "verdict": "bound"
  }
 },
 "spatializing-sounds-in-the-core-api": {
  "5.0.2 Loading Sounds as 3D": {
   "code": "var handleError = (result:FmodResult) -> trace(result);\n\nvar sound = Sound.create(\"../media/drumloop.wav\", false, false, ChannelMode.MODE_3D);\nif (sound.isNull()) {\n    handleError(StudioSystem.lastResult());\n}",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.core.ChannelMode, haxefmod.studio.FmodResult",
   "verdict": "bound"
  },
  "5.1 Controlling a Spatializer DSP": {
   "code": "function dot(a:FmodVector, b:FmodVector):Float {\n    return a.x * b.x + a.y * b.y + a.z * b.z;\n}\n\nfunction cross(a:FmodVector, b:FmodVector):FmodVector {\n    return {x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x};\n}\n\nfunction toListenerSpace(v:FmodVector, listener:Fmod3DAttributes):FmodVector {\n    var right = cross(listener.up, listener.forward);\n    return {x: dot(v, right), y: dot(v, listener.up), z: dot(v, listener.forward)};\n}\n\nfunction calculatePannerAttributes(listener:Fmod3DAttributes, emitter:Fmod3DAttributes):FmodDspParameter3DAttributes {\n    var offset = {x: emitter.position.x - listener.position.x, y: emitter.position.y - listener.position.y, z: emitter.position.z - listener.position.z};\n    var motion = {x: emitter.velocity.x - listener.velocity.x, y: emitter.velocity.y - listener.velocity.y, z: emitter.velocity.z - listener.velocity.z};\n    return {\n        relative: {\n            position: toListenerSpace(offset, listener),\n            velocity: toListenerSpace(motion, listener),\n            forward: toListenerSpace(emitter.forward, listener),\n            up: toListenerSpace(emitter.up, listener)\n        },\n        absolute: emitter\n    };\n}",
   "notes": [],
   "type": "haxefmod.studio.Types",
   "verdict": "bound"
  },
  "5.1 Controlling a Spatializer DSP#2": {
   "code": "do\n{\n    updateGame();       // here the game is updated and the sources would be moved with channel.set3DAttributes.\n\n    StudioSystem.setListenerAttributes(0, {position: listenerPos, velocity: listenerVel, forward: listenerForward, up: listenerUp});     // update 'ears'\n\n    // the library runs the once-per-frame update itself.\n\n} while (gameRunning);",
   "notes": [],
   "type": "haxefmod.studio.Types",
   "verdict": "bound"
  },
  "5.1.1 Velocity": {
   "code": "var velx = (posx - lastposx) * 1000 / timedelta;\nvar vely = (posy - lastposy) * 1000 / timedelta;\nvar velz = (posz - lastposz) * 1000 / timedelta;",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "5.1.1 Velocity#2": {
   "code": "var vel = 0.1 * 1000 / 16.67; // 6 meters per second",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "5.1.1 Velocity#3": {
   "code": "var vel = 0.2 * 1000 / 33.33; // 6 meters per second",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "studio-api-commandreplay": {
  "FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD invokes it from its Studio update thread while the replay plays, and no Haxe target can run code there. The replay creates the instances itself, and CommandReplay.getCommandInfo reads each command from the game thread."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD invokes it from its Studio update thread while the replay plays, and no Haxe target can run code there. Poll CommandReplay.getCurrentCommand from the game thread for the index and time the replay is on."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK": {
   "code": null,
   "notes": [
    "Cannot be bound. FMOD invokes it from its Studio update thread while the replay plays, and no Haxe target can run code there. The replay loads the captured banks itself, and CommandReplay.setBankPath redirects where it reads them from."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "FMOD_STUDIO_COMMAND_INFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodCommandInfo = {\n    var commandName:String;\n    var parentCommandIndex:Int;\n    var frameNumber:Int;\n    var frameTime:Float;\n    var instanceType:FmodStudioInstanceType;\n    var outputType:FmodStudioInstanceType;\n    var instanceHandle:Int;\n    var outputHandle:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_INSTANCETYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodStudioInstanceType(Int) from Int to Int {\n    var NONE = 0;\n    var SYSTEM = 1;\n    var EVENTDESCRIPTION = 2;\n    var EVENTINSTANCE = 3;\n    var PARAMETERINSTANCE = 4;\n    var BUS = 5;\n    var VCA = 6;\n    var BANK = 7;\n    var COMMANDREPLAY = 8;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "studio-api-common": {
  "FMOD_STUDIO_LOADING_STATE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodLoadingState(Int) from Int to Int {\n    var UNLOADING = 0;\n    var UNLOADED = 1;\n    var LOADING = 2;\n    var LOADED = 3;\n    var ERROR = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_MEMORY_USAGE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodMemoryUsage = {\n    var exclusive:Int;\n    var inclusive:Int;\n    var sampledata:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PARAMETER_DESCRIPTION": {
   "code": "package haxefmod.studio;\n\ntypedef FmodParameterDescription = {\n    var name:String;\n    var id:FmodParameterId;\n    var minimum:Float;\n    var maximum:Float;\n    var defaultValue:Float;\n    var type:FmodParameterType;\n    var flags:Int;\n    /** The parameter's GUID, the same value lookupID returns for its path. */\n    var guid:FmodGuid;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PARAMETER_FLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodParameterFlags(Int) from Int to Int {\n    var READONLY = 0x00000001;\n    var AUTOMATIC = 0x00000002;\n    var GLOBAL = 0x00000004;\n    var DISCRETE = 0x00000008;\n    var LABELED = 0x00000010;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PARAMETER_ID": {
   "code": "package haxefmod.studio;\n\ntypedef FmodParameterId = {\n    var data1:Int;\n    var data2:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PARAMETER_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodParameterType(Int) from Int to Int {\n    var GAME_CONTROLLED = 0;\n    var AUTOMATIC_DISTANCE = 1;\n    var AUTOMATIC_EVENT_CONE_ANGLE = 2;\n    var AUTOMATIC_EVENT_ORIENTATION = 3;\n    var AUTOMATIC_DIRECTION = 4;\n    var AUTOMATIC_ELEVATION = 5;\n    var AUTOMATIC_LISTENER_ORIENTATION = 6;\n    var AUTOMATIC_SPEED = 7;\n    var AUTOMATIC_SPEED_ABSOLUTE = 8;\n    var AUTOMATIC_DISTANCE_NORMALIZED = 9;\n    var MAX = 10;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PLAYBACK_STATE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodPlaybackState(Int) from Int to Int {\n    var PLAYING = 0;\n    var SUSTAINING = 1;\n    var STOPPED = 2;\n    var STARTING = 3;\n    var STOPPING = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "studio-api-eventdescription": {
  "FMOD_STUDIO_USER_PROPERTY": {
   "code": "package haxefmod.studio;\n\ntypedef FmodUserProperty = {\n    var name:String;\n    var type:FmodUserPropertyType;\n    /** Numeric value (int/bool coerced). 0 for string properties. */\n    var floatValue:Float;\n    /** String value. \"\" for non-string properties. */\n    var stringValue:String;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_USER_PROPERTY_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodUserPropertyType(Int) from Int to Int {\n    var INTEGER = 0;\n    var BOOLEAN = 1;\n    var FLOAT = 2;\n    var STRING = 3;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "studio-api-eventinstance": {
  "FMOD_STUDIO_EVENT_CALLBACK": {
   "code": "package haxefmod.studio;\n\ntypedef EventCallback = EventCallbackData->Void;",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_EVENT_CALLBACK_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract EventCallbackType(Int) from Int to Int {\n    var CREATED = 0x00000001;\n    var DESTROYED = 0x00000002;\n    var STARTING = 0x00000004;\n    var STARTED = 0x00000008;\n    var RESTARTED = 0x00000010;\n    var STOPPED = 0x00000020;\n    var START_FAILED = 0x00000040;\n    var CREATE_PROGRAMMER_SOUND = 0x00000080;\n    var DESTROY_PROGRAMMER_SOUND = 0x00000100;\n    var PLUGIN_CREATED = 0x00000200;\n    var PLUGIN_DESTROYED = 0x00000400;\n    var TIMELINE_MARKER = 0x00000800;\n    var TIMELINE_BEAT = 0x00001000;\n    var SOUND_PLAYED = 0x00002000;\n    var SOUND_STOPPED = 0x00004000;\n    var REAL_TO_VIRTUAL = 0x00008000;\n    var VIRTUAL_TO_REAL = 0x00010000;\n    var START_EVENT_COMMAND = 0x00020000;\n    var NESTED_TIMELINE_BEAT = 0x00040000;\n    var ALL = 0xFFFFFFFF;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_EVENT_PROPERTY": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodEventProperty(Int) from Int to Int {\n    var CHANNELPRIORITY = 0;\n    var SCHEDULE_DELAY = 1;\n    var SCHEDULE_LOOKAHEAD = 2;\n    var MINIMUM_DISTANCE = 3;\n    var MAXIMUM_DISTANCE = 4;\n    var COOLDOWN = 5;\n    var MAX = 6;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES": {
   "code": "package haxefmod.studio;\n\ntypedef FmodPluginInstanceProperties = {\n    var name:String;\n    var dsp:haxefmod.core.Dsp;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES": {
   "code": "package haxefmod.studio;\n\ntypedef FmodProgrammerSoundProperties = {\n    var name:String;\n    var sound:haxefmod.core.Sound;\n    var subsoundIndex:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_STOP_MODE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodStopMode(Int) from Int to Int {\n    var ALLOWFADEOUT = 0;\n    var IMMEDIATE = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES": {
   "code": "package haxefmod.studio;\n\ntypedef FmodTimelineBeatProperties = {\n    var bar:Int;\n    var beat:Int;\n    var position:Int;\n    var tempo:Float;\n    var timeSignatureUpper:Int;\n    var timeSignatureLower:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES": {
   "code": "package haxefmod.studio;\n\ntypedef FmodTimelineMarkerProperties = {\n    var name:String;\n    var position:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES": {
   "code": "package haxefmod.studio;\n\ntypedef FmodTimelineNestedBeatProperties = {\n    var eventId:String;\n    var properties:FmodTimelineBeatProperties;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "studio-api-getting-started": {
  "12.1.1 Studio API Initialization": {
   "code": "var result:FmodResult;\n\nFmodManager.Initialize({numChannels: 512}); // Create and initialize the Studio system, which also initializes the Core system\nresult = StudioSystem.lastResult();\nif (result != FmodResult.FMOD_OK)\n{\n    trace('FMOD error! (${(result : Int)}) $result');\n}",
   "notes": [],
   "type": "haxefmod.studio.FmodResult",
   "verdict": "bound"
  }
 },
 "studio-api-system": {
  "FMOD_STUDIO_ADVANCEDSETTINGS": {
   "code": "package haxefmod.studio;\n\ntypedef FmodStudioAdvancedSettings = {\n    var commandQueueSize:Int;\n    var handleInitialSize:Int;\n    var studioUpdatePeriod:Int;\n    var idleSampleDataPoolSize:Int;\n    var streamingScheduleDelay:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_BANK_INFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodStudioBankInfo = {\n    var size:Int;\n    var userData:haxe.io.Bytes;\n    var userDataLength:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_BUFFER_INFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodBufferInfo = {\n    var currentUsage:Int;\n    var peakUsage:Int;\n    var capacity:Int;\n    var stallCount:Int;\n    var stallTime:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_BUFFER_USAGE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodBufferUsage = {\n    var studioCommandQueue:FmodBufferInfo;\n    var studioHandle:FmodBufferInfo;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_COMMANDCAPTURE_FLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodCommandCaptureFlags(Int) from Int to Int {\n    var NORMAL = 0x00000000;\n    var FILEFLUSH = 0x00000001;\n    var SKIP_INITIAL_STATE = 0x00000002;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_COMMANDREPLAY_FLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodCommandReplayFlags(Int) from Int to Int {\n    var NORMAL = 0x00000000;\n    var SKIP_CLEANUP = 0x00000001;\n    var FAST_FORWARD = 0x00000002;\n    var SKIP_BANK_LOAD = 0x00000004;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_CPU_USAGE": {
   "code": "package haxefmod.studio;\n\ntypedef FmodSystemCpuUsage = {\n    var studioUpdate:Float;\n    var dsp:Float;\n    var stream:Float;\n    var geometry:Float;\n    var update:Float;\n    var convolution1:Float;\n    var convolution2:Float;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_INITFLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodStudioInitFlags(Int) from Int to Int {\n    var NORMAL = 0x00000000;\n    var LIVEUPDATE = 0x00000001;\n    var ALLOW_MISSING_PLUGINS = 0x00000002;\n    var SYNCHRONOUS_UPDATE = 0x00000004;\n    var DEFERRED_CALLBACKS = 0x00000008;\n    var LOAD_FROM_UPDATE = 0x00000010;\n    var MEMORY_TRACKING = 0x00000020;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_LOAD_BANK_FLAGS": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodLoadBankFlags(Int) from Int to Int {\n    var NORMAL = 0;\n    var NONBLOCKING = 1;\n    var DECOMPRESS_SAMPLES = 2;\n    var UNENCRYPTED = 4;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT": {
   "code": "package haxefmod.studio;\n\nclass FmodLimits {\n    /** FMOD_MAX_CHANNEL_WIDTH, the widest mix matrix and channel format. */\n    public static inline var MAX_CHANNEL_WIDTH = 32;\n    /** FMOD_MAX_SYSTEMS, how many FMOD systems one process may create. haxefmod creates one. */\n    public static inline var MAX_SYSTEMS = 8;\n    /** FMOD_MAX_LISTENERS, the cap on StudioSystem.setNumListeners. */\n    public static inline var MAX_LISTENERS = 8;\n    /** FMOD_REVERB_MAXINSTANCES, the number of reverb instance slots. */\n    public static inline var REVERB_MAXINSTANCES = 4;\n    /** FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT, the alignment loadBankMemory needs in point mode. */\n    public static inline var STUDIO_LOAD_MEMORY_ALIGNMENT = 32;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_LOAD_MEMORY_MODE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodLoadMemoryMode(Int) from Int to Int {\n    var MEMORY = 0;\n    var MEMORY_POINT = 1;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_SOUND_INFO": {
   "code": "package haxefmod.studio;\n\ntypedef FmodSoundInfo = {\n    var name:String;\n    var mode:Int;\n    var length:Int;\n    var fileOffset:Int;\n    var initialSubsound:Int;\n    var numSubsounds:Int;\n    var subSoundIndex:Int;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_SYSTEM_CALLBACK": {
   "code": "package haxefmod.studio;\n\ntypedef SystemCallback = SystemEvent->Void;",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "FMOD_STUDIO_SYSTEM_CALLBACK_TYPE": {
   "code": "package haxefmod.studio;\n\nenum abstract FmodStudioSystemCallbackType(Int) from Int to Int {\n    var PREUPDATE = 0x00000001;\n    var POSTUPDATE = 0x00000002;\n    var BANK_UNLOAD = 0x00000004;\n    var LIVEUPDATE_CONNECTED = 0x00000008;\n    var LIVEUPDATE_DISCONNECTED = 0x00000010;\n    var ALL = 0xFFFFFFFF;\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  }
 },
 "studio-guide": {
  "13.9.1 Scripting Example": {
   "code": "class ProgrammerSoundContext {\n    public var coreSystem:Class<CoreSystem>;\n    public var system:Class<StudioSystem>;\n    public var dialogueString:String;\n    public function new() {}\n}\n\nvar programmerSoundContext = new ProgrammerSoundContext();\nprogrammerSoundContext.system = StudioSystem;\nprogrammerSoundContext.coreSystem = CoreSystem;",
   "notes": [],
   "type": "haxefmod.core.CoreSystem, haxefmod.studio.StudioSystem",
   "verdict": "bound"
  },
  "13.9.1 Scripting Example#2": {
   "code": "// The library owns the programmer-sound callback and its user data.\nvar result = eventInstance.assignProgrammerSound(key);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "13.9.1 Scripting Example#3": {
   "code": "// Available banks\n// \"Dialogue_EN.bank\", \"Dialogue_JP.bank\", \"Dialogue_CN.bank\"\nvar localizedBank:Bank = StudioSystem.loadBankFile(\"Dialogue_JP.bank\", FmodLoadBankFlags.NORMAL);\neventInstance.assignProgrammerSound(\"welcome\");\neventInstance.start();",
   "notes": [],
   "type": "haxefmod.studio.Bank, haxefmod.studio.Types.FmodLoadBankFlags",
   "verdict": "bound"
  },
  "13.9.1 Scripting Example#4": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. The programmer sound callback runs on FMOD's thread and is implemented once natively for every instance that has an assignment. EventInstance.setCallback delivers ProgrammerSoundCreated(properties) and ProgrammerSoundDestroyed(properties) on the game thread with the FmodProgrammerSoundProperties FMOD filled (instrument name, sound, subsound index), for observation and cleanup. An event with several programmer instruments assigns one key per instrument name with assignProgrammerSoundForName or assignProgrammerSounds."
   ],
   "type": null,
   "verdict": "library"
  },
  "13.9.1 Scripting Example#5": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. The create callback body runs natively when the instrument triggers. It looks the instrument name up in the name map, falls back to the single key, calls getSoundInfo, creates the sound with FMOD_LOOP_NORMAL, FMOD_CREATECOMPRESSEDSAMPLE, and FMOD_NONBLOCKING plus the mode getSoundInfo reports, and fills the properties. A key that matches no audio table entry is opened as a plain file path. A sound assigned with assignProgrammerSoundFrom is handed over as is, with its subsound index. StudioSystem.getSoundInfo(key) shows the name and subsound index a key resolves to."
   ],
   "type": null,
   "verdict": "library"
  },
  "13.9.1 Scripting Example#6": {
   "code": null,
   "notes": [
    "No Haxe declaration, the library owns this choice. The destroy callback runs natively and releases the sound it created when the instrument ends. A sound assigned with assignProgrammerSoundFrom stays with the game. EventInstance.clearProgrammerSound drops every assignment when an instance is reused for a different line."
   ],
   "type": null,
   "verdict": "library"
  }
 },
 "using-dsp-effects-in-the-core-api": {
  "7.2 Plug-in DSP Effects": {
   "code": null,
   "notes": [
    "Cannot be bound. registerPlugin and registerDSP take a DSP description whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A plug-in compiled from C loads with StudioSystem.loadPlugin, which registers its effects for Studio events and Dsp.createByPlugin."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "7.2 Plug-in DSP Effects#2": {
   "code": "var handle = StudioSystem.loadPlugin(filename, 0);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "7.2 Plug-in DSP Effects#3": {
   "code": "var result = StudioSystem.setPluginPath(path);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "7.2 Plug-in DSP Effects#4": {
   "code": "// Studio::System::unregisterPlugin stays C side with plug-in registration (see 7.2).\nvar result = StudioSystem.unloadPlugin(handle);",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "7.2.1 The Plug-in Descriptor": {
   "code": null,
   "notes": [
    "Cannot be bound. the descriptor is the C struct a plug-in author fills in, and its callbacks run on FMOD's mixer thread where no Haxe target can execute code. A compiled plug-in loads with StudioSystem.loadPlugin and Dsp.getPluginInfo reads back the name, version, and buffer counts it declared."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "7.2.4 Multiple plug-ins within one file": {
   "code": null,
   "notes": [
    "Cannot be bound. the plug-in list and its exported FMODGetPluginDescriptionList are C code compiled into the plug-in binary. A file that exports a list loads as one handle with StudioSystem.loadPlugin, and StudioSystem.getNestedPlugin walks the plug-ins inside it."
   ],
   "type": null,
   "verdict": "cannot"
  },
  "7.2.4 Multiple plug-ins within one file#2": {
   "code": "var baseHandle = StudioSystem.loadPlugin(\"plugin_name.dll\");\nif (baseHandle == 0) {\n    trace('loadPlugin failed: ${StudioSystem.lastResult()}');\n}\nvar count = StudioSystem.getNestedPluginCount(baseHandle);\nfor (index in 0...count) {\n    var handle = StudioSystem.getNestedPlugin(baseHandle, index);\n    var info = StudioSystem.getPluginInfo(handle);\n    if (info == null) {\n        trace('getPluginInfo failed: ${StudioSystem.lastResult()}');\n        continue;\n    }\n    var type = info.type;\n    // We have an output plug-in, a DSP plug-in, or a codec plug-in here.\n}",
   "notes": [],
   "type": null,
   "verdict": "bound"
  },
  "Add a DSP effect to a Channel": {
   "code": "var channel = sound.play();\nvar dsp_echo = Dsp.create(DspType.ECHO);\nvar result = channel.addDsp(0, dsp_echo);",
   "notes": [],
   "type": "haxefmod.core.Sound, haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Add a DSP effect to a Channel#2": {
   "code": "var result = channel.setDspIndex(dsp_echo, 1);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Add a DSP effect to a Channel#3": {
   "code": "var channelgroup = ChannelGroup.create(\"my channelgroup\");\nvar result = channel.setChannelGroup(channelgroup);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup",
   "verdict": "bound"
  },
  "Add an effect to the ChannelGroup": {
   "code": "var dsp_lowpass = Dsp.create(DspType.LOWPASS);\nvar result = channelgroup.addDsp(1, dsp_lowpass);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup, haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Bypass an effect / disable it.": {
   "code": "var dsp_reverb = Dsp.create(DspType.SFXREVERB);\nvar result = dsp_reverb.setBypass(true);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Controlling mix level and pan matrices for DSPConnections": {
   "code": "var channel = sound.play(true, channelgroup);                                       /* Play the sound.  Play it paused so we dont hear the sound play before it is connected to the reverb. */\nvar channel_dsp_head = channel.getDsp(Channel.DSP_HEAD);                            /* Grab the 'head' unit for the Channel */\nvar dsp_connection = dsp_reverb.addInput(channel_dsp_head);                         /* Manually add a connection from the Channel DSP head to the reverb. */\nvar result = channel.setPaused(false);                                              /* Unpause the channel and let it be audible. */",
   "notes": [],
   "type": "haxefmod.core.Channel, haxefmod.core.Sound, haxefmod.core.ChannelGroup, haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Controlling mix level and pan matrices for DSPConnections#2": {
   "code": "var result = dsp_connection.setMix(0.0);",
   "notes": [],
   "type": "haxefmod.core.Channel, haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Creating an effect and making all Channels send to it.": {
   "code": "var dsp_reverb = Dsp.create(DspType.SFXREVERB);                                     /* Create the reverb DSP */\nvar channelgroup_master = ChannelGroup.master();                                    /* Grab the master ChannelGroup / master bus */\nvar dsp_tail = channelgroup_master.getDsp(ChannelGroup.DSP_TAIL);                  /* Grab the 'tail' unit for the master ChannelGroup.  This is the last DSP unit for the ChannelGroup, in case it has other effects already in it. */\nvar connection = dsp_tail.addInput(dsp_reverb);",
   "notes": [],
   "type": "haxefmod.core.ChannelGroup, haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Creating an effect and making all Channels send to it.#2": {
   "code": "var dsp_reverb = Dsp.create(DspType.SFXREVERB);\nvar result = dsp_reverb.setActive(true);",
   "notes": [],
   "type": "haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Creating an effect and making all Channels send to it.#3": {
   "code": "var channel = sound.play(true, channelgroup);                                       /* Play the sound.  Play it paused so we dont hear the sound play before it is connected to the reverb. */\nvar channel_dsp_head = channel.getDsp(Channel.DSP_HEAD);                            /* Grab the 'head' unit for the Channel */\nvar connection = dsp_reverb.addInput(channel_dsp_head);                             /* Manually add a connection from the Channel DSP head to the reverb. */\nvar result = channel.setPaused(false);                                              /* Unpause the channel and let it be audible. */",
   "notes": [],
   "type": "haxefmod.core.Channel, haxefmod.core.Sound, haxefmod.core.ChannelGroup, haxefmod.core.Dsp, haxefmod.core.DspType",
   "verdict": "bound"
  },
  "Set the output format of a DSP unit, and control the pan matrix for its output signal": {
   "code": "var result = channel_dsp_head.setChannelFormat(0, 0, FmodSpeakerMode.QUAD);",
   "notes": [],
   "type": "haxefmod.core.Channel, haxefmod.core.Dsp, haxefmod.studio.Types.FmodSpeakerMode",
   "verdict": "bound"
  },
  "Set the output format of a DSP unit, and control the pan matrix for its output signal#2": {
   "code": "var matrix:Array<Float> =\n[   /*                                    FL FR SL SR <- Input signal (columns) */\n    /* row 0 = front left  out    <- */    0, 0, 0, 0,\n    /* row 1 = front right out    <- */    0, 0, 0, 0,\n    /* row 2 = surround left out  <- */    1, 0, 0, 0,\n    /* row 3 = surround right out <- */    0, 1, 0, 0\n];\nvar channel_dsp_head_output_connection = channel_dsp_head.getOutputConnection(0);\nvar result = channel_dsp_head_output_connection.setMixMatrix(matrix, 4, 4);",
   "notes": [],
   "type": "haxefmod.core.Channel, haxefmod.core.Dsp",
   "verdict": "bound"
  }
 },
 "welcome-whats-new-201": {
  "Thread attributes": {
   "code": "FmodManager.Initialize({threadAttributes: [\n    {type: FmodThreadType.STREAM, stackSize: stackSizeStream},\n    {type: FmodThreadType.NONBLOCKING, stackSize: stackSizeNonBlocking},\n    {type: FmodThreadType.MIXER, stackSize: stackSizeMixer},\n]});",
   "notes": [],
   "type": "haxefmod.studio.Types",
   "verdict": "bound"
  },
  "Thread attributes#2": {
   "code": "FmodManager.Initialize({threadAttributes: [\n    {type: FmodThreadType.MIXER, affinity: FmodThreadAffinity.CORE_5},\n    {type: FmodThreadType.STREAM, affinity: FmodThreadAffinity.CORE_3},\n]});",
   "notes": [],
   "type": "haxefmod.studio.Types",
   "verdict": "bound"
  }
 }
};

(function () {
    var style = document.createElement("style");
    style.textContent = "/* The site's .highlight box carries 6px of padding and a grey fill. The\n   note pulls back out to the box edge, draws a rule, and sits on white\n   so the code and the prose read as two things. */\n.haxefmod-block .haxefmod-note {\n    font-size: 14px;\n    line-height: 1.5;\n    margin: 10px -6px -6px -6px;\n    padding: 8px 12px 6px 12px;\n    border-top: 1px solid #b3b3b3;\n    background: #ffffff;\n    color: #333333;\n}\n\n.haxefmod-block .haxefmod-note p {\n    margin: 4px 0;\n}\n\n.haxefmod-block .haxefmod-type {\n    font-family: monospace;\n    font-size: 13px;\n    color: #555555;\n}\n\n.haxefmod-block .haxefmod-warn-title {\n    color: #a40000;\n    font-weight: bold;\n}\n\n.haxefmod-block .haxefmod-warn ul {\n    margin: 2px 0 6px 0;\n    padding-left: 20px;\n}\n\n.haxefmod-block .haxefmod-warn li {\n    margin: 2px 0;\n}\n\n.haxefmod-block .haxefmod-footer {\n    color: #666666;\n    font-size: 12px;\n}\n\n.haxefmod-block .haxefmod-footer a {\n    color: #666666;\n    text-decoration: underline;\n}\n\n/* The site sizes every tab for two or three characters (max-width 30px),\n   which pushes \"Haxe\" off center. Match the site's selector specificity\n   and give the word its room. */\n#Documentation div.documentation-content div.language-tab.haxefmod-tab,\n#Documentation div.searchresults div.language-tab.haxefmod-tab {\n    max-width: 40px;\n    text-align: center;\n}\n\n/* The extension keeps the clicked tab in place itself, so the browser's own anchoring must not move the page as blocks change height. */\ndiv.manual-content {\n    overflow-anchor: none;\n}\n";
    document.documentElement.appendChild(style);
})();

// Adds a "Haxe" language tab to every function on the fmod.com API
// reference. The site renders each function as an h2[api="function"], a
// language selector with C, C++, C#, and JS tabs, and one highlight block
// per language. This script appends a fifth tab and block, filled from
// HAXEFMOD_BINDINGS (bindings-data.js, generated by ci/haxe-bindings.py), and does the same for
// every other code block from HAXEFMOD_EXAMPLES (examples-data.js,
// generated by ci/haxe-catalog.py), keyed by extension/keys.js.
//
// The site's own selector only knows its four language classes, so the
// Haxe tab manages its own selection state and hides itself when another
// tab is picked.
(function () {
    "use strict";

    var LANG = "language-haxe";
    var STORAGE_KEY = "FMOD.Documents.selected-language";
    // The site validates the stored language against the ones a page
    // offers and rewrites the key when it finds ours, so the Haxe choice
    // keeps its own flag as well.
    var OWN_KEY = "haxefmod.selected";
    var NATIVE_LANGS = ["language-c", "language-cpp", "language-c-cpp", "language-csharp", "language-javascript"];
    var GUIDES = "https://tanz0rz.github.io/haxe-fmod/";
    var DATA = typeof HAXEFMOD_BINDINGS !== "undefined" ? HAXEFMOD_BINDINGS : null;
    var EXAMPLES = typeof HAXEFMOD_EXAMPLES !== "undefined" ? HAXEFMOD_EXAMPLES : {};

    if (!DATA) return;

    function pageName() {
        var file = window.location.pathname.split("/").pop() || "";
        return file.replace(/\.html$/, "");
    }

    var WARN_COLOR = "#a40000";

    function el(tag, className, text) {
        var node = document.createElement(tag);
        if (className) node.className = className;
        if (text != null) node.textContent = text;
        // The site styles text inside highlight blocks with rules that win
        // over a content script's stylesheet, so the warning colour goes
        // on the element itself
        if (className && className.indexOf("haxefmod-warn-title") >= 0) node.style.color = WARN_COLOR;
        return node;
    }

    function shortType(type) {
        return type.split(".").pop();
    }

    // Splits an argument list on the commas outside <>, {}, and ().
    function splitArgs(text) {
        var out = [];
        var depth = 0;
        var current = "";
        for (var i = 0; i < text.length; i++) {
            var c = text.charAt(i);
            if (c === "<" || c === "{" || c === "(") depth++;
            if (c === ">" || c === "}" || c === ")") depth--;
            if (c === "," && depth === 0) { out.push(current.trim()); current = ""; continue; }
            current += c;
        }
        if (current.trim()) out.push(current.trim());
        return out;
    }

    // The site prints a zero-argument signature on one line and every
    // other signature with one argument per line, ending with a
    // semicolon. The Haxe tab follows that shape.
    function formatSignature(prefix, signature) {
        var open = signature.indexOf("(");
        var close = signature.lastIndexOf(")");
        var name = signature.slice(0, open);
        var args = splitArgs(signature.slice(open + 1, close));
        var ret = signature.slice(close + 1);
        if (args.length === 0) return prefix + "." + name + "()" + ret + ";";
        return prefix + "." + name + "(\n  " + args.join(",\n  ") + "\n)" + ret + ";";
    }

    // Static methods are called on the type, instance methods on a value
    // of it, which the receiver name shows without a comment.
    // The site prints every language as a type-qualified declaration
    // (Sound::set3DConeSettings, Studio.EventInstance.start), so the Haxe
    // tab qualifies with the Haxe type the same way, static or not.
    // The other tabs qualify the function with its package (C# prints
    // Studio.EventInstance.start), so the Haxe tab prints the full type
    // path, which is the valid Haxe form of the same reference
    function receiver(m) {
        return m.type;
    }

    function renderBlock(entry) {
        var block = el("div", "highlight " + LANG + " haxefmod-block");
        block.style.display = "none";
        var pre = el("pre");
        var note = el("div", "haxefmod-note");

        var notes = entry && entry.notes ? entry.notes : [];
        if (!entry || entry.haxe.length === 0) {
            // A function haxefmod does not reach shows one comment line:
            // the verdict and its reason from functions.md ("Cannot be
            // bound. ...", "No Haxe declaration, another call plays this
            // role. ...", or the library's own step). No note at all is a
            // gap in the notes file, so say so on the page.
            if (!notes.length) {
                pre.textContent = "// Not exposed by haxefmod";
                note.appendChild(el("p", "haxefmod-warn", "haxefmod has no binding for this function and no note explaining why. Please report it."));
            } else {
                pre.textContent = "// " + notes[0];
            }
        } else {
            var direct = entry.haxe.filter(function (m) { return m.direct; });
            var also = entry.haxe.filter(function (m) { return !m.direct; });
            var shown = direct.length ? direct : also;
            var rest = direct.length ? also : [];
            var lines = [];
            shown.forEach(function (m, i) {
                if (i > 0) lines.push("");
                lines.push(formatSignature(receiver(m), m.signature));
            });
            pre.textContent = lines.join("\n");


            // The page already describes the function above the tabs, so
            // the note carries only what is specific to the Haxe side.
            if (rest.length) {
                var names = rest.map(function (m) { return shortType(m.type) + "." + m.name; });
                note.appendChild(el("p", null, "Also reaches this function: " + names.join(", ")));
            }
            if (entry.gated) {
                var warn = el("div", "haxefmod-warn");
                warn.appendChild(el("p", "haxefmod-warn-title", "HTML5 BUILD TARGET UNSUPPORTED"));
                var list = el("ul", "haxefmod-warn-list");
                list.appendChild(el("li", "haxefmod-warn-item", "FMOD's web build does not support this feature, so the call does not compile in a js build."));
                list.appendChild(el("li", "haxefmod-warn-item", "The build flag haxefmod_html5_allow_unsupported compiles it anyway, and it then returns FMOD_ERR_UNSUPPORTED at runtime."));
                warn.appendChild(list);
                note.appendChild(warn);
            } else if (entry.html5) {
                var limited = el("p", "haxefmod-warn");
                limited.appendChild(el("span", "haxefmod-warn-title", "Warning - "));
                limited.appendChild(document.createTextNode("HTML5: FMOD's web build does not support this call, haxefmod reports FMOD_ERR_UNSUPPORTED there."));
                note.appendChild(limited);
            }
            notes.forEach(function (text) { note.appendChild(el("p", null, text)); });
        }

        note.appendChild(footer());

        block.appendChild(pre);
        block.appendChild(note);
        return block;
    }

    function footer() {
        var line = el("p", "haxefmod-footer");
        line.appendChild(document.createTextNode("haxefmod " + DATA.haxefmod + " for FMOD " + DATA.fmod + ". "));
        var link = el("a", null, "Guides and API reference");
        link.href = GUIDES;
        link.target = "_blank";
        line.appendChild(link);
        return line;
    }

    // A guide example: hand-written Haxe for the C++ sample above it, or
    // a note when haxefmod has no equivalent.
    // A guide example shows code only, like the other tabs. A note that
    // explains a difference rides along as comment lines above the code,
    // and an example with no Haxe equivalent is a comment on its own.
    function renderExample(example) {
        var block = el("div", "highlight " + LANG + " haxefmod-block");
        block.style.display = "none";
        var lines = [];
        example.notes.forEach(function (text) { lines.push("// " + text); });
        if (example.code != null) {
            if (lines.length) lines.push("");
            lines.push(example.code);
        }
        var pre = el("pre");
        pre.textContent = lines.join("\n");
        block.appendChild(pre);
        var note = el("div", "haxefmod-note");
        if (example.type) note.appendChild(el("p", "haxefmod-type", example.type));
        note.appendChild(footer());
        block.appendChild(note);
        return block;
    }

    function lastHighlight(selector) {
        var last = null;
        var node = selector.nextElementSibling;
        while (node) {
            var isHighlight = node.tagName === "DIV" && node.classList.contains("highlight");
            var isSpacer = node.tagName === "P" && node.textContent.trim() === "";
            if (isHighlight) last = node;
            else if (!isSpacer) break;
            node = node.nextElementSibling;
        }
        return last;
    }

    function addTab(selector, block) {
        var anchor = lastHighlight(selector);
        if (!anchor) return false;
        var tab = el("div", "language-tab haxefmod-tab", "Haxe");
        tab.setAttribute("data-language", LANG);
        selector.appendChild(tab);
        anchor.parentNode.insertBefore(block, anchor.nextSibling);
        return true;
    }

    // Lone examples get a selector of their own so the Haxe tab has a
    // place to live. A run of per-language variants (one lone block per
    // language, folded by keys.js) shares a single selector with one
    // tab per language, so it reads like any tabbed unit on the site.
    var LABELS = { "language-c": "C", "language-cpp": "C++", "language-c-cpp": "C/C++", "language-csharp": "C#", "language-javascript": "JS" };
    var PLAIN_LABELS = { "language-java": "Java", "language-javaScript": "JS", "language-objective-c": "Objective-C", "language-html": "HTML" };

    // A block the site's selector never toggles: another language
    // (java, objective-c), or no language class at all.
    function plainLabel(node) {
        for (var i = 0; i < node.classList.length; i++) {
            var cls = node.classList[i];
            if (PLAIN_LABELS[cls]) return PLAIN_LABELS[cls];
        }
        return "Code";
    }

    function selectorForGroup(unit) {
        var selector = el("div", "language-selector haxefmod-selector");
        selector.setAttribute("data-haxefmod-count", String(unit.members.length));
        selector.setAttribute("data-haxefmod-langs", unit.langs.join(" "));
        for (var i = 0; i < unit.langs.length; i++) {
            var tab = el("div", "language-tab", LABELS[unit.langs[i]] || "Code");
            tab.setAttribute("data-language", unit.langs[i]);
            selector.appendChild(tab);
        }
        if (unit.langs.length === 0) {
            var lone = el("div", "language-tab", plainLabel(unit.members[0]));
            lone.setAttribute("data-language", "language-all");
            selector.appendChild(lone);
        }
        unit.members[0].parentNode.insertBefore(selector, unit.members[0]);
        return selector;
    }

    // The site's selector never learns about the strips this script
    // adds, so their visibility is managed here: a strip shows when Haxe
    // is the language, or when the pick is one of the languages its
    // blocks cover. A strip over blocks the site never toggles (no
    // language class) stays up. Native tabs get their selected state
    // from the site's own pass over every .language-tab.
    function updateStrips(selected) {
        var strips = document.querySelectorAll(".haxefmod-selector");
        for (var i = 0; i < strips.length; i++) {
            var langs = (strips[i].getAttribute("data-haxefmod-langs") || "").split(" ").filter(Boolean);
            var show = selected === LANG || langs.length === 0 || langs.indexOf(selected) >= 0;
            strips[i].style.display = show ? "" : "none";
            if (selected !== LANG) {
                var tabs = strips[i].querySelectorAll(".language-tab");
                for (var j = 0; j < tabs.length; j++) {
                    tabs[j].classList.toggle("selected", tabs[j].getAttribute("data-language") === selected);
                }
            }
        }
    }

    function current() {
        if (haxeChosen()) return LANG;
        try {
            var saved = window.localStorage.getItem(STORAGE_KEY);
            if (saved && saved !== LANG) return saved;
        } catch (e) { /* fall through to the site's default */ }
        return "language-cpp";
    }

    // Every code location on the page is keyed by extension/keys.js, the
    // same way the catalog was built, and looked up by that key.
    function injectAll() {
        var root = document.querySelector("div.manual-content");
        if (!root || typeof haxefmodKeys === "undefined") return false;
        var units = haxefmodKeys.grouped(haxefmodKeys.units(root));
        var examples = EXAMPLES[pageName()] || {};
        for (var i = 0; i < units.length; i++) {
            var unit = units[i];
            if (unit.added) continue;
            var nodes = unit.members || [unit.node];
            var done = false;
            for (var n = 0; n < nodes.length; n++) if (nodes[n].dataset.haxefmod) done = true;
            if (done) continue;
            var block;
            if (unit.kind === "function") {
                block = renderBlock(DATA.entries[unit.key]);
            } else if (examples[unit.key]) {
                block = renderExample(examples[unit.key]);
            } else {
                continue;
            }
            if (unit.tabbed) {
                if (addTab(unit.node, block)) unit.node.dataset.haxefmod = "1";
                continue;
            }
            var selector = selectorForGroup(unit);
            var tab = el("div", "language-tab haxefmod-tab", "Haxe");
            tab.setAttribute("data-language", LANG);
            selector.appendChild(tab);
            var last = nodes[nodes.length - 1];
            last.parentNode.insertBefore(block, last.nextSibling);
            for (var m = 0; m < nodes.length; m++) {
                nodes[m].dataset.haxefmod = "1";
                // The site's selector never hides a block without a
                // language class, so the Haxe swap for those is managed
                // here through this marker.
                if (unit.langs.length === 0) nodes[m].classList.add("haxefmod-plain");
            }
        }
        updateStrips(current());
        return units.length > 0;
    }

    function setDisplay(selectorList, display) {
        var nodes = document.querySelectorAll(selectorList);
        for (var i = 0; i < nodes.length; i++) nodes[i].style.display = display;
    }

    function apply(selected) {
        var haxeOn = selected === LANG;
        setDisplay("." + LANG, haxeOn ? "block" : "none");
        var tabs = document.querySelectorAll(".language-tab");
        for (var i = 0; i < tabs.length; i++) {
            var lang = tabs[i].getAttribute("data-language");
            if (lang === LANG) tabs[i].classList.toggle("selected", haxeOn);
            else if (haxeOn) tabs[i].classList.remove("selected");
        }
        if (haxeOn) {
            setDisplay(NATIVE_LANGS.map(function (l) { return "." + l; }).join(", "), "none");
        }
        setDisplay(".haxefmod-plain", haxeOn ? "none" : "");
        updateStrips(selected);
    }

    function applyNative(lang) {
        var tabs = document.querySelectorAll(".language-tab");
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].classList.toggle("selected", tabs[i].getAttribute("data-language") === lang);
        }
        NATIVE_LANGS.forEach(function (other) {
            setDisplay("." + other, other === lang ? "block" : "none");
        });
        updateStrips(lang);
        try { window.localStorage.setItem(STORAGE_KEY, lang); } catch (e) { /* ignore */ }
    }

    function haxeChosen() {
        try { return window.localStorage.getItem(OWN_KEY) === "1"; } catch (e) { return false; }
    }

    function choose(haxe) {
        try {
            if (haxe) {
                window.localStorage.setItem(OWN_KEY, "1");
                window.localStorage.setItem(STORAGE_KEY, LANG);
            } else {
                window.localStorage.removeItem(OWN_KEY);
            }
        } catch (e) { /* storage unavailable, selection lasts for the page only */ }
    }

    // Swapping a language block changes the height below the tab strip,
    // and the browser's scroll anchoring then shifts the page so some
    // other element stays put. The tab that was clicked is what the eye
    // is on, so its viewport position is taken before any handler runs
    // (capture phase) and restored once the site and this script have
    // both applied the change.
    document.addEventListener("click", function (event) {
        var tab = event.target.closest ? event.target.closest(".language-tab") : null;
        if (!tab) return;
        var before = tab.getBoundingClientRect().top;
        window.requestAnimationFrame(function () {
            var after = tab.getBoundingClientRect().top;
            if (after !== before) window.scrollBy(0, after - before);
        });
    }, true);

    document.addEventListener("click", function (event) {
        var tab = event.target.closest ? event.target.closest(".language-tab") : null;
        if (!tab) return;
        var lang = tab.getAttribute("data-language");
        if (lang === LANG) {
            choose(true);
            apply(LANG);
        } else if (lang === "language-all") {
            // The Code tab over blocks the site never toggles: leave
            // the page's language as it was, just put the block back.
            choose(false);
            var restored = current();
            apply(restored);
            applyNative(restored);
        } else {
            choose(false);
            apply(lang);
            // The site only wired the tabs it rendered. Tabs on the
            // selectors added for lone examples do the same work here.
            if (tab.parentNode.classList.contains("haxefmod-selector")) applyNative(lang);
        }
    });

    var pending = false;
    function schedule() {
        if (pending) return;
        pending = true;
        window.requestAnimationFrame(function () {
            pending = false;
            if (injectAll() && haxeChosen()) {
                choose(true);
                apply(LANG);
                // The site's selector initializes after render and may
                // run later than this pass. Reapply once it has settled.
                window.setTimeout(function () { apply(LANG); }, 50);
            }
        });
    }

    new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
    schedule();
})();
