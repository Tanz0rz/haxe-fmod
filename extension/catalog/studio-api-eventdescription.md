# studio-api-eventdescription

## studio_eventdescription_createinstance
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Studio::EventDescription::createInstance(
  Studio::EventInstance **instance
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_CreateInstance(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_EVENTINSTANCE **instance
);
```

### C#
```csharp
RESULT Studio.EventDescription.createInstance(
  out EventInstance instance
);
```

### JavaScript
```javascript
Studio.EventDescription.createInstance(
  instance
);
```

## studio_eventdescription_getid
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getID(
  FMOD_GUID *id
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetID(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_GUID *id
);
```

### C#
```csharp
RESULT Studio.EventDescription.getID(
  out Guid id
);
```

### JavaScript
```javascript
Studio.EventDescription.getID(
  id
);
```

## studio_eventdescription_getinstancecount
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getInstanceCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetInstanceCount(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int *count
);
```

### C#
```csharp
RESULT Studio.EventDescription.getInstanceCount(
  out int count
);
```

### JavaScript
```javascript
Studio.EventDescription.getInstanceCount(
  count
);
```

## studio_eventdescription_getinstancelist
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getInstanceList(
  Studio::EventInstance **array,
  int capacity,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetInstanceList(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_EVENTINSTANCE **array,
  int capacity,
  int *count
);
```

### C#
```csharp
RESULT Studio.EventDescription.getInstanceList(
  out EventInstance[] array
);
```

### JavaScript
```javascript
Studio.EventDescription.getInstanceList(
  array,
  capacity,
  count
);
```

## studio_eventdescription_getlength
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getLength(
  int *length
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetLength(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int *length
);
```

### C#
```csharp
RESULT Studio.EventDescription.getLength(
  out int length
);
```

### JavaScript
```javascript
Studio.EventDescription.getLength(
  length
);
```

## studio_eventdescription_getminmaxdistance
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getMinMaxDistance(
  float *min,
  float *max
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetMinMaxDistance(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  float *min,
  float *max
);
```

### C#
```csharp
RESULT Studio.EventDescription.getMinMaxDistance(
  out float min,
  out float max
);
```

### JavaScript
```javascript
Studio.EventDescription.getMinMaxDistance(
  min,
  max
);
```

## studio_eventdescription_getparameterdescriptionbyid
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterDescriptionByID(
  FMOD_STUDIO_PARAMETER_ID id,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterDescriptionByID(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_PARAMETER_ID id,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterDescriptionByID(
  PARAMETER_ID id,
  out PARAMETER_DESCRIPTION parameter
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterDescriptionByID(
  id,
  parameter
);
```

## studio_eventdescription_getparameterdescriptionbyindex
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterDescriptionByIndex(
  int index,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterDescriptionByIndex(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int index,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterDescriptionByIndex(
  int index,
  out PARAMETER_DESCRIPTION parameter
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterDescriptionByIndex(
  index,
  parameter
);
```

## studio_eventdescription_getparameterdescriptionbyname
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterDescriptionByName(
  const char *name,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterDescriptionByName(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  const char *name,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterDescriptionByName(
  string name,
  out PARAMETER_DESCRIPTION parameter
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterDescriptionByName(
  name,
  parameter
);
```

## studio_eventdescription_getparameterdescriptioncount
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterDescriptionCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterDescriptionCount(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int *count
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterDescriptionCount(
  out int count
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterDescriptionCount(
  count
);
```

## studio_eventdescription_getparameterlabelbyid
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterLabelByID(
  FMOD_STUDIO_PARAMETER_ID id,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterLabelByID(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_PARAMETER_ID id,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterLabelByID(
  PARAMETER_ID id,
  int labelindex,
  out string label
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterLabelByID(
  id,
  labelindex,
  label,
  size,
  retrieved
);
```

## studio_eventdescription_getparameterlabelbyindex
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterLabelByIndex(
  int index,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterLabelByIndex(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int index,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterLabelByIndex(
  int index,
  int labelindex,
  out string label
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterLabelByIndex(
  index,
  labelindex,
  label,
  size,
  retrieved
);
```

## studio_eventdescription_getparameterlabelbyname
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getParameterLabelByName(
  const char *name,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetParameterLabelByName(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  const char *name,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.EventDescription.getParameterLabelByName(
  string name,
  int labelindex,
  out string label
);
```

### JavaScript
```javascript
Studio.EventDescription.getParameterLabelByName(
  name,
  labelindex,
  label,
  size,
  retrieved
);
```

## studio_eventdescription_getpath
kind: function
index: 13

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getPath(
  char *path,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetPath(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  char *path,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.EventDescription.getPath(
  out string path
);
```

### JavaScript
```javascript
Studio.EventDescription.getPath(
  path,
  size,
  retrieved
);
```

## studio_eventdescription_getsampleloadingstate
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getSampleLoadingState(
  FMOD_STUDIO_LOADING_STATE *state
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetSampleLoadingState(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_LOADING_STATE *state
);
```

### C#
```csharp
RESULT Studio.EventDescription.getSampleLoadingState(
  out LOADING_STATE state
);
```

### JavaScript
```javascript
Studio.EventDescription.getSampleLoadingState(
  state
);
```

## studio_eventdescription_getsoundsize
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getSoundSize(
  float *size
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetSoundSize(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  float *size
);
```

### C#
```csharp
RESULT Studio.EventDescription.getSoundSize(
  out float size
);
```

### JavaScript
```javascript
Studio.EventDescription.getSoundSize(
  size
);
```

## studio_eventdescription_getuserdata
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetUserData(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  void **userdata
);
```

### C#
```csharp
RESULT Studio.EventDescription.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Studio.EventDescription.getUserData(
  userdata
);
```

## studio_eventdescription_getuserproperty
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getUserProperty(
  const char *name,
  FMOD_STUDIO_USER_PROPERTY *property
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetUserProperty(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  const char *name,
  FMOD_STUDIO_USER_PROPERTY *property
);
```

### C#
```csharp
RESULT Studio.EventDescription.getUserProperty(
  string name,
  out USER_PROPERTY property
);
```

### JavaScript
```javascript
Studio.EventDescription.getUserProperty(
  name,
  property
);
```

## studio_eventdescription_getuserpropertybyindex
kind: function
index: 18

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getUserPropertyByIndex(
  int index,
  FMOD_STUDIO_USER_PROPERTY *property
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetUserPropertyByIndex(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int index,
  FMOD_STUDIO_USER_PROPERTY *property
);
```

### C#
```csharp
RESULT Studio.EventDescription.getUserPropertyByIndex(
  int index,
  out USER_PROPERTY property
);
```

### JavaScript
```javascript
Studio.EventDescription.getUserPropertyByIndex(
  index,
  property
);
```

## studio_eventdescription_getuserpropertycount
kind: function
index: 19

### C++
```cpp
FMOD_RESULT Studio::EventDescription::getUserPropertyCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_GetUserPropertyCount(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  int *count
);
```

### C#
```csharp
RESULT Studio.EventDescription.getUserPropertyCount(
  out int count
);
```

### JavaScript
```javascript
Studio.EventDescription.getUserPropertyCount(
  count
);
```

## studio_eventdescription_hassustainpoint
kind: function
index: 20

### C++
```cpp
FMOD_RESULT Studio::EventDescription::hasSustainPoint(
  bool *sustainPoint
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_HasSustainPoint(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_BOOL *sustainPoint
);
```

### C#
```csharp
RESULT Studio.EventDescription.hasSustainPoint(
  out bool sustainPoint
);
```

### JavaScript
```javascript
Studio.EventDescription.hasSustainPoint(
  sustainPoint
);
```

## studio_eventdescription_is3d
kind: function
index: 21

### C++
```cpp
FMOD_RESULT Studio::EventDescription::is3D(
  bool *is3d
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_Is3D(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_BOOL *is3d
);
```

### C#
```csharp
RESULT Studio.EventDescription.is3D(
  out bool is3d
);
```

### JavaScript
```javascript
Studio.EventDescription.is3D(
  is3d
);
```

## studio_eventdescription_isdopplerenabled
kind: function
index: 22

### C++
```cpp
FMOD_RESULT Studio::EventDescription::isDopplerEnabled(
  bool *doppler
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_IsDopplerEnabled(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_BOOL *doppler
);
```

### C#
```csharp
RESULT Studio.EventDescription.isDopplerEnabled(
  out bool doppler
);
```

### JavaScript
```javascript
Studio.EventDescription.isDopplerEnabled(
  doppler
);
```

## studio_eventdescription_isoneshot
kind: function
index: 23

### C++
```cpp
FMOD_RESULT Studio::EventDescription::isOneshot(
  bool *oneshot
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_IsOneshot(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_BOOL *oneshot
);
```

### C#
```csharp
RESULT Studio.EventDescription.isOneshot(
  out bool oneshot
);
```

### JavaScript
```javascript
Studio.EventDescription.isOneshot(
  oneshot
);
```

## studio_eventdescription_issnapshot
kind: function
index: 24

### C++
```cpp
FMOD_RESULT Studio::EventDescription::isSnapshot(
  bool *snapshot
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_IsSnapshot(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_BOOL *snapshot
);
```

### C#
```csharp
RESULT Studio.EventDescription.isSnapshot(
  out bool snapshot
);
```

### JavaScript
```javascript
Studio.EventDescription.isSnapshot(
  snapshot
);
```

## studio_eventdescription_isstream
kind: function
index: 25

### C++
```cpp
FMOD_RESULT Studio::EventDescription::isStream(
  bool *isStream
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_IsStream(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_BOOL *isStream
);
```

### C#
```csharp
RESULT Studio.EventDescription.isStream(
  out bool isStream
);
```

### JavaScript
```javascript
Studio.EventDescription.isStream(
  isStream
);
```

## studio_eventdescription_isvalid
kind: function
index: 26

### C++
```cpp
bool Studio::EventDescription::isValid()
```

### C
```c
bool FMOD_Studio_EventDescription_IsValid(FMOD_STUDIO_EVENTDESCRIPTION *eventdescription)
```

### C#
```csharp
bool Studio.EventDescription.isValid()
```

### JavaScript
```javascript
Studio.EventDescription.isValid()
```

## studio_eventdescription_loadsampledata
kind: function
index: 27

### C++
```cpp
FMOD_RESULT Studio::EventDescription::loadSampleData();
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_LoadSampleData(FMOD_STUDIO_EVENTDESCRIPTION *eventdescription);
```

### C#
```csharp
RESULT Studio.EventDescription.loadSampleData();
```

### JavaScript
```javascript
Studio.EventDescription.loadSampleData();
```

## studio_eventdescription_releaseallinstances
kind: function
index: 28

### C++
```cpp
FMOD_RESULT Studio::EventDescription::releaseAllInstances();
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_ReleaseAllInstances(FMOD_STUDIO_EVENTDESCRIPTION *eventdescription);
```

### C#
```csharp
RESULT Studio.EventDescription.releaseAllInstances();
```

### JavaScript
```javascript
Studio.EventDescription.releaseAllInstances();
```

## studio_eventdescription_setcallback
kind: function
index: 29

### C++
```cpp
FMOD_RESULT Studio::EventDescription::setCallback(
  FMOD_STUDIO_EVENT_CALLBACK callback,
  FMOD_STUDIO_EVENT_CALLBACK_TYPE callbackmask = FMOD_STUDIO_EVENT_CALLBACK_ALL
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_SetCallback(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_EVENT_CALLBACK callback,
  FMOD_STUDIO_EVENT_CALLBACK_TYPE callbackmask
);
```

### C#
```csharp
RESULT Studio.EventDescription.setCallback(
  EVENT_CALLBACK callback,
  EVENT_CALLBACK_TYPE callbackmask = EVENT_CALLBACK_TYPE.ALL
);
```

### JavaScript
```javascript
Studio.EventDescription.setCallback(
  callback,
  callbackmask
);
```

## studio_eventdescription_setuserdata
kind: function
index: 30

### C++
```cpp
FMOD_RESULT Studio::EventDescription::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_SetUserData(
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  void *userdata
);
```

### C#
```csharp
RESULT Studio.EventDescription.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Studio.EventDescription.setUserData(
  userdata
);
```

## studio_eventdescription_unloadsampledata
kind: function
index: 31

### C++
```cpp
FMOD_RESULT Studio::EventDescription::unloadSampleData();
```

### C
```c
FMOD_RESULT FMOD_Studio_EventDescription_UnloadSampleData(FMOD_STUDIO_EVENTDESCRIPTION *eventdescription);
```

### C#
```csharp
RESULT Studio.EventDescription.unloadSampleData();
```

### JavaScript
```javascript
Studio.EventDescription.unloadSampleData();
```

## FMOD_STUDIO_USER_PROPERTY
kind: example
index: 32
heading: FMOD_STUDIO_USER_PROPERTY
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_USER_PROPERTY {
  const char                      *name;
  FMOD_STUDIO_USER_PROPERTY_TYPE   type;
  union
  {
      int                              intvalue;
      FMOD_BOOL                        boolvalue;
      float                            floatvalue;
      const char                      *stringvalue;
  }
} FMOD_STUDIO_USER_PROPERTY;
```

### C#
```csharp
struct USER_PROPERTY
{
    StringWrapper name;
    USER_PROPERTY_TYPE type;
    int intvalue;
    bool boolvalue;
    float floatvalue;
    string stringvalue;
}
```

### JavaScript
```javascript
FMOD_STUDIO_USER_PROPERTY
{
  name,
  type,
  intvalue,
  boolvalue,
  floatvalue,
  stringvalue,
};
```

## FMOD_STUDIO_USER_PROPERTY_TYPE
kind: example
index: 33
heading: FMOD_STUDIO_USER_PROPERTY_TYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_STUDIO_USER_PROPERTY_TYPE {
  FMOD_STUDIO_USER_PROPERTY_TYPE_INTEGER,
  FMOD_STUDIO_USER_PROPERTY_TYPE_BOOLEAN,
  FMOD_STUDIO_USER_PROPERTY_TYPE_FLOAT,
  FMOD_STUDIO_USER_PROPERTY_TYPE_STRING
} FMOD_STUDIO_USER_PROPERTY_TYPE;
```

### C#
```csharp
enum USER_PROPERTY_TYPE
{
    INTEGER,
    BOOLEAN,
    FLOAT,
    STRING,
}
```

### JavaScript
```javascript
STUDIO_USER_PROPERTY_TYPE_INTEGER
STUDIO_USER_PROPERTY_TYPE_BOOLEAN
STUDIO_USER_PROPERTY_TYPE_FLOAT
STUDIO_USER_PROPERTY_TYPE_STRING
```

