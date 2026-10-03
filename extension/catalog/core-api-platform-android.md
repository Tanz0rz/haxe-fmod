# core-api-platform-android

## fmod_android_jni_close
kind: function
index: 0

### C/C++
```cpp
FMOD_RESULT FMOD_Android_JNI_Close();
```

### C#
```csharp
RESULT FMOD.Android.JNI_Close();
```

## fmod_android_jni_init
kind: function
index: 1

### C/C++
```cpp
FMOD_RESULT FMOD_Android_JNI_Init(
    JavaVM *vm,
    jobject javaActivity
);
```

### C#
```csharp
FMOD_RESULT FMOD.Android.JNI_Init(
    IntPtr vm,
    IntPtr javaActivity
);
```

## FMOD_Android_JNI_Init
kind: example
index: 2
heading: FMOD_Android_JNI_Init

### C++
```cpp
mApp->activity->vm->AttachCurrentThread(&mJniEnv, NULL);
FMOD_Android_JNI_Init(mApp->activity->vm, mApp->activity->clazz);
```

