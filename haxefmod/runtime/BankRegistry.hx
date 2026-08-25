package haxefmod.runtime;

import haxefmod.studio.Bank;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * Refcounted bank loading. Multiple systems (states, components) can ask
 * for the same bank. It is only unloaded when the last reference is
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
        #if js
        // Files exist in the browser's virtual filesystem only after a
        // fetch wrote them, so html5 loads are always asynchronous
        return doLoad(normalizePath(path), true);
        #else
        return doLoad(normalizePath(path), false);
        #end
    }

    /**
     * Starts an async load (or bumps the refcount of an existing entry).
     * The returned handle is usable once loadingState(path) == LOADED.
     */
    public function loadAsync(path:String):Bank {
        return doLoad(normalizePath(path), true);
    }

    /**
     * Canonical map key for a bank path: forward slashes, no "." segments,
     * no duplicate separators. Two spellings of one file must share one
     * refcount, or unloading either to zero destroys the bank under the
     * other's holders.
     */
    public static function normalizePath(path:String):String {
        var parts = StringTools.replace(path, "\\", "/").split("/");
        var out = [];
        for (part in parts) {
            if (part == "" || part == ".") continue;
            out.push(part);
        }
        var joined = out.join("/");
        return StringTools.startsWith(path, "/") ? '/$joined' : joined;
    }

    function doLoad(path:String, async:Bool):Bank {
        var entry = banks.get(path);
        // An html5 async load holds a placeholder that reports LOADING but
        // not valid until the fetch lands, so the in-flight state counts as
        // registered too - a second load of the same path must share it
        // instead of starting a competing fetch
        if (entry != null && (entry.bank.isValid()
                || entry.bank.getLoadingState() == FmodLoadingState.LOADING)) {
            entry.refs++;
            return entry.bank;
        }
        // An entry can outlive its bank (unloadAll or an external unload).
        // The old refs' holders are still out there, so a replacement
        // carries their count forward instead of resetting to one. A dead
        // placeholder (an html5 fetch that settled in ERROR) still owns a
        // handle slot: release it before the replacement, or every retry
        // leaks one slot for the session.
        var carriedRefs = entry != null ? entry.refs + 1 : 1;
        if (entry != null && !entry.bank.isNull()) entry.bank.unload();
        var bank:Bank = async
            ? NativeStudio.sys_load_bank_async(path)
            : StudioSystem.loadBankFile(path);
        if (bank.isNull()) {
            // Already loaded outside the registry is fine - adopt it
            if (StudioSystem.lastResult() == FmodResult.FMOD_ERR_EVENT_ALREADY_LOADED) {
                var existing = StudioSystem.getBank(bankPathFor(path));
                if (!existing.isNull()) {
                    banks.set(path, {bank: existing, refs: carriedRefs});
                    return existing;
                }
            }
            return Bank.NULL;
        }
        banks.set(path, {bank: bank, refs: carriedRefs});
        return bank;
    }

    /**
     * Releases one reference. unloads the bank when the count hits zero.
     * Returns true when the bank was actually unloaded.
     */
    public function unload(path:String):Bool {
        path = normalizePath(path);
        var entry = banks.get(path);
        if (entry == null) return false;
        entry.refs--;
        if (entry.refs > 0) return false;
        banks.remove(path);
        entry.bank.unload();
        return true;
    }

    public function isLoaded(path:String):Bool {
        var entry = banks.get(normalizePath(path));
        return entry != null && entry.bank.isValid()
            && entry.bank.getLoadingState() == FmodLoadingState.LOADED;
    }

    /** Loading state for a registered bank (UNLOADED if never registered). */
    public function loadingState(path:String):FmodLoadingState {
        var entry = banks.get(normalizePath(path));
        if (entry == null) return UNLOADED;
        return entry.bank.getLoadingState();
    }

    public function refCount(path:String):Int {
        var entry = banks.get(normalizePath(path));
        return entry == null ? 0 : entry.refs;
    }

    /** The registered bank handle for a path (Bank.NULL if not registered). */
    public function get(path:String):Bank {
        var entry = banks.get(normalizePath(path));
        return entry == null ? Bank.NULL : entry.bank;
    }

    /** True while any registered bank is still loading (async). */
    public function anyLoading():Bool {
        for (entry in banks) {
            if (entry.bank.getLoadingState() == FmodLoadingState.LOADING) return true;
        }
        return false;
    }

    /** True when any registered bank settled in ERROR (a failed async load). */
    public function anyError():Bool {
        for (entry in banks) {
            if (entry.bank.getLoadingState() == FmodLoadingState.ERROR) return true;
        }
        return false;
    }

    static inline function bankPathFor(filePath:String):String {
        // FMOD bank paths look like "bank:/Master". Derive from the file
        // name, stripping only the trailing ".bank" extension so multi-dot
        // names like Master.strings.bank map to "bank:/Master.strings"
        var file = filePath.split("/").pop();
        var name = StringTools.endsWith(file, ".bank")
            ? file.substr(0, file.length - 5)
            : file;
        return 'bank:/$name';
    }
}
