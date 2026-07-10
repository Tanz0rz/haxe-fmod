// Placeholder for the FMOD WebAssembly module. The build replaces this file
// with the real FMOD engine from $FMOD_SDK_WEB during postbuild; if you are
// reading this in a deployed game, that replacement never happened.
(function () {
    var message = "haxefmod: the FMOD engine placeholder was never replaced. "
        + "Set FMOD_SDK_WEB to your FMOD HTML5 SDK directory and rebuild "
        + "(verify with: haxelib run haxefmod check).";
    console.error(message);
    if (typeof document !== "undefined") {
        var banner = document.createElement("div");
        banner.style.cssText = "position:fixed;top:0;left:0;right:0;z-index:99999;"
            + "background:#b00020;color:#fff;font:14px monospace;padding:12px;";
        banner.textContent = message;
        var attach = function () { document.body.appendChild(banner); };
        if (document.body) attach();
        else document.addEventListener("DOMContentLoaded", attach);
    }
    // Halt the game load: FMODModule is what jaxe.js calls to boot the
    // engine, and throwing here stops a soundless game from shipping quietly
    window.FMODModule = function () {
        throw new Error(message);
    };
})();
