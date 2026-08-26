// Drives the actual Haxe runtime layer (FmodRuntime + BankRegistry,
// compiled to js) against the real wasm under Node: the html5 init
// contract - isInitialized() gates on the default banks being usable,
// and a failed autoLoadBanks fetch holds it false with one traced
// warning. The other harnesses talk to jaxe.js directly and cannot see
// this layer.
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
            const bytes = fs.readFileSync(file);
            return Promise.resolve({ ok: true, arrayBuffer: () => Promise.resolve(
                bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)) });
        };
        eval(fs.readFileSync(${JSON.stringify(JAXE)}, 'utf8') + '\\nglobal.jaxe = jaxe;');
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
console.log(fails === 0 ? 'RUNTIME_INIT_TEST: ALL MODES COMPLETE' : 'RUNTIME_INIT_TEST: FAILED');
process.exit(fails === 0 ? 0 : 1);
