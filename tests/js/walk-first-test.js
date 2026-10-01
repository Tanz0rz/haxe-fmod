// Two handle rules that only a fresh process can show, on the real web
// glue. A walk that reaches the master group before any master lookup
// gets the fixed master handle. An instance's group at an address a
// released instance's group held gets a fresh handle.
// The lifecycle harness looks the master up early, so it cannot see the
// first rule.
//
// Usage: FMOD_SDK_WEB=<sdk root> node walk-first-test.js
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
eval(fs.readFileSync(JAXE, 'utf8') + '\nglobal.jaxe = jaxe;');

jaxe.preRun = function () {
    for (const n of ['Master.bank', 'Master.strings.bank']) {
        jaxe.FMOD.FS_createDataFile('/', n, fs.readFileSync(path.join(BANKS, n)), true, false, false);
    }
};
jaxe.onRuntimeInitialized = function () {
    var o = {};
    jaxe.FMOD.Studio_System_Create(o); jaxe.gSystem = o.val;
    jaxe.gSystem.getCoreSystem(o); jaxe.gSystemCore = o.val;
    jaxe.gSystemCore.setOutput(jaxe.FMOD.OUTPUTTYPE_NOSOUND_NRT);
    // A fixed mixer block makes NRT time-per-update deterministic, so the
    // beat wait below cannot depend on the SDK's default block size
    jaxe.gSystemCore.setDSPBufferSize(2048, 2);
    jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
    var b = {};
    jaxe.gSystem.loadBankFile('/Master.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.gSystem.loadBankFile('/Master.strings.bank', jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, b);
    jaxe.FmodIsInitialized = true;
    return jaxe.FMOD.OK;
};

let fails = 0;
function check(label, cond, detail) {
    console.log(`WALK: ${label} ${cond ? 'pass' : 'FAIL'} ${detail || ''}`);
    if (!cond) fails++;
}
// A path the run could not reach. It reads as neither a pass nor a failure.
function skip(label, detail) {
    console.log(`WALK: ${label} skip ${detail || ''}`);
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function pump(n) { for (let i = 0; i < n; i++) { jaxe.fmod_sys_update(); await sleep(15); } }
function drainEvents() { while (jaxe.fmod_cb_next()) {} }
async function main() {
    jaxe.FMOD['preRun'] = jaxe.preRun;
    jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
    FMODModule(jaxe.FMOD);
    for (let i = 0; i < 300 && !jaxe.FmodIsInitialized; i++) await sleep(50);
    await pump(2);
    // A: the first walk to the master group, before any master lookup
    const own = jaxe.fmod_cg_create('first-walk');
    const up = jaxe.fmod_cg_get_parent_group(own);
    check('walk_to_master_first_mint_fixed', up > 0 && jaxe.slots[up & 0xFFFF].borrowed === jaxe.BORROWED_NONE, `up=${up} borrowed=${up > 0 ? jaxe.slots[up & 0xFFFF].borrowed : -1}`);
    jaxe.fmod_cg_release(own);
    check('walked_master_survives_destroy', jaxe.handleIsLive(up) && up === jaxe.fmod_cg_get_master(), `live=${jaxe.handleIsLive(up)}`);
    // B: an instance group address reused before the drain
    const evd = jaxe.fmod_sys_get_event('event:/SFX/Coin');
    let reusedSeen = 0, staleAnswered = 0;
    for (let k = 0; k < 10; k++) {
        const a = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(a); jaxe.gSystem.flushCommands();
        const ga = jaxe.fmod_evi_get_channel_group(a);
        const rawA = jaxe.rawPtr(jaxe.resolveCg(ga));
        jaxe.handleResolve(a, jaxe.TYPE_EVI).stop(jaxe.FMOD.STUDIO_STOP_IMMEDIATE);
        jaxe.handleResolve(a, jaxe.TYPE_EVI).release();
        jaxe.gSystem.flushCommands();
        const b = jaxe.fmod_evd_create_instance(evd);
        jaxe.fmod_evi_start(b); jaxe.gSystem.flushCommands();
        const gb = jaxe.fmod_evi_get_channel_group(b);
        const rawB = gb ? jaxe.rawPtr(jaxe.resolveCg(gb)) : 0;
        if (rawB === rawA) { reusedSeen++; if (gb === ga) staleAnswered++; }
        jaxe.fmod_evi_stop(b, 1); jaxe.fmod_evi_release(b);
        jaxe.gSystem.flushCommands(); await pump(2); drainEvents();
    }
    // No reuse in ten rounds proves nothing, so that run fails too
    check('anchored_reuse_gets_fresh_handle', reusedSeen > 0 && staleAnswered === 0, `reused=${reusedSeen} staleAnswered=${staleAnswered}`);
    console.log('WALK: failures = ' + fails);
    process.exit(fails ? 1 : 0);
}
main().catch(e => { console.log('ERR', e); process.exit(1); });
