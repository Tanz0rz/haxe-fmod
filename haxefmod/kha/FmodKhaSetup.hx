package haxefmod.kha;

import haxefmod.FmodManager;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import kha.System;

/**
    One-call FMOD setup for Kha games. Call init() once from the
    System.start callback. init() does the following.

    It initializes FMOD. Settings pass through to FmodManager.Initialize.
    The first initialization wins. Settings are ignored if something
    already initialized FMOD.

    It installs FmodKhaUpdater so FmodManager.Update() runs every frame.

    It mutes the FMOD master output while the application is paused or
    in the background, through System.notifyOnApplicationState.

    Kha has no global volume control of its own, so the FMOD master bus
    is the volume. Use FmodManager.SetMasterVolume and SetMasterMute.

    Calling init() again is safe and keeps a single focus wiring.

    preload() does the same and takes the default banks from the Kha
    assets, then calls back once FMOD is ready. The first scene can then
    play events at once, on HTML5 too.
**/
class FmodKhaSetup {
    /**
        Initializes FMOD with the default banks taken from kha.Assets.blobs,
        and calls onReady once everything is usable. Add the bank folder to
        the khafile assets and call this from the kha.Assets.loadEverything
        callback. A bank named Master.bank is the blob Master_bank, the way
        khamake names assets. On a native target a bank missing from the
        blobs is read from the bank folder on disk instead, the folder the
        stage command fills. onFailed runs instead when a bank is not
        available either way or fails to load. FMOD is initialized with
        the settings either way, the game runs without that bank, and the
        console names it.
        @param settings The FmodSettings for Initialize. banksProvided is set on the object.
        @param onReady Called once FMOD and the default banks are usable.
        @param onFailed Called when a default bank is missing or fails to load. Without it, onReady runs anyway.
    **/
    public static function preload(?settings:FmodSettings, onReady:Void->Void, ?onFailed:Void->Void):Void {
        if (settings == null) settings = {};
        settings.banksProvided = true;
        var resolved = haxefmod.runtime.FmodSettingsResolver.resolve(settings);
        for (fileName in resolved.autoLoadBanks) {
            var blob:kha.Blob = kha.Assets.blobs.get(blobName(fileName));
            if (blob != null) {
                FmodRuntime.provideBank(fileName, blob.bytes);
                continue;
            }
            #if sys
            // The stage command put the bank folder next to the executable.
            // The working directory is tried first, then the executable's
            // own directory, since a launcher can start the game elsewhere.
            var path = FmodRuntime.bankPath(fileName, resolved.bankFolder);
            var bytes = readBankFile(path);
            if (bytes != null) {
                FmodRuntime.provideBank(fileName, bytes);
                continue;
            }
            FmodRuntime.provideBankFailed(fileName, 'it is not among the Kha assets (blob ${blobName(fileName)})'
                + ' and $path is not next to the executable or in the working directory');
            continue;
            #end
            FmodRuntime.provideBankFailed(fileName, 'it is not among the Kha assets (blob ${blobName(fileName)}).'
                + ' Add the bank folder to the khafile assets');
        }
        // Native init loads the default banks inside init, from the bytes
        // provided above. HTML5 loads them once the module is ready.
        init(settings);
        // Passed through as is: with no onFailed, onReady runs once FMOD
        // is ready, with or without every bank
        FmodRuntime.onceReady(onReady, onFailed);
    }

    #if sys
    static function readBankFile(path:String):Null<haxe.io.Bytes> {
        var candidates = [path];
        if (!haxe.io.Path.isAbsolute(path)) {
            var exeDir = haxe.io.Path.directory(Sys.programPath());
            candidates.push(haxe.io.Path.join([exeDir, path]));
            // A macOS bundle keeps its files under Contents/Resources
            candidates.push(haxe.io.Path.join([exeDir, "..", "Resources", path]));
        }
        for (candidate in candidates) {
            if (sys.FileSystem.exists(candidate)) {
                try return sys.io.File.getBytes(candidate) catch (e:Dynamic) {}
            }
        }
        return null;
    }
    #end

    /** The Kha asset name of a bank file: khamake turns dots, dashes, spaces, and slashes into underscores. **/
    public static function blobName(fileName:String):String {
        var slash = fileName.lastIndexOf("/");
        var name = slash >= 0 ? fileName.substr(slash + 1) : fileName;
        name = ~/[-@ .\/\\]/g.replace(name, "_");
        return ~/^[0-9]/.match(name) ? "_" + name : name;
    }

    /** Initializes FMOD and wires the Kha updater and application state hooks. **/
    public static function init(?settings:FmodSettings):Void {
        FmodManager.Initialize(settings);
        FmodKhaUpdater.init();
        // Remove-then-add keeps a single wiring across repeated init calls
        System.removeApplicationStateListeners(onForeground, onForeground, onBackground, onBackground, null);
        System.notifyOnApplicationState(onForeground, onForeground, onBackground, onBackground, null);
    }

    static function onForeground():Void {
        FmodRuntime.setWindowFocused(true);
    }

    static function onBackground():Void {
        FmodRuntime.setWindowFocused(false);
    }
}
