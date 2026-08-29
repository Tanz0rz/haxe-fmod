# managing-resources-in-the-core-api

## 9.5.1 Use a Fixed-size Memory Pool.
verdict: bound
```haxe
FmodManager.Initialize({memoryPoolSize: 4 * 1024 * 1024}); // allocate 4mb and pass it to the FMOD Engine to use.
```

