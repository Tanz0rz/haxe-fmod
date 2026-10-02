// Drives the actual Haxe runtime layer (FmodRuntime + BankRegistry,
// compiled to js) against the real wasm under Node.
// The subject is the html5 init contract.
// isInitialized() gates on the default banks being settled.
// A failed autoLoadBanks fetch is reported once, initFailed() turns true,
// and initialization completes without that bank.
// A provided bank that fails to load settles the same way.
// The other harnesses talk to jaxe.js directly and cannot see this layer.
//
// Usage: FMOD_SDK_WEB=<sdk root> node runtime-init-test.js
// Compiles tests/jsruntime/RuntimeInitTest.hx on the fly (needs haxe).
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFileSync, spawnSync } = require('child_process');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
const BANKS = path.join(REPO, 'example-project', 'EZPlatformer', 'assets', 'fmod', 'Desktop');

const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'haxefmod-runtime-init-'));
const bundle = path.join(outDir, 'runtime-init.js');
execFileSync('haxe', [
    '-cp', REPO,
    '-main', 'tests.jsruntime.RuntimeInitTest',
    '-js', bundle,
], { cwd: REPO, stdio: 'inherit' });

let fails = 0;
function runMode(mode) {
    const driver = `
        global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
        global.document = { addEventListener: function () {} };
        global.RUNTIME_TEST_MODE = ${JSON.stringify(mode)};
        const fs = require('fs');
        const path = require('path');
        // The bank a provided-mode run hands over as real bytes
        const strings = fs.readFileSync(path.join(${JSON.stringify(BANKS)}, 'Master.strings.bank'));
        global.RUNTIME_TEST_STRINGS_BANK = strings.buffer.slice(strings.byteOffset, strings.byteOffset + strings.byteLength);
        global.FMODModule = require(${JSON.stringify(path.join(SDK, 'fmodstudio.js'))});
        // Serve bank fetches from the local example project. Requests for
        // the 'missing/banks' folder 404 like a bad deploy would.
        global.fetch = function (url) {
            const raw = String(url);
            const name = raw.split('/').pop();
            const file = path.join(${JSON.stringify(BANKS)}, name);
            if (raw.indexOf('missing/') >= 0 || !fs.existsSync(file)) {
                return Promise.resolve({ ok: false, status: 404 });
            }
            if (global.RUNTIME_TEST_MODE === 'staggered') {
                if (name === 'Master.strings.bank') return Promise.resolve({ ok: false, status: 404 });
                const b = fs.readFileSync(file);
                return new Promise(res => setTimeout(() => res({ ok: true, arrayBuffer: () => Promise.resolve(
                    b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)) }), 1000));
            }
            const bytes = fs.readFileSync(file);
            return Promise.resolve({ ok: true, arrayBuffer: () => Promise.resolve(
                bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)) });
        };
        eval(fs.readFileSync(${JSON.stringify(JAXE)}, 'utf8') + '\\nglobal.jaxe = jaxe;');
        if (global.RUNTIME_TEST_MODE === 'refused') {
            const realAsync = jaxe.fmod_sys_load_bank_async;
            jaxe.fmod_sys_load_bank_async = function (p) {
                if (String(p).endsWith('/Master.bank')) { jaxe.lastResult = 38; return 0; }
                return realAsync(p);
            };
        }
        // Node has no audio device: route to NOSOUND inside the bootstrap
        const realBootstrap = jaxe.onRuntimeInitialized;
        jaxe.onRuntimeInitialized = function () {
            const realCreate = jaxe.FMOD.Studio_System_Create;
            jaxe.FMOD.Studio_System_Create = function (out) {
                const r = realCreate(out);
                const o = {};
                out.val.getCoreSystem(o);
                o.val.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
                return r;
            };
            const result = realBootstrap();
            jaxe.FMOD.Studio_System_Create = realCreate;
            return result;
        };
        require(${JSON.stringify(bundle)});
    `;
    const result = spawnSync(process.execPath, ['-e', driver], { encoding: 'utf8', timeout: 120000 });
    process.stdout.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    if (result.status !== 0) {
        console.log(`RUNTIME_INIT_TEST: mode ${mode} FAILED (exit ${result.status})`);
        fails++;
    } else {
        console.log(`RUNTIME_INIT_TEST: mode ${mode} ok`);
    }
}

runMode('ok');
runMode('missing');
runMode('provided');
runMode('refused');
runMode('staggered');
runMode('unloadinit');
console.log(fails === 0 ? 'RUNTIME_INIT_TEST: ALL MODES COMPLETE' : 'RUNTIME_INIT_TEST: FAILED');
process.exit(fails === 0 ? 0 : 1);
