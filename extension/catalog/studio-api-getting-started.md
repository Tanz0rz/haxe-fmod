# studio-api-getting-started

## 12.1.1 Studio API Initialization
kind: example
index: 0
heading: 12.1.1 Studio API Initialization

### text
```text
FMOD_RESULT result;
FMOD::Studio::System* system = NULL;

result = FMOD::Studio::System::create(&system); // Create the Studio System object.
if (result != FMOD_OK)
{
    printf("FMOD error! (%d) %s\n", result, FMOD_ErrorString(result));
    exit(-1);
}

// Initialize the Studio system, which also initializes the Core system
result = system->initialize(512, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL, 0);
if (result != FMOD_OK)
{
    printf("FMOD error! (%d) %s\n", result, FMOD_ErrorString(result));
    exit(-1);
}
```

