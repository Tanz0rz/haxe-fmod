// Clicking the toolbar icon opens the FMOD API reference, where the Haxe
// tab lives. Chrome runs this as a service worker and Firefox as a
// background script. package.py rewrites the manifest's background entry
// for Firefox.
var api = typeof browser !== "undefined" ? browser : chrome;
api.action.onClicked.addListener(function () {
    api.tabs.create({ url: "https://www.fmod.com/docs/2.03/api/welcome.html" });
});
