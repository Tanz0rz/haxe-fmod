# studio-api-vca

## studio_vca_getid
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Studio::VCA::getID(
  FMOD_GUID *id
);
```

### C
```c
FMOD_RESULT FMOD_Studio_VCA_GetID(
  FMOD_STUDIO_VCA *vca,
  FMOD_GUID *id
);
```

### C#
```csharp
RESULT Studio.VCA.getID(
  out Guid id
);
```

### JavaScript
```javascript
Studio.VCA.getID(
  id
);
```

## studio_vca_getpath
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Studio::VCA::getPath(
  char *path,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_VCA_GetPath(
  FMOD_STUDIO_VCA *vca,
  char *path,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.VCA.getPath(
  out string path
);
```

### JavaScript
```javascript
Studio.VCA.getPath(
  path,
  size,
  retrieved
);
```

## studio_vca_getvolume
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Studio::VCA::getVolume(
  float *volume,
  float *finalvolume = 0
);
```

### C
```c
FMOD_RESULT FMOD_Studio_VCA_GetVolume(
  FMOD_STUDIO_VCA *vca,
  float *volume,
  float *finalvolume
);
```

### C#
```csharp
RESULT Studio.VCA.getVolume(
  out float volume
);
RESULT Studio.VCA.getVolume(
  out float volume,
  out float finalvolume
);
```

### JavaScript
```javascript
Studio.VCA.getVolume(
  volume,
  finalvolume
);
```

## studio_vca_isvalid
kind: function
index: 3

### C++
```cpp
bool Studio::VCA::isValid()
```

### C
```c
bool FMOD_Studio_VCA_IsValid(FMOD_STUDIO_VCA *vca)
```

### C#
```csharp
bool Studio.VCA.isValid()
```

### JavaScript
```javascript
Studio.VCA.isValid()
```

## studio_vca_setvolume
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Studio::VCA::setVolume(
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Studio_VCA_SetVolume(
  FMOD_STUDIO_VCA *vca,
  float volume
);
```

### C#
```csharp
RESULT Studio.VCA.setVolume(
  float volume
);
```

### JavaScript
```javascript
Studio.VCA.setVolume(
  volume
);
```

