# fsbank-api

## *
<!-- page default -->
FSBank is FMOD's offline encoding library for producing FSB files from source audio, and it is a separate native library rather than part of the runtime engine. haxefmod does not bind it.
Build your banks in FMOD Studio (or with its command line build) and load them with StudioSystem.loadBank. An FSB that already exists loads through Sound.create like any other file. See docs/guides/banks-and-settings.md.
