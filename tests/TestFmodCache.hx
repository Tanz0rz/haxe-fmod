package tests;

import haxefmod.FmodCache;

class TestFmodCache {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- FmodCache ---");

		testGetHandleReturnsInvalidForUnknown();
		testGetEventPathReturnsNullForUnknown();
		testRegisterAndRetrieve();
		testHasEventInstance();
		testUnregister();
		testRegisterOverwritesExisting();
		testGetEventInstanceCount();
		testClear();
		testBankRegistration();
		testBankUnregistration();
		testGetAllInstanceNames();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function setUp():FmodCache {
		var cache = FmodCache.getInstance();
		cache.clear();
		return cache;
	}

	static function testGetHandleReturnsInvalidForUnknown() {
		var cache = setUp();
		assert("getHandle unknown returns INVALID_HANDLE", cache.getHandle("nonexistent") == FmodCache.INVALID_HANDLE);
	}

	static function testGetEventPathReturnsNullForUnknown() {
		var cache = setUp();
		assert("getEventPath unknown returns null", cache.getEventPath("nonexistent") == null);
	}

	static function testRegisterAndRetrieve() {
		var cache = setUp();
		cache.registerEventInstance("mySound", "event:/SFX/Jump", 42);
		assert("getHandle returns registered handle", cache.getHandle("mySound") == 42);
		assert("getEventPath returns registered path", cache.getEventPath("mySound") == "event:/SFX/Jump");
	}

	static function testHasEventInstance() {
		var cache = setUp();
		assert("hasEventInstance false before register", !cache.hasEventInstance("mySound"));
		cache.registerEventInstance("mySound", "event:/SFX/Jump", 1);
		assert("hasEventInstance true after register", cache.hasEventInstance("mySound"));
	}

	static function testUnregister() {
		var cache = setUp();
		cache.registerEventInstance("mySound", "event:/SFX/Jump", 1);
		cache.unregisterEventInstance("mySound");
		assert("hasEventInstance false after unregister", !cache.hasEventInstance("mySound"));
		assert("getHandle returns INVALID_HANDLE after unregister", cache.getHandle("mySound") == FmodCache.INVALID_HANDLE);
		assert("getEventPath returns null after unregister", cache.getEventPath("mySound") == null);
	}

	static function testRegisterOverwritesExisting() {
		var cache = setUp();
		cache.registerEventInstance("mySound", "event:/SFX/Jump", 1);
		cache.registerEventInstance("mySound", "event:/SFX/Land", 99);
		assert("getHandle returns new handle after overwrite", cache.getHandle("mySound") == 99);
		assert("getEventPath returns new path after overwrite", cache.getEventPath("mySound") == "event:/SFX/Land");
		assert("count still 1 after overwrite", cache.getEventInstanceCount() == 1);
	}

	static function testGetEventInstanceCount() {
		var cache = setUp();
		assert("count 0 initially", cache.getEventInstanceCount() == 0);
		cache.registerEventInstance("a", "event:/A", 1);
		assert("count 1 after one register", cache.getEventInstanceCount() == 1);
		cache.registerEventInstance("b", "event:/B", 2);
		assert("count 2 after two registers", cache.getEventInstanceCount() == 2);
		cache.unregisterEventInstance("a");
		assert("count 1 after unregister", cache.getEventInstanceCount() == 1);
	}

	static function testClear() {
		var cache = setUp();
		cache.registerEventInstance("a", "event:/A", 1);
		cache.registerEventInstance("b", "event:/B", 2);
		cache.registerBank("Master.bank");
		cache.clear();
		assert("count 0 after clear", cache.getEventInstanceCount() == 0);
		assert("hasEventInstance false after clear", !cache.hasEventInstance("a"));
		assert("bank not loaded after clear", !cache.isBankLoaded("Master.bank"));
	}

	static function testBankRegistration() {
		var cache = setUp();
		assert("bank not loaded initially", !cache.isBankLoaded("Master.bank"));
		cache.registerBank("Master.bank");
		assert("bank loaded after register", cache.isBankLoaded("Master.bank"));
		assert("other bank still not loaded", !cache.isBankLoaded("Other.bank"));
	}

	static function testBankUnregistration() {
		var cache = setUp();
		cache.registerBank("Master.bank");
		cache.unregisterBank("Master.bank");
		assert("bank not loaded after unregister", !cache.isBankLoaded("Master.bank"));
	}

	static function testGetAllInstanceNames() {
		var cache = setUp();
		cache.registerEventInstance("x", "event:/X", 1);
		cache.registerEventInstance("y", "event:/Y", 2);
		var names = new Map<String, Bool>();
		for (name in cache.getAllInstanceNames()) {
			names.set(name, true);
		}
		assert("getAllInstanceNames contains x", names.exists("x"));
		assert("getAllInstanceNames contains y", names.exists("y"));
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
