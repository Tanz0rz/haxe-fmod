# dsp-plugin-api-guide

## 18.2.1 Building a Plug-in
verdict: cannot The exported description function is part of a plug-in library written in C, and its callbacks run on FMOD's mixer thread where no Haxe target can run code. The built library loads with StudioSystem.loadPlugin.

## 18.2.1 Building a Plug-in#2
verdict: cannot The exported description function is part of a plug-in library written in C, and its callbacks run on FMOD's mixer thread where no Haxe target can run code. The built library loads with StudioSystem.loadPlugin.

## 18.2.2 Loading the Plug-in in the Game
verdict: cannot Registering from a description struct cannot be bound, because the struct carries callbacks that FMOD runs on its mixer thread and no Haxe target can run code there. A plug-in built into a shared library loads with StudioSystem.loadPlugin, which makes its effects available to Studio events and to Dsp.createByPlugin.

## 18.2.2 Loading the Plug-in in the Game#2
verdict: bound
Native only (unsupported in HTML5).
Returns FMOD's plugin handle, or 0 on failure with the reason in StudioSystem.lastResult().
```haxe
var priority = 0;
var handle = StudioSystem.loadPlugin("fmod_gain.dll", priority);
if (handle == 0) {
    trace('loadPlugin failed: ${StudioSystem.lastResult()}');
}
```

## 18.2.2 Loading the Plug-in in the Game#3
verdict: bound
Native only (unsupported in HTML5).
```haxe
var result = StudioSystem.setPluginPath("plugins");
if (!result.isOk()) {
    trace('setPluginPath failed: $result');
}
```

## 18.2.2 Loading the Plug-in in the Game#4
verdict: bound
Native only (unsupported in HTML5).
unregisterPlugin has no Haxe form because registerPlugin has none, unloadPlugin is the one that applies.
Release every Dsp created from the plug-in first. FMOD frees them from its mixer thread, so an unload that answers FMOD_ERR_DSP_INUSE succeeds when retried a few frames later.
```haxe
var handle = StudioSystem.loadPlugin("fmod_gain.dll");
var result = StudioSystem.unloadPlugin(handle);
if (!result.isOk()) {
    trace('unloadPlugin failed: $result');
}
```

## 18.4 The Plug-in Descriptor
verdict: cannot The descriptor is a C struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can run code there. A compiled plug-in loads with StudioSystem.loadPlugin and Dsp.getPluginInfo reads the name, version, and buffer counts it registered.

## 18.7 Multiple Plug-ins Within One File
verdict: cannot The plug-in list and the descriptors it points to are C code inside the plug-in library. A library that exports a list loads as one handle with StudioSystem.loadPlugin, and getNestedPluginCount and getNestedPlugin reach the plug-ins inside it.

## 18.7 Multiple Plug-ins Within One File#2
verdict: bound
Native only (unsupported in HTML5).
loadPlugin returns 0 on failure and getNestedPluginCount returns -1, with the reason in StudioSystem.lastResult(). getPluginInfo returns the type together with the name and version.
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
