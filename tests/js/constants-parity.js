// Parity test between the two constants generators: the FMOD Studio-side
// script (fmod-scripts/ExportHaxeConstants.js, runs inside Studio on every
// export) and the CLI (haxelib run haxefmod generate, parses the built
// strings bank). Both must emit byte-identical files or projects that mix
// the workflows drift.
//
// Usage: node tests/js/constants-parity.js <dir-with-cli-generated-files>
// The directory comes from running the CLI generator against the checked-in
// fixture bank (tests/fixtures/Master.strings.bank); the same entries are
// fed here to the Studio script's pure core and the outputs are diffed.
const path = require('path');
const fs = require('fs');

const REPO = path.join(__dirname, '..', '..');
const core = require(path.join(REPO, 'fmod-scripts', 'ExportHaxeConstants.js'));

const cliDir = process.argv[2];
if (!cliDir) {
    console.error('usage: node constants-parity.js <dir-with-cli-generated-files>');
    process.exit(2);
}

// The fixture bank's full entry set (runtime-verified against FMOD's own
// string table enumeration; also asserted by TestStringsBankParser)
const FIXTURE_ENTRIES = [
    { path: 'bus:/Reverb', guid: '{1a13f11e-eecf-4c3c-b353-79423771ced9}' },
    { path: 'parameter:/FadeArpIn', guid: '{293aa1ce-c07e-4cc2-bc41-7a082a62b7fa}' },
    { path: 'event:/SFX/Jump', guid: '{4562f533-1e6b-4ce9-a40a-814283edde66}' },
    { path: 'parameter:/HighPass', guid: '{4e75eb97-ff6c-459d-a75b-0576603fe118}' },
    { path: 'bank:/Master.strings', guid: '{66f6c0e2-d897-0a5b-0d20-44f9abca2481}' },
    { path: 'event:/SFX/Coin', guid: '{6c656399-97f5-432f-9817-c10c8c56939d}' },
    { path: 'bus:/', guid: '{7A6E2E04-9CA1-4DC4-9DF2-20F23D4A9D52}' },
    { path: 'event:/Music/MainLevel', guid: '{e5187c3f-0517-463e-b458-de9ef1a9f750}' },
    { path: 'bank:/Master', guid: '{feebe036-a9ec-4619-8b69-ce075a392219}' },
];

const studioFiles = core.generate(FIXTURE_ENTRIES);

let failures = 0;
function fail(message) {
    console.log('PARITY FAIL: ' + message);
    failures++;
}

// Every file the Studio script emits must exist from the CLI with identical
// bytes, and vice versa (bank:/ entries produce no file in either tool)
const cliFiles = fs.readdirSync(cliDir).filter(name => name.endsWith('.hx'));

for (const name of Object.keys(studioFiles)) {
    const cliPath = path.join(cliDir, name);
    if (!fs.existsSync(cliPath)) {
        fail(`Studio script emits ${name} but the CLI did not generate it`);
        continue;
    }
    const cliText = fs.readFileSync(cliPath, 'utf8');
    if (cliText !== studioFiles[name]) {
        fail(`${name} differs between the generators`);
        const a = cliText.split('\n');
        const b = studioFiles[name].split('\n');
        for (let i = 0; i < Math.max(a.length, b.length); i++) {
            if (a[i] !== b[i]) {
                console.log(`  line ${i + 1} CLI:    ${JSON.stringify(a[i])}`);
                console.log(`  line ${i + 1} Studio: ${JSON.stringify(b[i])}`);
                break;
            }
        }
    } else {
        console.log(`PARITY OK: ${name}`);
    }
}
for (const name of cliFiles) {
    if (!(name in studioFiles)) {
        fail(`CLI generated ${name} but the Studio script does not emit it`);
    }
}

if (Object.keys(studioFiles).length === 0) {
    fail('Studio script emitted no files');
}

console.log(failures ? `CONSTANTS PARITY FAILED: ${failures}` : 'CONSTANTS PARITY OK');
process.exit(failures ? 1 : 0);
