package;

/**
 * Selects which CI test state to run in audio_test builds.
 *
 * Native targets: HAXEFMOD_TEST_STATE env var ("volume", "api-probe").
 * HTML5: "test" query parameter (e.g. http://localhost:8080/?test=api-probe).
 * Defaults to "volume" (the original volume/mute validation flow).
 */
class TestConfig {
    public static function testState():String {
        #if sys
        var name = Sys.getEnv("HAXEFMOD_TEST_STATE");
        return name == null || name == "" ? "volume" : name;
        #elseif js
        var search = js.Browser.window.location.search;
        var matcher = ~/[?&]test=([\w-]+)/;
        return matcher.match(search) ? matcher.matched(1) : "volume";
        #else
        return "volume";
        #end
    }
}
