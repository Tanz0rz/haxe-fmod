# core-api-reverb3d

## reverb3d_get3dattributes
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Reverb3D::get3DAttributes(
  FMOD_VECTOR *position,
  float *mindistance,
  float *maxdistance
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_Get3DAttributes(
  FMOD_REVERB3D *reverb3d,
  FMOD_VECTOR *position,
  float *mindistance,
  float *maxdistance
);
```

### C#
```csharp
RESULT Reverb3D.get3DAttributes(
  ref VECTOR position,
  ref float mindistance,
  ref float maxdistance
);
```

### JavaScript
```javascript
Reverb3D.get3DAttributes(
  position,
  mindistance,
  maxdistance
);
```

## reverb3d_getactive
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Reverb3D::getActive(
  bool *active
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_GetActive(
  FMOD_REVERB3D *reverb3d,
  FMOD_BOOL *active
);
```

### C#
```csharp
RESULT Reverb3D.getActive(
  out bool active
);
```

### JavaScript
```javascript
Reverb3D.getActive(
  active
);
```

## reverb3d_getproperties
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Reverb3D::getProperties(
  FMOD_REVERB_PROPERTIES *properties
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_GetProperties(
  FMOD_REVERB3D *reverb3d,
  FMOD_REVERB_PROPERTIES *properties
);
```

### C#
```csharp
RESULT Reverb3D.getProperties(
  ref REVERB_PROPERTIES properties
);
```

### JavaScript
```javascript
Reverb3D.getProperties(
  properties
);
```

## reverb3d_getuserdata
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Reverb3D::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_GetUserData(
  FMOD_REVERB3D *reverb3d,
  void **userdata
);
```

### C#
```csharp
RESULT Reverb3D.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Reverb3D.getUserData(
  userdata
);
```

## reverb3d_release
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Reverb3D::release();
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_Release(FMOD_REVERB3D *reverb3d);
```

### C#
```csharp
RESULT Reverb3D.release();
```

### JavaScript
```javascript
Reverb3D.release();
```

## reverb3d_set3dattributes
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Reverb3D::set3DAttributes(
  const FMOD_VECTOR *position,
  float mindistance,
  float maxdistance
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_Set3DAttributes(
  FMOD_REVERB3D *reverb3d,
  const FMOD_VECTOR *position,
  float mindistance,
  float maxdistance
);
```

### C#
```csharp
RESULT Reverb3D.set3DAttributes(
  ref VECTOR position,
  float mindistance,
  float maxdistance
);
```

### JavaScript
```javascript
Reverb3D.set3DAttributes(
  position,
  mindistance,
  maxdistance
);
```

## reverb3d_setactive
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Reverb3D::setActive(
  bool active
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_SetActive(
  FMOD_REVERB3D *reverb3d,
  FMOD_BOOL active
);
```

### C#
```csharp
RESULT Reverb3D.setActive(
  bool active
);
```

### JavaScript
```javascript
Reverb3D.setActive(
  active
);
```

## reverb3d_setproperties
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Reverb3D::setProperties(
  const FMOD_REVERB_PROPERTIES *properties
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_SetProperties(
  FMOD_REVERB3D *reverb3d,
  const FMOD_REVERB_PROPERTIES *properties
);
```

### C#
```csharp
RESULT Reverb3D.setProperties(
  ref REVERB_PROPERTIES properties
);
```

### JavaScript
```javascript
Reverb3D.setProperties(
  properties
);
```

## reverb3d_setuserdata
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Reverb3D::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Reverb3D_SetUserData(
  FMOD_REVERB3D *reverb3d,
  void *userdata
);
```

### C#
```csharp
RESULT Reverb3D.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Reverb3D.setUserData(
  userdata
);
```

