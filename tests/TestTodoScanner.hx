package tests;

import haxefmod.tools.Todos;

/**
 * Tests the FmodManager.Todo scanner behind `haxelib run haxefmod todos`.
 * Everything runs against in-memory source strings through
 * Todos.scanContent, so no filesystem fixtures are needed.
 */
class TestTodoScanner {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Todo Scanner ---");

		testFindsDoubleQuoted();
		testFindsSingleQuoted();
		testReportsCorrectLine();
		testMultiplePerFile();
		testMultilineCall();
		testDynamicDescription();
		testEscapedQuotes();
		testIgnoresLineComment();
		testIgnoresBlockComment();
		testIgnoresStringMention();
		testIgnoresLongerIdentifier();
		testIgnoresFieldAccessPrefix();
		testEmptyFile();
		testCallAfterString();
		testFindsFullyQualified();
		testRegexLiteralWithQuote();
		testRootResolution();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function scan(src:String):Array<TodoEntry> {
		return Todos.scanContent("Test.hx", src);
	}

	static function testFindsDoubleQuoted() {
		var found = scan('FmodManager.Todo("door creak");');
		assert("finds double-quoted call", found.length == 1 && found[0].description == "door creak");
	}

	static function testFindsSingleQuoted() {
		var found = scan("FmodManager.Todo('sword clang');");
		assert("finds single-quoted call", found.length == 1 && found[0].description == "sword clang");
	}

	static function testReportsCorrectLine() {
		var found = scan('var a = 1;\nvar b = 2;\nFmodManager.Todo("on line three");\n');
		assert("reports the call line", found.length == 1 && found[0].line == 3);
	}

	static function testMultiplePerFile() {
		var found = scan('FmodManager.Todo("first");\nFmodManager.Todo("second");\n');
		assert("finds every call in a file", found.length == 2 && found[1].description == "second" && found[1].line == 2);
	}

	static function testMultilineCall() {
		var found = scan('FmodManager.Todo(\n    "wrapped description"\n);\nFmodManager.Todo("after");');
		assert("handles a call split across lines", found.length == 2 && found[0].description == "wrapped description" && found[0].line == 1 && found[1].line == 4);
	}

	static function testDynamicDescription() {
		var found = scan("FmodManager.Todo(someVariable);");
		assert("computed argument reported as dynamic", found.length == 1 && found[0].description == "(dynamic description)");
	}

	static function testEscapedQuotes() {
		var found = scan('FmodManager.Todo("boss \\"roar\\" sound");');
		assert("unescapes quotes in the description", found.length == 1 && found[0].description == 'boss "roar" sound');
	}

	static function testIgnoresLineComment() {
		var found = scan('// FmodManager.Todo("commented out");\nFmodManager.Todo("real");');
		assert("skips line-commented calls", found.length == 1 && found[0].description == "real");
	}

	static function testIgnoresBlockComment() {
		var found = scan('/* FmodManager.Todo("commented out");\n   more comment */\nFmodManager.Todo("real");');
		assert("skips block-commented calls", found.length == 1 && found[0].description == "real" && found[0].line == 3);
	}

	static function testIgnoresStringMention() {
		var found = scan('var doc = "call FmodManager.Todo(desc) to mark spots";\nFmodManager.Todo("real");');
		assert("skips mentions inside string literals", found.length == 1 && found[0].description == "real" && found[0].line == 2);
	}

	static function testIgnoresLongerIdentifier() {
		var found = scan('MyFmodManager.Todo("not ours");');
		assert("skips calls on other classes", found.length == 0);
	}

	static function testIgnoresFieldAccessPrefix() {
		var found = scan('wrapper.FmodManager.Todo("qualified through a field");');
		assert("skips field-qualified lookalikes", found.length == 0);
	}

	static function testEmptyFile() {
		assert("empty file yields nothing", scan("").length == 0);
	}

	static function testCallAfterString() {
		var found = scan('var s = "text"; FmodManager.Todo("after a string");');
		assert("finds a call after a string on the same line", found.length == 1 && found[0].description == "after a string");
	}

	static function testFindsFullyQualified() {
		var found = scan('haxefmod.FmodManager.Todo("fully qualified");');
		assert("finds the package-qualified call", found.length == 1
			&& found[0].description == "fully qualified");
		var nested = scan('foo.haxefmod.FmodManager.Todo("not the real package");');
		assert("skips a re-qualified lookalike package", nested.length == 0);
	}

	static function testRegexLiteralWithQuote() {
		var found = scan('var r = ~/"/; FmodManager.Todo("after a regex");');
		assert("a quote inside a regex literal does not hide calls",
			found.length == 1 && found[0].description == "after a regex");
		var cls = scan("var r = ~/[\"']+/g; FmodManager.Todo('after a class regex');");
		assert("quotes in a regex class do not hide calls",
			cls.length == 1 && cls[0].description == "after a class regex");
	}

	static function testRootResolution() {
		// A relative directory argument is the caller's, not the process
		// cwd (haxelib run leaves the process inside the library root)
		var cwd = Sys.getCwd();
		var resolved = Todos.resolveRoot(["tests"], cwd);
		assert("relative arg resolves against the caller cwd",
			StringTools.replace(resolved, "\\", "/") == StringTools.replace(haxe.io.Path.join([cwd, "tests"]), "\\", "/"));
		assert("absolute arg kept", Todos.resolveRoot([cwd], "/somewhere/else") == cwd);
		assert("missing arg falls back to the caller cwd",
			Todos.resolveRoot(["no-such-dir-here"], cwd) == cwd);
		assert("no arg falls back to the caller cwd", Todos.resolveRoot([], cwd) == cwd);
		assert("json flag is not a directory", Todos.resolveRoot(["--json"], cwd) == cwd);
	}

	static function assert(name:String, condition:Bool) {
		if (condition) {
			passed++;
		} else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}
}
