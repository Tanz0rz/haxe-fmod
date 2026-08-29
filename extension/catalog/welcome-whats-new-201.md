# welcome-whats-new-201

## Thread attributes
kind: example
index: 0
heading: Thread attributes

### C++
```cpp
FMOD::Thread_SetAttributes(FMOD_THREAD_TYPE_STREAM,      FMOD_THREAD_AFFINITY_GROUP_DEFAULT, FMOD_THREAD_PRIORITY_DEFAULT, stackSizeStream);
FMOD::Thread_SetAttributes(FMOD_THREAD_TYPE_NONBLOCKING, FMOD_THREAD_AFFINITY_GROUP_DEFAULT, FMOD_THREAD_PRIORITY_DEFAULT, stackSizeNonBlocking);
FMOD::Thread_SetAttributes(FMOD_THREAD_TYPE_MIXER,       FMOD_THREAD_AFFINITY_GROUP_DEFAULT, FMOD_THREAD_PRIORITY_DEFAULT, stackSizeMixer);
```

## Thread attributes#2
kind: example
index: 1
heading: Thread attributes

### C++
```cpp
FMOD::Thread_SetAttributes(FMOD_THREAD_TYPE_MIXER, FMOD_THREAD_AFFINITY_CORE_5);
FMOD::Thread_SetAttributes(FMOD_THREAD_TYPE_STREAM, FMOD_THREAD_AFFINITY_CORE_3);
```

