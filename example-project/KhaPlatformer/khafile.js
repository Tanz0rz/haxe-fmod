// Kha project for the haxefmod example. Same two levels and the same
// shared test scenarios as the flixel and Heaps examples.
//
// haxefmod comes in through haxelib (haxelib dev haxefmod <checkout> or a
// normal install), which also pulls its kfile.js in so the native binding
// is compiled into the executable. FMOD_SDK must be set for native targets
// and FMOD_SDK_WEB for html5 (the stage command reads them). See build.sh.
let project = new Project('KhaPlatformer');

project.addSources('src');
project.addSources('../shared');
project.addLibrary('haxefmod');
project.addParameter('-resource ../EZPlatformer/assets/level.csv@level');
project.addParameter('--macro haxefmod.tools.BuildCheck.verify()');

if (platform === 'html5') {
	// The api-probe calls methods FMOD's web build cannot serve on purpose
	// and checks the FMOD_ERR_UNSUPPORTED results at runtime
	project.addDefine('haxefmod_html5_allow_unsupported');
}
if (process.env.KHA_AUDIO_TEST === '1') {
	project.addDefine('audio_test');
}
if (process.env.KHA_MANUAL_UPDATE === '1') {
	project.addDefine('audio_test_manual_update');
	project.addDefine('haxefmod_num_channels=100');
}

project.windowOptions.width = 640;
project.windowOptions.height = 480;

resolve(project);
