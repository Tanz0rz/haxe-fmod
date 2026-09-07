# Parameters

`setParameter(name, value, ?ignoreSeekSpeed)`, `setParameterWithLabel(name, label, ?ignoreSeekSpeed)`, `getParameter(name)`, and `getParameterFinal(name)` are short names for FMOD's `...ByName` calls. They exist on `EventInstance` for event parameters and on `StudioSystem` for global parameters.

```haxe
instance.setParameter("RPM", 0.7);
instance.setParameterWithLabel("Surface", "Gravel");
StudioSystem.setParameter("TimeOfDay", 0.25);
```

Parameter names are bare names, for example `"RPM"`. The generated `FmodParameters` constants hold full `parameter:/` paths for the global parameters. The description lookups accept those paths as well.
