# managing-resources-in-the-core-api

## 9.5.1 Use a Fixed-size Memory Pool.
kind: example
index: 0
heading: 9.5.1 Use a Fixed-size Memory Pool.

### text
```text
result = FMOD::Memory_Initialize(malloc(4*1024*1024), 4*1024*1024, 0,0,0);  // allocate 4mb and pass it to the FMOD Engine to use.
ERRCHECK(result);
```

