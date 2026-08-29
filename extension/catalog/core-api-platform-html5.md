# core-api-platform-html5

## fs_createpreloadedfile
kind: function
index: 0

### JavaScript
```javascript
FS_createPreloadedFile(ptr, value, type);
```

## Example usage.
kind: example
index: 1
heading: Example usage.

### JavaScript
```javascript
function prerun()
{
    var fileUrl = "/public/js/";
    var fileName = "Master.Bank";
    var folderName = "/";

    FMOD.FS_createPreloadedFile(folderName, fileName, fileUrl + fileName, true, false);
}
```

## readfile
kind: function
index: 2

### JavaScript
```javascript
ReadFile(system, value, type);
```

## Example usage.#2
kind: example
index: 3
heading: Example usage.

### JavaScript
```javascript
result = FMOD.ReadFile(gSystemCore, "/" + filename, outval);
CHECK_RESULT(result);

memoryPtr    = outval.val;      // Pointer to FMOD owned file data. See below where FMOD.Memory_Free is used to free it.
memoryLength = outval.length;   // Length of FMOD owned file data

result = gSystem.loadBankMemory(memoryPtr, memoryLength, FMOD.STUDIO_LOAD_MEMORY, FMOD.STUDIO_LOAD_BANK_NONBLOCKING, outval);
CHECK_RESULT(result);
```

## memory_free
kind: function
index: 4

### JavaScript
```javascript
Memory_Free(ptr);
```

## file_open
kind: function
index: 5

### JavaScript
```javascript
file_open(system, filename, filesize, handle);
```

## file_close
kind: function
index: 6

### JavaScript
```javascript
file_close(handle);
```

## file_read
kind: function
index: 7

### JavaScript
```javascript
file_read(handle, buffer, sizebytes, bytesread);
```

## file_seek
kind: function
index: 8

### JavaScript
```javascript
file_seek(handle, pos);
```

## setvalue
kind: function
index: 9

### JavaScript
```javascript
setValue(ptr, value, type);
```

## Example usage.#3
kind: example
index: 10
heading: Example usage.

### JavaScript
```javascript
for (var samp = 0; samp < length; samp++)
{
    for (var chan = 0; chan < outchannels; chan++)
    {
        // This DSP filter just halves the volume! Input is modified, and sent to output.
        let val = FMOD.getValue(inbuffer + (((samp * inchannels) + chan) * 4), 'float') * dsp_state.plugindata.volume_linear;

        FMOD.setValue(outbuffer + (((samp * outchannels) + chan) * 4), val, 'float');
    }
}
```

## getvalue
kind: function
index: 11

### JavaScript
```javascript
getValue(ptr, value);
```

## Example usage.#4
kind: example
index: 12
heading: Example usage.

### JavaScript
```javascript
for (var samp = 0; samp < length; samp++)
{
    for (var chan = 0; chan < outchannels; chan++)
    {
        // This DSP filter just halves the volume! Input is modified, and sent to output.
        let val = FMOD.getValue(inbuffer + (((samp * inchannels) + chan) * 4), 'float') * dsp_state.plugindata.volume_linear;

        FMOD.setValue(outbuffer + (((samp * outchannels) + chan) * 4), val, 'float');
    }
}
```

## file_seek_1
kind: function
index: 13

### JavaScript
```javascript
file_seek(handle, pos);
```

