package;

/**
 * Selects which CI test state to run in audio_test builds.
 *
 * Native targets: HAXEFMOD_TEST_STATE env var ("volume", "api-probe").
 * HTML5: "test" query parameter (e.g. http://localhost:8080/?test=api-probe).
 * testState() defaults to "volume" (the original volume/mute validation
 * flow). requestedState() returns null instead when nothing was asked
 * for, so a test build can fall back to the plain game and one build
 * serves every CI leg.
 */
class TestConfig {
    public static function testState():String {
        var name = requestedState();
        return name == null ? "volume" : name;
    }

    public static function requestedState():Null<String> {
        #if sys
        var name = Sys.getEnv("HAXEFMOD_TEST_STATE");
        return name == null || name == "" ? null : name;
        #elseif js
        var search = js.Browser.window.location.search;
        var matcher = ~/[?&]test=([\w-]+)/;
        return matcher.match(search) ? matcher.matched(1) : null;
        #else
        return null;
        #end
    }
}
