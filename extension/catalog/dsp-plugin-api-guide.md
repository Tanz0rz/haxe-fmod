# dsp-plugin-api-guide

## 18.2.1 Building a Plug-in
kind: example
index: 0
heading: 18.2.1 Building a Plug-in

### C
```c
extern "C" {
F_EXPORT FMOD_DSP_DESCRIPTION* F_CALL FMODGetDSPDescription();
}
```

## 18.2.1 Building a Plug-in#2
kind: example
index: 1
heading: 18.2.1 Building a Plug-in

### C
```c
extern "C" {
F_EXPORT FMOD_DSP_DESCRIPTION* F_CALL FMOD_YourCompany_YourProduct_GetDSPDescription();
}
```

## 18.2.2 Loading the Plug-in in the Game
kind: example
index: 2
heading: 18.2.2 Loading the Plug-in in the Game

### text
```text
FMOD_RESULT FMOD::Studio::System::registerPlugin(const FMOD_DSP_DESCRIPTION* description);
FMOD_RESULT FMOD::System::registerDSP(const FMOD_DSP_DESCRIPTION *description, unsigned int *handle);
```

## 18.2.2 Loading the Plug-in in the Game#2
kind: example
index: 3
heading: 18.2.2 Loading the Plug-in in the Game

### text
```text
FMOD_RESULT FMOD::System::loadPlugin(const char *filename, unsigned int *handle, unsigned int priority = 0)
```

## 18.2.2 Loading the Plug-in in the Game#3
kind: example
index: 4
heading: 18.2.2 Loading the Plug-in in the Game

### text
```text
FMOD_RESULT FMOD::System::setPluginPath(const char *path)
```

## 18.2.2 Loading the Plug-in in the Game#4
kind: example
index: 5
heading: 18.2.2 Loading the Plug-in in the Game

### text
```text
FMOD_RESULT FMOD::Studio::System::unregisterPlugin(const char* name)
FMOD_RESULT FMOD::System::unloadPlugin(unsigned int handle)
```

## 18.4 The Plug-in Descriptor
kind: example
index: 6
heading: 18.4 The Plug-in Descriptor

### text
```text
FMOD_DSP_DESCRIPTION FMOD_Gain_Desc =
{
    FMOD_PLUGIN_SDK_VERSION,
    "FMOD Gain",    // name
    0x00010000,     // plug-in version
    1,              // number of input buffers to process
    1,              // number of output buffers to process
    ...
};
```

## 18.7 Multiple Plug-ins Within One File
kind: example
index: 7
heading: 18.7 Multiple Plug-ins Within One File

### text
```text
FMOD_DSP_DESCRIPTION My_Gain_Desc = { .. };
FMOD_DSP_DESCRIPTION My_Panner_Desc = { .. };
FMOD_OUTPUT_DESCRIPTION My_Output_Desc = { .. };

static FMOD_PLUGINLIST My_Plugin_List[] =
{
    { FMOD_PLUGINTYPE_DSP, &My_Gain_Desc },
    { FMOD_PLUGINTYPE_DSP, &My_Panner_Desc },
    { FMOD_PLUGINTYPE_OUTPUT, &My_Output_Desc },
    { FMOD_PLUGINTYPE_MAX, NULL }
};

extern "C"
{

F_EXPORT FMOD_PLUGINLIST* F_CALL FMODGetPluginDescriptionList()
{
    return &My_Plugin_List;
}

} // end extern "C"
```

## 18.7 Multiple Plug-ins Within One File#2
kind: example
index: 8
heading: 18.7 Multiple Plug-ins Within One File

### text
```text
unsigned int baseHandle;
ERRCHECK(system->loadPlugin("plugin_name.dll", &baseHandle));
int count;
ERRCHECK(system->getNumNestedPlugins(baseHandle, &count));
for (int index=0; index<count; ++index)
{
    unsigned int handle;
    ERRCHECK(system->getNestedPlugin(baseHandle, index, &handle));        
    FMOD_PLUGINTYPE type;
    ERRCHECK(system->getPluginInfo(handle, &type, 0, 0, 0));
    // We have an output plug-in, a DSP plug-in, or a codec plug-in here.
}
```

