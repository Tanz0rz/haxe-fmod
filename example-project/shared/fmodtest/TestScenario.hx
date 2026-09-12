package fmodtest;

/** One test state's logic, independent of the engine hosting it. */
interface TestScenario {
    function create(host:TestHost):Void;
    function update(elapsed:Float):Void;
}
