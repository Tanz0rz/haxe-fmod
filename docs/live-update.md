# Live Update

FMOD Studio Live Update connects Studio to the running game, so you can mix in real time while you play. It works on C++ and HashLink builds. It opens TCP port 9264, and the FMOD API does not allow another port. It is on by default in `-debug` builds. The `liveUpdate` setting or the `haxefmod_live_update` and `haxefmod_no_live_update` defines force it on or off.

```haxe
FmodManager.Initialize({liveUpdate: true});
```

The game listens on a local socket. macOS and Windows therefore show a firewall dialog the first time a Live Update build runs.
