import haxefmod.tools.PostBuild;
import haxefmod.tools.BuildHdll;

// Runs copyHdll on a project hdll with the given source marker (args: dir, marker)
class PostBuildHdllWarn {
	static function main() {
		var args = Sys.args();
		var dir = args[0];
		var abi = PostBuild.expectedAbiVersion(".");
		var marker = args[1] == "current" ? BuildHdll.sourceHash(".") : args[1];
		sys.FileSystem.createDirectory(dir + "/.haxefmod");
		sys.FileSystem.createDirectory(dir + "/out");
		sys.io.File.saveContent(dir + "/.haxefmod/hlaxe_fmod.hdll", 'junk hlaxe_fmod_abi=$abi\x00 hlaxe_fmod_src=$marker\x00');
		@:privateAccess PostBuild.copyHdll(dir, ".", "Linux64", dir + "/out");
	}
}
