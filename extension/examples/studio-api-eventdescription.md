# studio-api-eventdescription

## 32
<!-- FMOD_STUDIO_USER_PROPERTY -->
FmodUserProperty has a name, a type, a floatValue that carries integer, boolean, and float properties, and a stringValue for string properties. EventDescription.getUserProperty(index) and getUserPropertyByName(name) return it, or null when the property does not exist.
```haxe
var description = StudioSystem.getEvent("event:/SFX/Coin");
var property = description.getUserPropertyByName("Priority");
if (property != null) {
    trace('${property.name} = ${property.floatValue}');
}
```

## 33
<!-- FMOD_STUDIO_USER_PROPERTY_TYPE -->
FmodUserPropertyType carries the same values. Numeric properties are native only (unsupported in HTML5), where FMOD's runtime crashes on them, so the call returns FMOD_ERR_UNSUPPORTED there.
```haxe
import haxefmod.studio.Types;

var description = StudioSystem.getEvent("event:/SFX/Coin");
for (i in 0...description.getUserPropertyCount()) {
    var property = description.getUserProperty(i);
    if (property == null) continue;
    switch (property.type) {
        case INTEGER: trace('${property.name}: ${Std.int(property.floatValue)}');
        case BOOLEAN: trace('${property.name}: ${property.floatValue != 0}');
        case FLOAT: trace('${property.name}: ${property.floatValue}');
        case STRING: trace('${property.name}: ${property.stringValue}');
    }
}
```
