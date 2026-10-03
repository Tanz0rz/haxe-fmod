# core-api-channel

## channel_getchannelgroup
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Channel::getChannelGroup(
  ChannelGroup **channelgroup
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetChannelGroup(
  FMOD_CHANNEL *channel,
  FMOD_CHANNELGROUP **channelgroup
);
```

### C#
```csharp
RESULT Channel.getChannelGroup(
  out ChannelGroup channelgroup
);
```

### JavaScript
```javascript
Channel.getChannelGroup(
  channelgroup
);
```

## channel_getcurrentsound
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Channel::getCurrentSound(
  Sound **sound
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetCurrentSound(
  FMOD_CHANNEL *channel,
  FMOD_SOUND **sound
);
```

### C#
```csharp
RESULT Channel.getCurrentSound(
  out Sound sound
);
```

### JavaScript
```javascript
Channel.getCurrentSound(
  sound
);
```

## channel_getfrequency
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Channel::getFrequency(
  float *frequency
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetFrequency(
  FMOD_CHANNEL *channel,
  float *frequency
);
```

### C#
```csharp
RESULT Channel.getFrequency(
  out float frequency
);
```

### JavaScript
```javascript
Channel.getFrequency(
  frequency
);
```

## channel_getindex
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Channel::getIndex(
  int *index
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetIndex(
  FMOD_CHANNEL *channel,
  int *index
);
```

### C#
```csharp
RESULT Channel.getIndex(
  out int index
);
```

### JavaScript
```javascript
Channel.getIndex(
  index
);
```

## channel_getloopcount
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Channel::getLoopCount(
  int *loopcount
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetLoopCount(
  FMOD_CHANNEL *channel,
  int *loopcount
);
```

### C#
```csharp
RESULT Channel.getLoopCount(
  out int loopcount
);
```

### JavaScript
```javascript
Channel.getLoopCount(
  loopcount
);
```

## channel_getlooppoints
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Channel::getLoopPoints(
  unsigned int *loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int *loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetLoopPoints(
  FMOD_CHANNEL *channel,
  unsigned int *loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int *loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C#
```csharp
RESULT Channel.getLoopPoints(
  out uint loopstart,
  TIMEUNIT loopstarttype,
  out uint loopend,
  TIMEUNIT loopendtype
);
```

### JavaScript
```javascript
Channel.getLoopPoints(
  loopstart,
  loopstarttype,
  loopend,
  loopendtype
);
```

## channel_getposition
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Channel::getPosition(
  unsigned int *position,
  FMOD_TIMEUNIT postype
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetPosition(
  FMOD_CHANNEL *channel,
  unsigned int *position,
  FMOD_TIMEUNIT postype
);
```

### C#
```csharp
RESULT Channel.getPosition(
  out uint position,
  TIMEUNIT postype
);
```

### JavaScript
```javascript
Channel.getPosition(
  position,
  postype
);
```

## channel_getpriority
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Channel::getPriority(
  int *priority
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetPriority(
  FMOD_CHANNEL *channel,
  int *priority
);
```

### C#
```csharp
RESULT Channel.getPriority(
  out int priority
);
```

### JavaScript
```javascript
Channel.getPriority(
  priority
);
```

## channel_isvirtual
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Channel::isVirtual(
  bool *isvirtual
);
```

### C
```c
FMOD_RESULT FMOD_Channel_IsVirtual(
  FMOD_CHANNEL *channel,
  FMOD_BOOL *isvirtual
);
```

### C#
```csharp
RESULT Channel.isVirtual(
  out bool isvirtual
);
```

### JavaScript
```javascript
Channel.isVirtual(
  isvirtual
);
```

## channel_setchannelgroup
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Channel::setChannelGroup(
  ChannelGroup *channelgroup
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetChannelGroup(
  FMOD_CHANNEL *channel,
  FMOD_CHANNELGROUP *channelgroup
);
```

### C#
```csharp
RESULT Channel.setChannelGroup(
  ChannelGroup channelgroup
);
```

### JavaScript
```javascript
Channel.setChannelGroup(
  channelgroup
);
```

## channel_setfrequency
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Channel::setFrequency(
  float frequency
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetFrequency(
  FMOD_CHANNEL *channel,
  float frequency
);
```

### C#
```csharp
RESULT Channel.setFrequency(
  float frequency
);
```

### JavaScript
```javascript
Channel.setFrequency(
  frequency
);
```

## channel_setloopcount
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Channel::setLoopCount(
  int loopcount
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetLoopCount(
  FMOD_CHANNEL *channel,
  int loopcount
);
```

### C#
```csharp
RESULT Channel.setLoopCount(
  int loopcount
);
```

### JavaScript
```javascript
Channel.setLoopCount(
  loopcount
);
```

## channel_setlooppoints
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Channel::setLoopPoints(
  unsigned int loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetLoopPoints(
  FMOD_CHANNEL *channel,
  unsigned int loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C#
```csharp
RESULT Channel.setLoopPoints(
  uint loopstart,
  TIMEUNIT loopstarttype,
  uint loopend,
  TIMEUNIT loopendtype
);
```

### JavaScript
```javascript
Channel.setLoopPoints(
  loopstart,
  loopstarttype,
  loopend,
  loopendtype
);
```

## channel_setposition
kind: function
index: 13

### C++
```cpp
FMOD_RESULT Channel::setPosition(
  unsigned int position,
  FMOD_TIMEUNIT postype
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetPosition(
  FMOD_CHANNEL *channel,
  unsigned int position,
  FMOD_TIMEUNIT postype
);
```

### C#
```csharp
RESULT Channel.setPosition(
  uint position,
  TIMEUNIT postype
);
```

### JavaScript
```javascript
Channel.setPosition(
  position,
  postype
);
```

## channel_setpriority
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Channel::setPriority(
  int priority
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetPriority(
  FMOD_CHANNEL *channel,
  int priority
);
```

### C#
```csharp
RESULT Channel.setPriority(
  int priority
);
```

### JavaScript
```javascript
Channel.setPriority(
  priority
);
```

