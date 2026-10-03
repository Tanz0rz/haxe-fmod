# studio-api-bank

## studio_bank_getbuscount
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Studio::Bank::getBusCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetBusCount(
  FMOD_STUDIO_BANK *bank,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getBusCount(
  out int count
);
```

### JavaScript
```javascript
Bank.getBusCount(
  count
);
```

## studio_bank_getbuslist
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Studio::Bank::getBusList(
  Studio::Bus **array,
  int capacity,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetBusList(
  FMOD_STUDIO_BANK *bank,
  FMOD_STUDIO_BUS **array,
  int capacity,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getBusList(
  out Bus[] array
);
```

### JavaScript
```javascript
Bank.getBusList(
  array,
  capacity,
  count
);
```

## studio_bank_geteventcount
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Studio::Bank::getEventCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetEventCount(
  FMOD_STUDIO_BANK *bank,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getEventCount(
  out int count
);
```

### JavaScript
```javascript
Bank.getEventCount(
  count
);
```

## studio_bank_geteventlist
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Studio::Bank::getEventList(
  Studio::EventDescription **array,
  int capacity,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetEventList(
  FMOD_STUDIO_BANK *bank,
  FMOD_STUDIO_EVENTDESCRIPTION **array,
  int capacity,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getEventList(
  out EventDescription[] array
);
```

### JavaScript
```javascript
Bank.getEventList(
  array,
  capacity,
  count
);
```

## studio_bank_getid
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Studio::Bank::getID(
  FMOD_GUID *id
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetID(
  FMOD_STUDIO_BANK *bank,
  FMOD_GUID *id
);
```

### C#
```csharp
RESULT Studio.Bank.getID(
  out Guid id
);
```

### JavaScript
```javascript
Bank.getID(
  id
);
```

## studio_bank_getloadingstate
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Studio::Bank::getLoadingState(
  FMOD_STUDIO_LOADING_STATE *state
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetLoadingState(
  FMOD_STUDIO_BANK *bank,
  FMOD_STUDIO_LOADING_STATE *state
);
```

### C#
```csharp
RESULT Studio.Bank.getLoadingState(
  out LOADING_STATE state
);
```

### JavaScript
```javascript
Bank.getLoadingState(
  state
);
```

## studio_bank_getpath
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Studio::Bank::getPath(
  char *path,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetPath(
  FMOD_STUDIO_BANK *bank,
  char *path,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.Bank.getPath(
  out string path
);
```

### JavaScript
```javascript
Bank.getPath(
  path,
  size,
  retrieved
);
```

## studio_bank_getsampleloadingstate
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Studio::Bank::getSampleLoadingState(
  FMOD_STUDIO_LOADING_STATE *state
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetSampleLoadingState(
  FMOD_STUDIO_BANK *bank,
  FMOD_STUDIO_LOADING_STATE *state
);
```

### C#
```csharp
RESULT Studio.Bank.getSampleLoadingState(
  out LOADING_STATE state
);
```

### JavaScript
```javascript
Bank.getSampleLoadingState(
  state
);
```

## studio_bank_getstringcount
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Studio::Bank::getStringCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetStringCount(
  FMOD_STUDIO_BANK *bank,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getStringCount(
  out int count
);
```

### JavaScript
```javascript
Bank.getStringCount(
  count
);
```

## studio_bank_getstringinfo
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Studio::Bank::getStringInfo(
  int index,
  FMOD_GUID *id,
  char *path,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetStringInfo(
  FMOD_STUDIO_BANK *bank,
  int index,
  FMOD_GUID *id,
  char *path,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.Bank.getStringInfo(
  int index,
  out Guid id,
  out string path
);
```

### JavaScript
```javascript
Bank.getStringInfo(
  index,
  id,
  path,
  size,
  retrieved
);
```

## studio_bank_getuserdata
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Studio::Bank::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetUserData(
  FMOD_STUDIO_BANK *bank,
  void **userdata
);
```

### C#
```csharp
RESULT Studio.Bank.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Bank.getUserData(
  userdata
);
```

## studio_bank_getvcacount
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Studio::Bank::getVCACount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetVCACount(
  FMOD_STUDIO_BANK *bank,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getVCACount(
  out int count
);
```

### JavaScript
```javascript
Bank.getVCACount(
  count
);
```

## studio_bank_getvcalist
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Studio::Bank::getVCAList(
  Studio::VCA **array,
  int capacity,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_GetVCAList(
  FMOD_STUDIO_BANK *bank,
  FMOD_STUDIO_VCA **array,
  int capacity,
  int *count
);
```

### C#
```csharp
RESULT Studio.Bank.getVCAList(
  out VCA[] array
);
```

### JavaScript
```javascript
Bank.getVCAList(
  array,
  capacity,
  count
);
```

## studio_bank_isvalid
kind: function
index: 13

### C++
```cpp
bool Studio::Bank::isValid()
```

### C
```c
bool FMOD_Studio_Bank_IsValid(FMOD_STUDIO_BANK *bank)
```

### C#
```csharp
bool Studio.Bank.isValid()
```

### JavaScript
```javascript
Studio.Bank.isValid()
```

## studio_bank_loadsampledata
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Studio::Bank::loadSampleData();
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_LoadSampleData(FMOD_STUDIO_BANK *bank);
```

### C#
```csharp
RESULT Studio.Bank.loadSampleData();
```

### JavaScript
```javascript
Bank.loadSampleData();
```

## studio_bank_setuserdata
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Studio::Bank::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_SetUserData(
  FMOD_STUDIO_BANK *bank,
  void *userdata
);
```

### C#
```csharp
RESULT Studio.Bank.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Bank.setUserData(
  userdata
);
```

## studio_bank_unload
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Studio::Bank::unload();
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_Unload(FMOD_STUDIO_BANK *bank);
```

### C#
```csharp
RESULT Studio.Bank.unload();
```

### JavaScript
```javascript
Bank.unload();
```

## studio_bank_unloadsampledata
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Studio::Bank::unloadSampleData();
```

### C
```c
FMOD_RESULT FMOD_Studio_Bank_UnloadSampleData(FMOD_STUDIO_BANK *bank);
```

### C#
```csharp
RESULT Studio.Bank.unloadSampleData();
```

### JavaScript
```javascript
Bank.unloadSampleData();
```

