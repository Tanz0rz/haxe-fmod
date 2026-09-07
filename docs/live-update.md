# Live Update

FMOD Studio Live Update connects Studio to the running game, so you can mix in real time while you play. [FMOD's guide](https://fmod.com/docs/2.03/studio/editing-during-live-update.html) covers the Studio side of the connection.

## Where it works

| Target | Live Update |
|---|---|
| C++ | Yes |
| HashLink | Yes |
| HTML5 | No. FMOD does not support it in browsers. |

## Turning it on

Live Update is on by default in `-debug` builds and off everywhere else. Three switches change that.

| Switch | Effect |
|---|---|
| `liveUpdate` in the [settings](guides/banks-and-settings.md#settings) | Forces it on or off for that build. It wins over the defines. |
| `-D haxefmod_live_update` | Forces it on in every build. |
| `-D haxefmod_no_live_update` | Forces it off in every build. |

```haxe
FmodManager.Initialize({liveUpdate: true});
```

## Port and firewall

Live Update opens TCP port 9264. The FMOD API does not allow another port.

The game listens on a local socket. macOS and Windows therefore show a firewall dialog the first time a Live Update build runs. Allow the connection once and the dialog does not return.
