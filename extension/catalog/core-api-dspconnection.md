# core-api-dspconnection

## dspconnection_getinput
kind: function
index: 0

### C++
```cpp
FMOD_RESULT DSPConnection::getInput(
  DSP **input
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_GetInput(
  FMOD_DSPCONNECTION *dspconnection,
  FMOD_DSP **input
);
```

### C#
```csharp
RESULT DSPConnection.getInput(
  out DSP input
);
```

### JavaScript
```javascript
DSPConnection.getInput(
  input
);
```

## dspconnection_getmix
kind: function
index: 1

### C++
```cpp
FMOD_RESULT DSPConnection::getMix(
  float *volume
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_GetMix(
  FMOD_DSPCONNECTION *dspconnection,
  float *volume
);
```

### C#
```csharp
RESULT DSPConnection.getMix(
  out float volume
);
```

### JavaScript
```javascript
DSPConnection.getMix(
  volume
);
```

## dspconnection_getmixmatrix
kind: function
index: 2

### C++
```cpp
FMOD_RESULT DSPConnection::getMixMatrix(
  float *matrix,
  int *outchannels,
  int *inchannels,
  int inchannel_hop = 0
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_GetMixMatrix(
  FMOD_DSPCONNECTION *dspconnection,
  float *matrix,
  int *outchannels,
  int *inchannels,
  int inchannel_hop
);
```

### C#
```csharp
RESULT DSPConnection.getMixMatrix(
  float[] matrix,
  out int outchannels,
  out int inchannels,
  int inchannel_hop = 0
);
```

### JavaScript
```javascript
DSPConnection.getMixMatrix(
  matrix,
  outchannels,
  inchannels,
  inchannel_hop
);
```

## dspconnection_getoutput
kind: function
index: 3

### C++
```cpp
FMOD_RESULT DSPConnection::getOutput(
  DSP **output
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_GetOutput(
  FMOD_DSPCONNECTION *dspconnection,
  FMOD_DSP **output
);
```

### C#
```csharp
RESULT DSPConnection.getOutput(
  out DSP output
);
```

### JavaScript
```javascript
DSPConnection.getOutput(
  output
);
```

## dspconnection_gettype
kind: function
index: 4

### C++
```cpp
FMOD_RESULT DSPConnection::getType(
  FMOD_DSPCONNECTION_TYPE *type
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_GetType(
  FMOD_DSPCONNECTION *dspconnection,
  FMOD_DSPCONNECTION_TYPE *type
);
```

### C#
```csharp
RESULT DSPConnection.getType(
  out DSPCONNECTION_TYPE type
);
```

### JavaScript
```javascript
DSPConnection.getType(
  type
);
```

## dspconnection_getuserdata
kind: function
index: 5

### C++
```cpp
FMOD_RESULT DSPConnection::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_GetUserData(
  FMOD_DSPCONNECTION *dspconnection,
  void **userdata
);
```

### C#
```csharp
RESULT DSPConnection.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
DSPConnection.getUserData(
  userdata
);
```

## dspconnection_setmix
kind: function
index: 6

### C++
```cpp
FMOD_RESULT DSPConnection::setMix(
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_SetMix(
  FMOD_DSPCONNECTION *dspconnection,
  float volume
);
```

### C#
```csharp
RESULT DSPConnection.setMix(
  float volume
);
```

### JavaScript
```javascript
DSPConnection.setMix(
  volume
);
```

## dspconnection_setmixmatrix
kind: function
index: 7

### C++
```cpp
FMOD_RESULT DSPConnection::setMixMatrix(
  float *matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop = 0
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_SetMixMatrix(
  FMOD_DSPCONNECTION *dspconnection,
  float *matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop
);
```

### C#
```csharp
RESULT DSPConnection.setMixMatrix(
  float[] matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop = 0
);
```

### JavaScript
```javascript
DSPConnection.setMixMatrix(
  matrix,
  outchannels,
  inchannels,
  inchannel_hop
);
```

## dspconnection_setuserdata
kind: function
index: 8

### C++
```cpp
FMOD_RESULT DSPConnection::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_DSPConnection_SetUserData(
  FMOD_DSPCONNECTION *dspconnection,
  void *userdata
);
```

### C#
```csharp
RESULT DSPConnection.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
DSPConnection.setUserData(
  userdata
);
```

## FMOD_DSPCONNECTION_TYPE
kind: example
index: 9
heading: FMOD_DSPCONNECTION_TYPE

### C/C++
```cpp
typedef enum FMOD_DSPCONNECTION_TYPE {
  FMOD_DSPCONNECTION_TYPE_STANDARD,
  FMOD_DSPCONNECTION_TYPE_SIDECHAIN,
  FMOD_DSPCONNECTION_TYPE_SEND,
  FMOD_DSPCONNECTION_TYPE_SEND_SIDECHAIN,
  FMOD_DSPCONNECTION_TYPE_PREALLOCATED,
  FMOD_DSPCONNECTION_TYPE_MAX
} FMOD_DSPCONNECTION_TYPE;
```

### C#
```csharp
enum DSPCONNECTION_TYPE
{
    STANDARD,
    SIDECHAIN,
    SEND,
    SEND_SIDECHAIN,
    PREALLOCATED,
    MAX,
}
```

### JavaScript
```javascript
FMOD.DSPCONNECTION_TYPE_STANDARD
FMOD.DSPCONNECTION_TYPE_SIDECHAIN
FMOD.DSPCONNECTION_TYPE_SEND
FMOD.DSPCONNECTION_TYPE_SEND_SIDECHAIN
FMOD.DSPCONNECTION_TYPE_PREALLOCATED
FMOD.DSPCONNECTION_TYPE_MAX
```

