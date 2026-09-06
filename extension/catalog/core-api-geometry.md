# core-api-geometry

## geometry_addpolygon
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Geometry::addPolygon(
  float directocclusion,
  float reverbocclusion,
  bool doublesided,
  int numvertices,
  const FMOD_VECTOR *vertices,
  int *polygonindex
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_AddPolygon(
  FMOD_GEOMETRY *geometry,
  float directocclusion,
  float reverbocclusion,
  FMOD_BOOL doublesided,
  int numvertices,
  const FMOD_VECTOR *vertices,
  int *polygonindex
);
```

### C#
```csharp
RESULT Geometry.addPolygon(
  float directocclusion,
  float reverbocclusion,
  bool doublesided,
  int numvertices,
  VECTOR[] vertices,
  out int polygonindex
);
```

## geometry_getactive
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Geometry::getActive(
  bool *active
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetActive(
  FMOD_GEOMETRY *geometry,
  FMOD_BOOL *active
);
```

### C#
```csharp
RESULT Geometry.getActive(
  out bool active
);
```

### JavaScript
```javascript
Geometry.getActive(
  active
);
```

## geometry_getmaxpolygons
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Geometry::getMaxPolygons(
  int *maxpolygons,
  int *maxvertices
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetMaxPolygons(
  FMOD_GEOMETRY *geometry,
  int *maxpolygons,
  int *maxvertices
);
```

### C#
```csharp
RESULT Geometry.getMaxPolygons(
  out int maxpolygons,
  out int maxvertices
);
```

### JavaScript
```javascript
Geometry.getMaxPolygons(
  maxpolygons,
  maxvertices
);
```

## geometry_getnumpolygons
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Geometry::getNumPolygons(
  int *numpolygons
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetNumPolygons(
  FMOD_GEOMETRY *geometry,
  int *numpolygons
);
```

### C#
```csharp
RESULT Geometry.getNumPolygons(
  out int numpolygons
);
```

### JavaScript
```javascript
Geometry.getNumPolygons(
  numpolygons
);
```

## geometry_getpolygonattributes
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Geometry::getPolygonAttributes(
  int index,
  float *directocclusion,
  float *reverbocclusion,
  bool *doublesided
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetPolygonAttributes(
  FMOD_GEOMETRY *geometry,
  int index,
  float *directocclusion,
  float *reverbocclusion,
  FMOD_BOOL *doublesided
);
```

### C#
```csharp
RESULT Geometry.getPolygonAttributes(
  int index,
  out float directocclusion,
  out float reverbocclusion,
  out bool doublesided
);
```

### JavaScript
```javascript
Geometry.getPolygonAttributes(
  index,
  directocclusion,
  reverbocclusion,
  doublesided
);
```

## geometry_getpolygonnumvertices
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Geometry::getPolygonNumVertices(
  int index,
  int *numvertices
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetPolygonNumVertices(
  FMOD_GEOMETRY *geometry,
  int index,
  int *numvertices
);
```

### C#
```csharp
RESULT Geometry.getPolygonNumVertices(
  int index,
  out int numvertices
);
```

### JavaScript
```javascript
Geometry.getPolygonNumVertices(
  index,
  numvertices
);
```

## geometry_getpolygonvertex
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Geometry::getPolygonVertex(
  int index,
  int vertexindex,
  FMOD_VECTOR *vertex
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetPolygonVertex(
  FMOD_GEOMETRY *geometry,
  int index,
  int vertexindex,
  FMOD_VECTOR *vertex
);
```

### C#
```csharp
RESULT Geometry.getPolygonVertex(
  int index,
  int vertexindex,
  out VECTOR vertex
);
```

### JavaScript
```javascript
Geometry.getPolygonVertex(
  index,
  vertexindex,
  vertex
);
```

## geometry_getposition
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Geometry::getPosition(
  FMOD_VECTOR *position
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetPosition(
  FMOD_GEOMETRY *geometry,
  FMOD_VECTOR *position
);
```

### C#
```csharp
RESULT Geometry.getPosition(
  out VECTOR position
);
```

### JavaScript
```javascript
Geometry.getPosition(
  position
);
```

## geometry_getrotation
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Geometry::getRotation(
  FMOD_VECTOR *forward,
  FMOD_VECTOR *up
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetRotation(
  FMOD_GEOMETRY *geometry,
  FMOD_VECTOR *forward,
  FMOD_VECTOR *up
);
```

### C#
```csharp
RESULT Geometry.getRotation(
  out VECTOR forward,
  out VECTOR up
);
```

### JavaScript
```javascript
Geometry.getRotation(
  forward,
  up
);
```

## geometry_getscale
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Geometry::getScale(
  FMOD_VECTOR *scale
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetScale(
  FMOD_GEOMETRY *geometry,
  FMOD_VECTOR *scale
);
```

### C#
```csharp
RESULT Geometry.getScale(
  out VECTOR scale
);
```

### JavaScript
```javascript
Geometry.getScale(
  scale
);
```

## geometry_getuserdata
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Geometry::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_GetUserData(
  FMOD_GEOMETRY *geometry,
  void **userdata
);
```

### C#
```csharp
RESULT Geometry.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Geometry.getUserData(
  userdata
);
```

## geometry_release
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Geometry::release();
```

### C
```c
FMOD_RESULT FMOD_Geometry_Release(FMOD_GEOMETRY *geometry);
```

### C#
```csharp
RESULT Geometry.release();
```

### JavaScript
```javascript
Geometry.release();
```

## geometry_save
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Geometry::save(
  void *data,
  int *datasize
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_Save(
  FMOD_GEOMETRY *geometry,
  void *data,
  int *datasize
);
```

### C#
```csharp
RESULT Geometry.save(
  IntPtr data,
  out int datasize
);
```

## geometry_setactive
kind: function
index: 13

### C++
```cpp
FMOD_RESULT Geometry::setActive(
  bool active
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetActive(
  FMOD_GEOMETRY *geometry,
  FMOD_BOOL active
);
```

### C#
```csharp
RESULT Geometry.setActive(
  bool active
);
```

### JavaScript
```javascript
Geometry.setActive(
  active
);
```

## geometry_setpolygonattributes
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Geometry::setPolygonAttributes(
  int index,
  float directocclusion,
  float reverbocclusion,
  bool doublesided
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetPolygonAttributes(
  FMOD_GEOMETRY *geometry,
  int index,
  float directocclusion,
  float reverbocclusion,
  FMOD_BOOL doublesided
);
```

### C#
```csharp
RESULT Geometry.setPolygonAttributes(
  int index,
  float directocclusion,
  float reverbocclusion,
  bool doublesided
);
```

### JavaScript
```javascript
Geometry.setPolygonAttributes(
  index,
  directocclusion,
  reverbocclusion,
  doublesided
);
```

## geometry_setpolygonvertex
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Geometry::setPolygonVertex(
  int index,
  int vertexindex,
  const FMOD_VECTOR *vertex
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetPolygonVertex(
  FMOD_GEOMETRY *geometry,
  int index,
  int vertexindex,
  const FMOD_VECTOR *vertex
);
```

### C#
```csharp
RESULT Geometry.setPolygonVertex(
  int index,
  int vertexindex,
  ref VECTOR vertex
);
```

### JavaScript
```javascript
Geometry.setPolygonVertex(
  index,
  vertexindex,
  vertex
);
```

## geometry_setposition
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Geometry::setPosition(
  const FMOD_VECTOR *position
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetPosition(
  FMOD_GEOMETRY *geometry,
  const FMOD_VECTOR *position
);
```

### C#
```csharp
RESULT Geometry.setPosition(
  ref VECTOR position
);
```

### JavaScript
```javascript
Geometry.setPosition(
  position
);
```

## geometry_setrotation
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Geometry::setRotation(
  const FMOD_VECTOR *forward,
  const FMOD_VECTOR *up
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetRotation(
  FMOD_GEOMETRY *geometry,
  const FMOD_VECTOR *forward,
  const FMOD_VECTOR *up
);
```

### C#
```csharp
RESULT Geometry.setRotation(
  ref VECTOR forward,
  ref VECTOR up
);
```

### JavaScript
```javascript
Geometry.setRotation(
  forward,
  up
);
```

## geometry_setscale
kind: function
index: 18

### C++
```cpp
FMOD_RESULT Geometry::setScale(
  const FMOD_VECTOR *scale
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetScale(
  FMOD_GEOMETRY *geometry,
  const FMOD_VECTOR *scale
);
```

### C#
```csharp
RESULT Geometry.setScale(
  ref VECTOR scale
);
```

### JavaScript
```javascript
Geometry.setScale(
  scale
);
```

## geometry_setuserdata
kind: function
index: 19

### C++
```cpp
FMOD_RESULT Geometry::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Geometry_SetUserData(
  FMOD_GEOMETRY *geometry,
  void *userdata
);
```

### C#
```csharp
RESULT Geometry.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Geometry.setUserData(
  userdata
);
```

