// Kinc project file for Kha builds. khamake picks this up when a khafile
// does project.addLibrary('haxefmod') and compiles the native binding into
// the game executable, since Kha's native targets never run hxcpp's own
// build (Kore-hxcpp) or load hdlls (Kore-HL).
//
// Reads FMOD_SDK for the headers and libraries. The Kore-HL target is
// selected with HAXEFMOD_KHA_HL=1 in the environment (the kfile has no
// other way to know which backend khamake chose). The link step finds
// libfmod and libfmodstudio through LIBRARY_PATH on Linux, and the
// runtime finds them next to the executable through the stage command's
// run.sh. See example-project/KhaPlatformer/build.sh.

const fs = require('fs');
const path = require('path');

let project = new Project('haxefmod');

const sdk = process.env.FMOD_SDK;
if (!sdk) {
	throw 'haxefmod: FMOD_SDK is not set. Download the FMOD Engine from https://www.fmod.com/download and point FMOD_SDK at it.';
}

project.addIncludeDir(path.join(sdk, 'api', 'core', 'inc'));
project.addIncludeDir(path.join(sdk, 'api', 'studio', 'inc'));
project.addIncludeDir('native/shared');

if (process.env.HAXEFMOD_KHA_HL === '1') {
	// HL/C: the HashLink runtime is compiled into the binary by Kore-HL,
	// so the binding goes in as plain C next to it
	project.addFile('native/hlaxe/hlaxe_fmod.c');
} else {
	project.addIncludeDir('native/faxe');
	project.addFile('native/faxe/linc_faxe.cpp');
}

if (platform === Platform.Windows) {
	project.addLib(path.join(sdk, 'api', 'core', 'lib', 'x64', 'fmod_vc'));
	project.addLib(path.join(sdk, 'api', 'studio', 'lib', 'x64', 'fmodstudio_vc'));
} else {
	project.addLib('fmod');
	project.addLib('fmodstudio');
}

resolve(project);
