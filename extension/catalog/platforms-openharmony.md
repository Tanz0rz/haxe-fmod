# platforms-openharmony

## JavaScript
kind: example
index: 0
heading: JavaScript

### text
```text
export const init: (ability: UIAbility) => void;
export const close: () => void;
```

## JavaScript#2
kind: example
index: 1
heading: JavaScript

### text
```text
{
  "name": "libfmod.so",
  "types": "./index.d.ts",
  "version": "",
  "description": "FMOD Core Library."
}
```

## JavaScript#3
kind: example
index: 2
heading: JavaScript

### text
```text
"devDependencies": {
  "@types/libfmod.so": "file:./src/main/cpp/types/libfmod"
},
```

## JavaScript#4
kind: example
index: 3
heading: JavaScript

### JavaScript
```javascript
import fmod from 'libfmod.so';
```

## JavaScript#5
kind: example
index: 4
heading: JavaScript

### JavaScript
```javascript
fmod.init(this);
```

## JavaScript#6
kind: example
index: 5
heading: JavaScript

### JavaScript
```javascript
fmod.close();
```

## JavaScript#7
kind: example
index: 6
heading: JavaScript

### JavaScript
```javascript
windowStage.on('windowStageEvent', (data) => {
  if (data == window.WindowStageEventType.ACTIVE) {
    // Call you JS entry point for FMOD creation here
  }
  else if (data == window.WindowStageEventType.INACTIVE) {
    // Call you JS entry point for FMOD destruction here
  }
});
```

