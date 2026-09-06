# Tools CLI

`haxelib run haxefmod <command>` runs the library's command-line tools from your project directory.

| Command | Purpose |
|---|---|
| `check` | Verifies the FMOD SDK path and version, the compiler, and the HashLink headers. |
| `generate` | Writes the `FmodEvents`, `FmodBuses`, `FmodVCAs`, `FmodSnapshots`, and `FmodParameters` constants classes from `Master.strings.bank`. |
| `todos` | Lists every `FmodManager.Todo` marker in the project. |
| `stage` | Copies the FMOD runtime files into a build output directory, for builds lime does not manage. |
| `build-hdll` | Compiles the HashLink native library against your installed FMOD SDK. |
| `verify-native` | Confirms the native shims match the binding manifest. The library's own CI uses it. |
| `help` | Prints the command list. |

`postbuild` also exists. Lime calls it after each build to copy the FMOD runtime files next to the output. There is no reason to run it by hand.

## check

```bash
haxelib run haxefmod check
```

Run it after you install the SDK and whenever a build fails unexpectedly. It reports what is missing and how to fix it. The report includes the download link for the expected FMOD version and the compiler installation steps for your platform. It also counts the sound TODO markers in the project.

## generate

[Generated constants](constants.md) covers what the generator writes and how to run it from FMOD Studio.

```bash
haxelib run haxefmod generate [--strings <path>] [--out <dir>] [--package <pkg>]
```

- `--strings` is the path to `Master.strings.bank`. Default `assets/fmod/Desktop/Master.strings.bank`.
- `--out` is the output directory. Default `source/` if it exists, otherwise the current directory.
- `--package` is the package for the generated classes. Default top-level.

The generator parses the compiled strings bank, so it reflects exactly what the banks contain. Run it again after every bank build.

## todos

```bash
haxelib run haxefmod todos [--json]
```

Finds every `FmodManager.Todo(...)` call in the project, so the sound work they mark can be scheduled. The scanner is comment-aware and string-aware. It skips commented-out calls and mentions inside string literals. Calls with a literal first argument show their description. The scanner still finds a computed description and reports it as dynamic. `--json` prints machine-readable output for build dashboards.

## stage

```bash
haxelib run haxefmod stage <platform> <target> <outdir>
```

Lime builds get the FMOD runtime files copied next to the game automatically. Every other build runs `stage` after compiling to do the same: Heaps, Kha, and plain haxe builds. The platform is `mac`, `linux`, `windows`, or `html5`. The target is `hl` or `cpp`.

- `hl` copies the FMOD libraries and `hlaxe_fmod.hdll`, resolved through the same tiers as a lime build (see [Platforms](../platforms.md#hashlink)). It also writes a launcher that starts the game with the right library path. The launcher is `run.sh` on Linux and macOS and `run.cmd` on Windows.
- `cpp` copies the FMOD libraries only, for executables the binding was compiled into. Kha's native targets use this on Kore HL/C builds too.
- `html5` copies the FMOD web engine (`fmodstudio.js`, `fmodstudio.wasm`) and the library's `jaxe.js` glue into the directory. Your page then loads them with script tags ahead of the game.

The command reads `FMOD_SDK` (or `FMOD_SDK_WEB` for html5). It stops with the reason when the variable is unset, points at the wrong package, or holds an unusable version. The Heaps and Kha tabs of [Getting started](../getting-started.md#6-build-and-run) show it inside a full build.

## build-hdll

```bash
haxelib run haxefmod build-hdll
```

The library ships pre-built HashLink libraries for FMOD Engine 2.03.12. Any other engine version needs the hdll compiled against your installed SDK, and this command does it. It detects the platform and finds the HashLink headers in the usual locations. It compiles and places the result in a `.haxefmod/` directory in your project. The build then prefers that copy over the bundled one. Set `HASHLINK_DIR` to your HashLink installation if the command cannot find the headers. You must have a C compiler (`gcc` on Linux, `cc` on macOS, `cl` on Windows). See [Platforms](../platforms.md#hashlink) for how the hdll is resolved at build time.
