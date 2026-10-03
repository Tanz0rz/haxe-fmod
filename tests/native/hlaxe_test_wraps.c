/* Link wrappers for tests/ShimDropPoints.hx. The test hdll is
 * linked with -Wl,--wrap=FMOD_Sound_Release -Wl,--wrap=FMOD_System_RecordStop.
 * HLAXE_TEST_REFUSE_SOUND_RELEASE=1 refuses a sound release, and
 * HLAXE_TEST_ACCEPT_RECORD_STOP=1 accepts a record stop on a machine
 * with no record device. Every other call reaches FMOD. */
#include <stdlib.h>
#include "fmod.h"

static int test_flag(const char* name) {
    const char* value = getenv(name);
    return value && value[0] == '1';
}

FMOD_RESULT __real_FMOD_Sound_Release(FMOD_SOUND* sound);
FMOD_RESULT __wrap_FMOD_Sound_Release(FMOD_SOUND* sound) {
    if (test_flag("HLAXE_TEST_REFUSE_SOUND_RELEASE")) return FMOD_ERR_NOTREADY;
    return __real_FMOD_Sound_Release(sound);
}

FMOD_RESULT __real_FMOD_System_RecordStop(FMOD_SYSTEM* system, int id);
FMOD_RESULT __wrap_FMOD_System_RecordStop(FMOD_SYSTEM* system, int id) {
    if (test_flag("HLAXE_TEST_ACCEPT_RECORD_STOP")) return FMOD_OK;
    return __real_FMOD_System_RecordStop(system, id);
}
