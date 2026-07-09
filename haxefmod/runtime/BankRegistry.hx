package haxefmod.runtime;

import haxefmod.studio.Bank;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * Refcounted bank loading. Multiple systems (states, components) can ask
 * for the same bank; it is only unloaded when the last reference is
 * released. Async loads go through FMOD's NONBLOCKING flag (native) or a
 * fetch into the virtual filesystem (html5) - poll loadingState or check
 * isReady.
 */
class BankRegistry {
    var banks:Map<String, {bank:Bank, refs:Int}> = new Map();

    public function new() {}

    /**
     * Loads a bank (or bumps its refcount). Path is used as given - resolve
     * against your bank folder first (FmodRuntime does this for you).
     * Returns Bank.NULL on failure.
     */
    public function load(path:String):Bank {
        return doLoad(path, false);
    }

    /**
     * Starts an async load (or bumps the refcount of an existing entry).
     * The returned handle is usable once loadingState(path) == LOADED.
     */
    public function loadAsync(path:String):Bank {
        return doLoad(path, true);
    }

    function doLoad(path:String, async:Bool):Bank {
        var entry = banks.get(path);
        if (entry != null && entry.bank.isValid()) {
            entry.refs++;
            return entry.bank;
        }
        var bank:Bank = async
            ? NativeStudio.sys_load_bank_async(path)
            : StudioSystem.loadBankFile(path);
        if (bank.isNull()) {
            // Already loaded outside the registry is fine - adopt it
            if (StudioSystem.lastResult() == FmodResult.FMOD_ERR_EVENT_ALREADY_LOADED) {
                var existing = StudioSystem.getBank(bankPathFor(path));
                if (!existing.isNull()) {
                    banks.set(path, {bank: existing, refs: 1});
                    return existing;
                }
            }
            return Bank.NULL;
        }
        banks.set(path, {bank: bank, refs: 1});
        return bank;
    }

    /**
     * Releases one reference; unloads the bank when the count hits zero.
     * Returns true when the bank was actually unloaded.
     */
    public function unload(path:String):Bool {
        var entry = banks.get(path);
        if (entry == null) return false;
        entry.refs--;
        if (entry.refs > 0) return false;
        banks.remove(path);
        entry.bank.unload();
        return true;
    }

    public function isLoaded(path:String):Bool {
        var entry = banks.get(path);
        return entry != null && entry.bank.isValid()
            && entry.bank.getLoadingState() == FmodLoadingState.LOADED;
    }

    /** Loading state for a registered bank (UNLOADED if never registered). */
    public function loadingState(path:String):FmodLoadingState {
        var entry = banks.get(path);
        if (entry == null) return UNLOADED;
        return entry.bank.getLoadingState();
    }

    public function refCount(path:String):Int {
        var entry = banks.get(path);
        return entry == null ? 0 : entry.refs;
    }

    /** The registered bank handle for a path (Bank.NULL if not registered). */
    public function get(path:String):Bank {
        var entry = banks.get(path);
        return entry == null ? Bank.NULL : entry.bank;
    }

    /** True while any registered bank is still loading (async). */
    public function anyLoading():Bool {
        for (entry in banks) {
            if (entry.bank.getLoadingState() == FmodLoadingState.LOADING) return true;
        }
        return false;
    }

    static inline function bankPathFor(filePath:String):String {
        // FMOD bank paths look like "bank:/Master"; derive from the file name
        var file = filePath.split("/").pop();
        var name = file.split(".")[0];
        return 'bank:/$name';
    }
}
