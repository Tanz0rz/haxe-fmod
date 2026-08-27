# Compat fixture banks

Banks for the FMOD 2.02.33 compat jobs. FMOD Studio builds bank files that only load on a runtime at least as new as the Studio version, and the example project's live banks are built with Studio 2.03.12. The compat jobs swap these older banks into the example project before building so the game still produces audio on 2.02.33. The files are the project's banks as they were before the 2026-08-27 authoring round.

The set has no Extras.bank. Nothing misses it today because the compat jobs build without -Daudio_test and the demo only plays Master events, but a compat run of bank-test or pan-test would fail on the missing bank.
