package tests;

class RunTests {
	public static function main():Void {
		Sys.println("Running haxefmod unit tests...");
		Sys.println("");

		var totalFailed = 0;
		totalFailed += TestCallbackDispatcher.run();
		totalFailed += TestFacadePredicates.run();
		totalFailed += TestLayering.run();
		totalFailed += TestPlugins.run();
		totalFailed += TestPostBuild.run();
		totalFailed += TestRuntime.run();
		totalFailed += TestSongMachine.run();
		totalFailed += TestStringsBankParser.run();
		totalFailed += TestStudioSurface.run();
		totalFailed += TestTodoScanner.run();
		totalFailed += TestUserData.run();
		totalFailed += TestVersionParsing.run();

		Sys.println("");
		if (totalFailed > 0) {
			Sys.println('FAILED: $totalFailed assertion(s)');
			Sys.exit(1);
		} else {
			Sys.println("All tests passed.");
		}
	}
}
