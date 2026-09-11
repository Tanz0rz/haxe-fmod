# Line-count waivers

`ci/example-line-counts.py` counts the lines of the site's C# snippet (or the C++ one where the page has no C#) against the lines the Haxe tab shows for the same unit. Every unit below was reviewed by hand and the counts differ for the reason in the last column. The script reports a row again when either count moves and asks for the row to go when the counts match. Lines that hold only an opening brace or a C# attribute are not counted, and neither is the package header of a declaration.

| Page | Key | Language | Site | Haxe | Reason |
|---|---|---|---|---|---|
| advanced-core-api-topics | 10.2 Extracting PCM Data from a Sound | C# | 9 | 5 | The three declarations fold into the var lines that receive each result. |
| advanced-core-api-topics | Codec Example#2 | C# | 8 | 4 | The result and handle declarations fold into the var lines, loadPlugin returns the handle. |
| advanced-core-api-topics | Output Example#2 | C# | 5 | 2 | The result and handle declarations fold into the var lines, loadPlugin returns the handle. |
| advanced-core-api-topics | DSP Example#2 | C# | 9 | 4 | The four declarations fold into the var lines, play and createByPlugin return their objects. |
| advanced-core-api-topics | 10.7.1 3D Reverbs | text | 4 | 3 | Reverb3D.create returns the reverb, no separate declaration. |
| advanced-core-api-topics | 10.7.1 3D Reverbs#3 | text | 2 | 7 | setListenerAttributes takes one Fmod3DAttributes, so the three null vectors of the C++ call are written out. |
| advanced-core-api-topics | 10.7.2 Using Multiple Reverbs#3 | text | 2 | 1 | Reverb.get returns the properties, no out struct to declare. |
| advanced-core-api-topics | Added new DSP effects | C++ | 13 | 36 | The site lists the thirteen kinds added in 2.01, the tab shows the whole DspType enum. |
| core-api-channelcontrol | ChannelControl::addFadePoint | C++ | 5 | 4 | getDspClock returns the clocks, no out variable to declare. |
| core-api-channelcontrol | FMOD_CHANNELCONTROL_CALLBACK | C# | 7 | 1 | The five delegate parameters arrive as one ChannelEvent (types.txt skip). |
| core-api-common | FMOD_CPU_USAGE | C# | 8 | 9 | FmodSystemCpuUsage carries the Studio update field too, one struct for both getCPUUsage calls. |
| core-api-common | FMOD_GUID | C# | 1 | 7 | The site names System.Guid, FmodGuid declares NULL and the four data fields. |
| core-api-common | FMOD_MODE | C# | 31 | 37 | ChannelMode keeps six aliases with the older haxefmod spelling of the 3D flags. |
| core-api-common | FMOD_SYNCPOINT | C# | 1 | 3 | The site shows IntPtr, FmodSyncPoint is an index abstract with a NULL value. |
| core-api-common | FMOD_THREAD_AFFINITY | C# | 34 | 19 | The 64-bit group values and the per-thread defaults do not fit an Int (types.txt skip). |
| core-api-common | FMOD_THREAD_PRIORITY | C# | 22 | 24 | CONVOLUTION1 and CONVOLUTION2 are in the 2.03 header, the C# integration leaves them out. |
| core-api-common | FMOD_THREAD_STACK_SIZE | C# | 14 | 16 | CONVOLUTION1 and CONVOLUTION2 are in the 2.03 header, the C# integration leaves them out. |
| core-api-common-dsp-effects | FMOD_DSP_TYPE | C# | 37 | 36 | MAX is a count rather than a unit kind (types.txt skip). |
| core-api-platform-html5 | Example usage.#2 | JavaScript | 8 | 2 | loadBankMemory takes the bytes the game fetched, FMOD.ReadFile and the pointer bookkeeping have no Haxe side. |
| core-api-sound | FMOD_SOUND_PCMREAD_CALLBACK | C# | 5 | 1 | The delegate is one function type line, PcmStream stands in for the sound pointer. |
| core-api-sound | Sound::setDefaults | C# | 3 | 2 | getDefaults returns both defaults, no out variable to declare. |
| core-api-sound | FMOD_TAG | C# | 8 | 10 | data and datalen are folded into intValue, floatValue, stringValue, and length (types.txt skip). |
| core-api-system | FMOD_ADVANCEDSETTINGS | C# | 24 | 12 | Only the fields FmodSettings sets and getAdvancedSettings reads back are declared (types.txt skip). |
| core-api-system | FMOD_CREATESOUNDEXINFO | C# | 38 | 25 | cbsize, the callbacks, and the pointer fields run on FMOD threads (types.txt skip). |
| core-api-system | FMOD_SYSTEM_CALLBACK | C# | 7 | 1 | The five delegate parameters arrive as one SystemEvent (types.txt skip). |
| core-api-system | System::setDSPBufferSize | text | 13 | 10 | The four declarations fold into the var lines that read the getter results. |
| dsp-plugin-api-guide | 18.7 Multiple Plug-ins Within One File#2 | text | 11 | 8 | ERRCHECK lines on calls that return their value, and the plugin info is read in the line that declares the type. |
| glossary | 22.33 Reading Sound Data | C# | 9 | 5 | The three declarations fold into the var lines that receive each result. |
| glossary | 22.49 User Data | C# | 10 | 5 | setUserData takes the string itself, no GCHandle round trip. |
| loading-and-playing-sounds-in-the-core-api | 4.1.1 Non-blocking Sound Creation | text | 3 | 2 | The declaration folds into the var line. |
| loading-and-playing-sounds-in-the-core-api | 4.1.1 Non-blocking Sound Creation#3 | text | 10 | 7 | The nonblock callback cannot be hosted, the exinfo lines are replaced by a getOpenState poll. |
| loading-and-playing-sounds-in-the-core-api | 4.2 Playing a sound | C# | 9 | 8 | The result declaration goes, the checks read lastResult. |
| loading-and-playing-sounds-in-the-core-api | 4.3.1 Creating a Sound from memory | C# | 16 | 9 | fromMemory reads the length from the bytes, the exinfo lines and the GCHandle note go. |
| loading-and-playing-sounds-in-the-core-api | 4.3.3 Creating a Sound by manually providing sample data | C# | 15 | 11 | The read callback cannot be hosted, PcmStream takes the same rate, channels, and size and the game writes the samples. |
| loading-and-playing-sounds-in-the-core-api | 4.3.4 Creating the Sound as a Streamed FSB File | text | 10 | 4 | initialSubsound is an argument of Sound.create, the exinfo lines and the result declaration go. |
| managing-resources-in-the-core-api | 9.5.1 Use a Fixed-size Memory Pool. | text | 2 | 1 | The pool is a setting of Initialize, its result surfaces through lastResult. |
| platforms-html5 | Setting and getting | JavaScript | 7 | 5 | getName returns the string, the outval object goes. |
| platforms-html5 | Via memory | JavaScript | 8 | 2 | fromMemory takes the bytes, mode, and length, the exinfo and outval lines go. |
| platforms-html5 | Audio Stability (Stuttering) | JavaScript | 2 | 1 | The buffer size is a setting of Initialize, its result surfaces through lastResult. |
| platforms-uwp | Background Music | C++ | 6 | 4 | The group and channel declarations fold into the var lines. |
| platforms-uwp | Pass Through | C++ | 6 | 4 | The group and channel declarations fold into the var lines. |
| platforms-win | ASIO and C# | C# | 5 | 1 | Initialize creates and initializes the system, the Main scaffold has no Haxe side. |
| platforms-win | Background Music | C++ | 6 | 4 | The group and channel declarations fold into the var lines. |
| platforms-win | Pass Through | C++ | 6 | 4 | The group and channel declarations fold into the var lines. |
| plugin-api-dsp | FMOD_DSP_PARAMETER_DESC | C# | 7 | 10 | The desc union is four nullable fields, one per parameter type. |
| plugin-api-dsp | FMOD_DSP_PARAMETER_FFT | C# | 7 | 5 | The two getSpectrum helpers are C# integration methods, the spectrum array is read directly. |
| plugin-api-output | FMOD_OUTPUT_METHOD | C/C++ | 2 | 4 | Two defines against an enum with its opening and closing lines. The header gives MIX_BUFFERED the value 1, the page shows 2. |
| running-the-core-api | 3.1 Initializing the Core API | text | 14 | 7 | Initialize creates and initializes the system in one call with one result check. |
| spatializing-sounds-in-the-core-api | 5.1 Controlling a Spatializer DSP | text | 79 | 26 | The site comments a 47-line maths library, the Haxe helpers are three short functions. |
| studio-api-eventdescription | FMOD_STUDIO_USER_PROPERTY | C# | 8 | 6 | The union is folded, floatValue carries integer and boolean properties (types.txt skip). |
| studio-api-eventinstance | FMOD_STUDIO_EVENT_CALLBACK | C# | 5 | 1 | The three delegate parameters arrive as one EventCallbackData (types.txt skip). |
| studio-api-getting-started | 12.1.1 Studio API Initialization | text | 15 | 7 | Initialize creates and initializes both systems in one call with one result check. |
| studio-api-system | FMOD_STUDIO_ADVANCEDSETTINGS | C# | 9 | 7 | cbsize and the encryption key are init-time only (types.txt skip). |
| studio-api-system | FMOD_STUDIO_BANK_INFO | C# | 9 | 5 | The four file callbacks run on FMOD's loading threads (types.txt skip). |
| studio-api-system | FMOD_STUDIO_CPU_USAGE | C# | 3 | 9 | FmodSystemCpuUsage carries the Core fields too, one struct for both getCPUUsage calls. |
| studio-api-system | FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT | C/C++ | 1 | 3 | One define against a class constant with its opening and closing lines. |
| studio-api-system | FMOD_STUDIO_LOAD_MEMORY_MODE#2 | JavaScript | 2 | 4 | Two JavaScript constants against an enum with its opening and closing lines. |
| studio-api-system | FMOD_STUDIO_SOUND_INFO | C# | 7 | 9 | name carries name_or_data and the exinfo fields are flattened into four fields (types.txt skip). |
| studio-api-system | FMOD_STUDIO_SYSTEM_CALLBACK | C# | 6 | 1 | The four delegate parameters arrive as one SystemEvent (types.txt skip). |
| studio-guide | 13.9.1 Scripting Example | C++ | 9 | 10 | A Haxe class needs a constructor line. |
| studio-guide | 13.9.1 Scripting Example#3 | C++ | 6 | 5 | loadBankFile returns the bank, no separate declaration. |
| using-dsp-effects-in-the-core-api | Add a DSP effect to a Channel | text | 5 | 3 | The two declarations fold into the var lines. |
| using-dsp-effects-in-the-core-api | Add an effect to the ChannelGroup | text | 3 | 2 | The declaration folds into the var line. |
| using-dsp-effects-in-the-core-api | Creating an effect and making all Channels send to it. | text | 7 | 4 | The three declarations fold into the var lines. |
| using-dsp-effects-in-the-core-api | Creating an effect and making all Channels send to it.#3 | text | 5 | 4 | The declaration folds into the var line. |
| using-dsp-effects-in-the-core-api | Controlling mix level and pan matrices for DSPConnections | text | 6 | 4 | The two declarations fold into the var lines. |
| using-dsp-effects-in-the-core-api | Set the output format of a DSP unit, and control the pan matrix for its output signal#2 | text | 10 | 9 | The connection declaration folds into the var line. |
| using-dsp-effects-in-the-core-api | 7.2.4 Multiple plug-ins within one file#2 | text | 11 | 8 | ERRCHECK lines on calls that return their value, and the plugin info is read in the line that declares the type. |
| welcome-whats-new-201 | Thread attributes | C++ | 3 | 5 | Thread attributes are a setting of Initialize, the array adds its opening and closing lines. |
| welcome-whats-new-201 | Thread attributes#2 | C++ | 2 | 4 | Thread attributes are a setting of Initialize, the array adds its opening and closing lines. |
