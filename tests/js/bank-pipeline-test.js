// Drives jaxe.js's REAL preRun/onRuntimeInitialized (the other harnesses
// replace them) against the real wasm, with fetch redirected to local
// files. The shim must not own bank loading: settings-driven banks load
// through the runtime's registry via the async pipeline, so right after
// init the system holds zero banks, and the same fetch path then loads
// the master banks on request.
// Usage: FMOD_SDK_WEB=<sdk root> node bank-pipeline-test.js
const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..');
if (!process.env.FMOD_SDK_WEB) {
    console.error('FMOD_SDK_WEB is not set (expected the FMOD html5 SDK root)');
    process.exit(1);
}
const SDK = path.join(process.env.FMOD_SDK_WEB, 'api', 'studio', 'lib', 'wasm');
const JAXE = path.join(REPO, 'native', 'jaxe', 'jaxe.js');
const BANKS = path.join(REPO, 'example-project', 'EZPlatformer', 'assets', 'fmod', 'Desktop');

global.window = { location: { pathname: '/g/i.html' }, setInterval, clearInterval };
global.document = { addEventListener: function () {} };
global.FMODModule = require(path.join(SDK, 'fmodstudio.js'));
// Serve bank fetches from the local example project, like a web server would
global.fetch = function (url) {
    const name = String(url).split('/').pop();
    const file = path.join(BANKS, name);
    if (!fs.existsSync(file)) {
        return Promise.resolve({ ok: false, status: 404 });
    }
    const bytes = fs.readFileSync(file);
    return Promise.resolve({ ok: true, arrayBuffer: () => Promise.resolve(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)) });
};
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

let fails = 0;
function check(label, cond, detail) {
    console.log(`BANK_PIPELINE_TEST: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
    // Node has no audio device: route output to NOSOUND before the real
    // bootstrap initializes, leaving every other bootstrap step unchanged
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

    // The shim's own bootstrap, exactly as a browser runs it
    jaxe.fmod_sys_init_ex(128, 0, 0, 0);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await sleep(50);
    check('init_completes', jaxe.FmodIsInitialized, '');

    // Bank ownership belongs to the runtime's registry: the shim itself
    // loads nothing at startup
    check('no_banks_preloaded', jaxe.fmod_sys_get_bank_count() === 0,
        `count=${jaxe.fmod_sys_get_bank_count()}`);

    // The registry's async pipeline then loads the settings-driven banks
    // through the same shim call the runtime uses
    const master = jaxe.fmod_sys_load_bank_async('assets/fmod/Desktop/Master.bank');
    const strings = jaxe.fmod_sys_load_bank_async('assets/fmod/Desktop/Master.strings.bank');
    check('async_handles', master > 0 && strings > 0, `m=${master} s=${strings}`);
    for (let i = 0; i < 200; i++) {
        const m = jaxe.fmod_bank_get_loading_state(master);
        const s = jaxe.fmod_bank_get_loading_state(strings);
        if (m !== 2 && s !== 2) break;
        await sleep(20);
    }
    check('master_loaded', jaxe.fmod_bank_get_loading_state(master) === 3,
        `state=${jaxe.fmod_bank_get_loading_state(master)}`);
    check('strings_loaded', jaxe.fmod_bank_get_loading_state(strings) === 3,
        `state=${jaxe.fmod_bank_get_loading_state(strings)}`);
    check('bank_count_after_loads', jaxe.fmod_sys_get_bank_count() === 2,
        `count=${jaxe.fmod_sys_get_bank_count()}`);

    // Events resolve once the banks are in, proving the pipeline is whole
    const evd = jaxe.fmod_sys_get_event('event:/Music/MainLevel');
    check('event_resolves_after_async_load', evd > 0, `handle=${evd}`);

    // A failed fetch surfaces as ERROR instead of hanging init forever
    // (the old preRun preload turned a 404 into an unresolvable hang)
    const missing = jaxe.fmod_sys_load_bank_async('assets/fmod/Desktop/Nope.bank');
    for (let i = 0; i < 200 && jaxe.fmod_bank_get_loading_state(missing) === 2; i++) await sleep(20);
    check('missing_bank_settles_error', jaxe.fmod_bank_get_loading_state(missing) === 4,
        `state=${jaxe.fmod_bank_get_loading_state(missing)}`);
    jaxe.fmod_bank_unload(missing);

    console.log(`BANK_PIPELINE_TEST: failures = ${fails}`);
    console.log(fails === 0 ? 'BANK_PIPELINE_TEST: COMPLETE' : 'BANK_PIPELINE_TEST: FAILED');
    process.exit(fails === 0 ? 0 : 1);
}

main().catch(e => { console.log('HARNESS ERROR', e); process.exit(1); });
