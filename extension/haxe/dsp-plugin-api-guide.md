# dsp-plugin-api-guide

## 18.2.1 Building a Plug-in
verdict: cannot The exported description function is part of a plug-in library written in C, and its callbacks run on FMOD's mixer thread where no Haxe target can run code. The built library loads with StudioSystem.loadPlugin.

## 18.2.1 Building a Plug-in#2
verdict: cannot The exported description function is part of a plug-in library written in C, and its callbacks run on FMOD's mixer thread where no Haxe target can run code. The built library loads with StudioSystem.loadPlugin.

## 18.2.2 Loading the Plug-in in the Game
verdict: cannot Registering from a description struct cannot be bound, because the struct carries callbacks that FMOD runs on its mixer thread and no Haxe target can run code there. A plug-in built into a shared library loads with StudioSystem.loadPlugin, which makes its effects available to Studio events and to Dsp.createByPlugin.

## 18.2.2 Loading the Plug-in in the Game#2
verdict: bound
```haxe
var handle = StudioSystem.loadPlugin(filename, 0);
```

## 18.2.2 Loading the Plug-in in the Game#3
verdict: bound
```haxe
var result = StudioSystem.setPluginPath(path);
```

## 18.2.2 Loading the Plug-in in the Game#4
verdict: bound
```haxe
// Studio::System::unregisterPlugin stays C side with plug-in registration (see 18.2.2).
var result = StudioSystem.unloadPlugin(handle);
```

## 18.4 The Plug-in Descriptor
verdict: cannot The descriptor is a C struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can run code there. A compiled plug-in loads with StudioSystem.loadPlugin and Dsp.getPluginInfo reads the name, version, and buffer counts it registered.

## 18.7 Multiple Plug-ins Within One File
verdict: cannot The plug-in list and the descriptors it points to are C code inside the plug-in library. A library that exports a list loads as one handle with StudioSystem.loadPlugin, and getNestedPluginCount and getNestedPlugin reach the plug-ins inside it.

## 18.7 Multiple Plug-ins Within One File#2
verdict: bound
```haxe
var baseHandle = StudioSystem.loadPlugin("plugin_name.dll");
if (baseHandle == 0) {
    trace('loadPlugin failed: ${StudioSystem.lastResult()}');
}
var count = StudioSystem.getNestedPluginCount(baseHandle);
for (index in 0...count) {
    var handle = StudioSystem.getNestedPlugin(baseHandle, index);
    var info = StudioSystem.getPluginInfo(handle);
    if (info != null) {
        var type = info.type;
        // We have an output plug-in, a DSP plug-in, or a codec plug-in here.
    }
}
```

