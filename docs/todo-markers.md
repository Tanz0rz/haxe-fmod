# Sound TODO markers

`FmodManager.Todo("description")` marks a spot in game code that still needs a sound. Release builds compile the call away. Debug builds trace each call site once. A build with `-D haxefmod_todo_beep` also plays a short placeholder blip, so missing sounds are audible during playtesting.

```haxe
FmodManager.Todo("door creak when the cellar opens");
```

`haxelib run haxefmod todos` lists every remaining marker in the project. See [Tools CLI](guides/tools-cli.md#todos).
