# platforms-html5

## Libraries
kind: example
index: 0
heading: Libraries

### html
```text
<script type="text/javascript" src="fmod.js"></script>
```

## Libraries#2
kind: example
index: 1
heading: Libraries

### html
```text
<script type="text/javascript" src="fmodstudio.js"></script>
```

## Using FMOD with C/C++
kind: example
index: 2
heading: Using FMOD with C/C++

### text
```text
-s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s EXPORTED_RUNTIME_METHODS=ccall,cwrap,setValue,getValue
```

## Flags using WASM pthread build
kind: example
index: 3
heading: Flags using WASM pthread build

### text
```text
-pthread -s PTHREAD_POOL_SIZE=5
```

## Overriding FMOD's 'window' handle.
kind: example
index: 4
heading: Overriding FMOD's 'window' handle.

### JavaScript
```javascript
EM_ASM({
    console.log("Setting FMOD module window handle");
    Module.window = window;
});
```

## Application setup
kind: example
index: 5
heading: Application setup

### JavaScript
```javascript
var FMOD = {};                          // FMOD global object which must be declared to enable 'main' and 'preRun' and then call the constructor function.
FMOD.window = window;                   // Optional. Specify main window handle from a different context if needed.
FMOD.preRun = prerun;                   // Optional. Will be called before FMOD runs, but after the Emscripten runtime has initialized
FMOD.onRuntimeInitialized = main;       // Called when the Emscripten runtime has initialized
FMOD.INITIAL_MEMORY = 64*1024*1024;     // FMOD Heap defaults to 16mb which is enough for this demo, but set it differently here for demonstration (64mb)
FMODModule(FMOD);                       // Requires being called to initialize the 'FMOD' object via the FMOD constructor.

function prerun()
{
    // Call FMOD file preloading functions here to mount local files. Otherwise load custom data from memory or use own file system. 
}
```

## Setting and getting
kind: example
index: 6
heading: Setting and getting

### JavaScript
```javascript
var outval = {}; // generic variable to reuse and be passed to FMOD functions.
var name;        // to store name of sound.

sound.getName(outval);
name = outval.val;  // 'val' contains the data. Pass it to the variable we want to keep.

console.log(name);
```

## Using structures
kind: example
index: 7
heading: Using structures

### JavaScript
```javascript
var guid = FMOD.GUID();
var info = FMOD.STUDIO_BANK_INFO();
```

## Direct from host, via FMOD's filesystem
kind: example
index: 8
heading: Direct from host, via FMOD's filesystem

### JavaScript
```javascript
// Will be called before FMOD runs, but after the Emscripten runtime has initialized
// Call FMOD file preloading functions here to mount local files. Otherwise load custom data from memory or use own file system.
function prerun()
{
    var fileUrl = "/public/js/";
    var fileName;
    var folderName = "/";
    var canRead = true;
    var canWrite = false;

    fileName = [
        "dog.wav",
        "lion.wav",
        "wave.mp3"
    ];

    for (var count = 0; count < fileName.length; count++)
    {
        FMOD.FS_createPreloadedFile(folderName, fileName[count], fileUrl + fileName[count], canRead, canWrite);
    }
}
```

## Direct from host, via FMOD's filesystem#2
kind: example
index: 9
heading: Direct from host, via FMOD's filesystem

### JavaScript
```javascript
result = gSystem.createSound("/lion.wav", FMOD.LOOP_OFF, null, outval);
CHECK_RESULT(result);
```

## Via memory
kind: example
index: 10
heading: Via memory

### JavaScript
```javascript
var chars  = new Uint8Array(e.target.result);
var outval = {};
var result;
var exinfo = FMOD.CREATESOUNDEXINFO();
exinfo.length = chars.length;

result = gSystem.createStream(chars.buffer, FMOD.LOOP_OFF | FMOD.OPENMEMORY, exinfo, outval);
CHECK_RESULT(result);
```

## Via callbacks
kind: example
index: 11
heading: Via callbacks

### JavaScript
```javascript
var info = new FMOD.STUDIO_BANK_INFO();

info.opencallback = customFileOpen;
info.closecallback = customFileClose;
info.readcallback = customFileRead;
info.seekcallback = customFileSeek;
info.userdata = filename;

result = gSystem.loadBankCustom(info, FMOD.STUDIO_LOAD_BANK_NONBLOCKING, outval);
CHECK_RESULT(result);
```

## Via callbacks#2
kind: example
index: 12
heading: Via callbacks

### JavaScript
```javascript
function customFileOpen(name, filesize, handle, userdata)
{
    var filesize_outval = {};
    var handle_outval = {}

    // We pass the filename into our callbacks via userdata in the custom info struct
    var filename = userdata;

    var result = FMOD.file_open(gSystemLowLevel, filename, filesize_outval, handle_outval)
    if (result == FMOD.OK)
    {
        filesize.val = filesize_outval.val;
        handle.val = handle_outval.val;
    }

    return result;
}
```

## Via callbacks#3
kind: example
index: 13
heading: Via callbacks

### JavaScript
```javascript
function customFileRead(handle, buffer, sizebytes, bytesread, userdata)
{
    var bytesread_outval = {};
    var buffer_outval = {};

    // Read from the file into a new buffer. This part can be swapped for your own file system.
    var result = FMOD.file_read(handle, buffer_outval, sizebytes, bytesread_outval)   // read produces a new array with data.
    if (result == FMOD.OK)
    {
        bytesread.val = bytesread_outval.val;
    }

    // Copy the new buffer contents into the buffer that is passed into the callback. 'buffer' is a memory address, so we can only write to it with FMOD.setValue
    for (count = 0; count < bytesread.val; count++)
    {
        FMOD.setValue(buffer + count, buffer_outval.val[count], 'i8');      // See https://kripken.github.io/emscripten-site/docs/api_reference/preamble.js.html#accessing-memory for docs on setValue.
    }

    return result;
}
```

## CPU Overhead
kind: example
index: 14
heading: CPU Overhead

### JavaScript
```javascript
var outval = {};
result = gSystem.getDriverInfo(0, null, null, outval, null, null);
CHECK_RESULT(result);
result = gSystem.setSoftwareFormat(outval.val, FMOD.SPEAKERMODE_DEFAULT, 0)
CHECK_RESULT(result);
```

## Audio Stability (Stuttering)
kind: example
index: 15
heading: Audio Stability (Stuttering)

### JavaScript
```javascript
result = gSystem.setDSPBufferSize(2048, 2);
CHECK_RESULT(result);
```

