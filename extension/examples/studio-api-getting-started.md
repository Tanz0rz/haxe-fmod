# studio-api-getting-started

## 0
<!-- 12.1.1 Studio API Initialization -->
FmodManager.Initialize creates the Studio system, initializes the core system underneath it, and loads the master banks. Every other call initializes with defaults on first use, so calling it is optional. Call FmodManager.Update once per frame to deliver callbacks. There is no release call. FMOD lives until the process exits.
```haxe
FmodManager.Initialize({liveUpdate: true, numChannels: 1024});

// each frame
FmodManager.Update();
```
