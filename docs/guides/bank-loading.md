# Bank loading

## The registry

`FmodRuntime.banks` is a `BankRegistry`, a refcounted loader keyed by normalized path. Several systems can ask for the same bank. The registry unloads it only when the last of them lets go. Bank file names without a directory resolve against `bankFolder` through `FmodRuntime.bankPath`.

```haxe
import haxefmod.runtime.FmodRuntime;

var path = FmodRuntime.bankPath("Vehicles.bank");
var bank = FmodRuntime.banks.load(path);
if (bank.isNull()) trace("Vehicles.bank failed to load");
// later, when the level ends
FmodRuntime.banks.unload(path);
```

`load` blocks on native. On HTML5 it always runs asynchronously. A file exists in the browser's virtual filesystem only after a fetch wrote it. `loadAsync` starts a background load on every target. It returns a handle that becomes usable once `loadingState(path)` reports `LOADED`. `loadMemory(path, bytes)` loads a bank from bytes the engine's loader delivered. It registers the bank under the path a file load would use. The other registry calls are `isRegistered`, `isLoaded`, `loadingState`, `refCount`, `get`, `anyLoading`, and `anyError`. `unload` returns true when it unloaded the bank. It returns false when it only decremented the count.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.banks.loadAsync(FmodRuntime.bankPath("Vehicles.bank"));
// in update, once per frame
if (FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Vehicles.bank"))) {
    FmodManager.PlayOneShot("event:/Vehicles/Horn");
}
```

A path that settles in `ERROR` is not deduplicated. A second load replaces the dead entry, so a game can retry a failed fetch.

Two spellings of one file share one refcount, because `BankRegistry.normalizePath` collapses separators and `.` segments. Windows backslashes are accepted. Two paths FMOD reports as one bank share an entry too, so the last unload of either unloads it.

## Loading outside the registry

`StudioSystem.loadBankFile`, `loadBankMemory`, `getBank`, and the `Bank` methods are FMOD's own calls and remain available. The registry adopts a bank loaded that way on the first registry load of the same path. `StudioSystem.unloadAll()` unloads everything, and the registry keeps its reference counts. A later registry load carries those counts forward.
