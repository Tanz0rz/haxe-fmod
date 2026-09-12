# platforms-android

## Java
kind: example
index: 0
heading: Java

### java
```text
public class MainActivity extends Activity
{
    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        org.fmod.FMOD.init(this);
    }

    @Override
    protected void onDestroy()
    {
        org.fmod.FMOD.close();
    }
}

static
{
    System.loadLibrary("fmod");
}
```

## Java#2
kind: example
index: 1
heading: Java

### C++
```cpp
void android_main(struct android_app* app)
{
    jniEnv = NULL;
    app->activity->vm->AttachCurrentThread(&jniEnv, NULL);
    FMOD_Android_JNI_Init(app->activity->vm, app->activity->clazz);

    // ... game loop

    FMOD_Android_JNI_Close();
    app->activity->vm->DetachCurrentThread();
}
```

## Application Lifecycle Management
kind: example
index: 2
heading: Application Lifecycle Management

### java
```text
@Override
protected void onStart()
{
    super.onStart();
    setStateStart();
}

@Override
protected void onStop()
{
    setStateStop();
    super.onStop();
}

@Override
protected void onDestroy()
{
    setStateDestroy();
    super.onDestroy();
}

private native void setStateStart();
private native void setStateStop();
private native void setStateDestroy();
```

## Application Lifecycle Management#2
kind: example
index: 3
heading: Application Lifecycle Management

### java
```text
void Java_org_fmod_example_MainActivity_setStateStart(JNIEnv *env, jobject thiz)
{
    gSystem->mixerResume();
}

void Java_org_fmod_example_MainActivity_setStateStop(JNIEnv *env, jobject thiz)
{
    gSystem->mixerSuspend();
}

void Java_org_fmod_example_MainActivity_setStateDestroy(JNIEnv *env, jobject thiz)
{
    gSystem->mixerResume();
}
```

