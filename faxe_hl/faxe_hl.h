/**
* Faxe - FMOD bindings for Haxe
*
* The MIT License (MIT)
*
* Copyright (c) 2016 Aaron M. Shea
* Copyright (c) 2020 Tanner Moore
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/
#pragma once

#define IMPLEMENT_API

#if (defined __MWERKS__)
#include <SIOUX.h>
#endif

#include <fmod_studio.hpp>
        //// FMOD System

        /**
		 * Turns on print statements for any errors happening within the FMOD integration
		 * \param[onOff] turns debug messages on or off
		 */
        HL_PRIM extern void HL_NAME(fmod_set_debug)(bool onOff);

        /**
		 * Only needed for the html5 API. Will always return true here
		 */
        HL_PRIM extern bool HL_NAME(fmod_is_initialized)();

        /**
		 * Initialization of FMOD sound system
		 * \param[numChannels] number of channels to allocate for this sound system
		 */
        HL_PRIM extern void HL_NAME(fmod_init)(int numChannels = 32);

        /**
		 * Update the FMOD command buffer, should be called once per "tick"
		 */
        HL_PRIM extern void HL_NAME(fmod_update)();

        /**
		 * Should be called by a background thread. Updates FMOD 60 times per second until a SIGTERM is received
		 */
        HL_PRIM extern void update_fmod_async();

        //// Sound Banks

        /**
		 * Load a FMOD sound bank file
		 * \param[bankName] ::String the file path of the sound bank to load
		 */
        HL_PRIM extern void HL_NAME(fmod_load_bank)(vbyte *bankName);

        /**
		 * Unload a FMOD sound bank file
		 * \param[bankName] ::String the file path of the sound bank to unload
		 */
        HL_PRIM extern void HL_NAME(fmod_unload_bank)(vbyte *bankName);

        //// Event Descriptions

        /**
		 * Load an event description from a loaded bank
		 * Event instances are spawned from event descriptions
		 * Event descriptions are loaded automatically when creating event instances
		 * \param[eventPath] ::String the path of the event
		 */
        HL_PRIM extern void HL_NAME(fmod_load_event_description)(vbyte *eventPath);

        /**
		 * Check if an event description is currently loaded
		 * \param[eventDescriptionName] ::String the event description to check
		 */
        HL_PRIM extern bool HL_NAME(fmod_is_event_description_loaded)(vbyte *eventDescriptionName);

        //// Events

        /**
		 * Create and play an event instance in a fire-and-forget fashion
		 * There is no way to interact with these events once they are started
		 * Follows the Master Track rules set in the Event's settings in FMOD Studio (Max Instances, Stealing, and probably more)
		 * \param[eventPath] ::String the bank path of the event
		 */
        HL_PRIM extern void HL_NAME(fmod_create_event_instance_one_shot)(vbyte *eventPath);

        /**
		 * Create and play an event instance and store a reference to it
		 * Events created with this method can receive other commands via this API (like passing in parameters)
		 * \param[eventPath] ::String the bank path of the event
		 * \param[eventInstanceName] ::String the name to assign to the new event instance
		 */
        HL_PRIM extern void HL_NAME(fmod_create_event_instance_named)(vbyte *eventPath, vbyte *eventInstanceName);

        /**
		 * Check if an event instance is currently loaded
		 * \param[eventInstanceName] ::String the event instance to check
		 */
        HL_PRIM extern bool HL_NAME(fmod_is_event_instance_loaded)(vbyte *eventInstanceName);

        /**
		 * Sends the "play" command to an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
        HL_PRIM extern void HL_NAME(fmod_play_event_instance)(vbyte *eventInstanceName);

        /**
		 * Sends the "pause" or "unpause" command to an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 * \param[shouldBePaused] bool if the event instance should be paused
		 */
        HL_PRIM extern void HL_NAME(fmod_set_pause_on_event_instance)(vbyte *eventInstanceName, bool shouldBePaused);

        /**
		 * Sends the "stop" command to an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
        HL_PRIM extern void HL_NAME(fmod_stop_event_instance)(vbyte *eventInstanceName);

        /**
		 * Immediately stops an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
        HL_PRIM extern void HL_NAME(fmod_stop_event_instance_immediately)(vbyte *eventInstanceName);

        /**
		 * Release a loaded event instance from memory
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
        HL_PRIM extern void HL_NAME(fmod_release_event_instance)(vbyte *eventInstanceName);

        /**
		 * Check to see if an event instance is currently playing
		 * \param[eventInstanceName] ::String the name of the event instance
		 * \return ::Bool if the event is currently playing
		 */
        HL_PRIM extern bool HL_NAME(fmod_is_event_instance_playing)(vbyte *eventInstanceName);

        /**
		 * Get the playback state of an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
        HL_PRIM extern FMOD_STUDIO_PLAYBACK_STATE HL_NAME(fmod_get_event_instance_playback_state)(vbyte *eventInstanceName);

        /**
		 * Check to see if an event is currently playing
		 * \param[eventInstanceName] ::String the name of the event to get param value from
		 * \param[paramName] ::String the name of the param to GET
		 * \return float the current value of the param from the specified event
		 */
        HL_PRIM extern float HL_NAME(fmod_get_event_instance_param)(vbyte *eventInstanceName, vbyte *paramName);

        /**
		 * Set the parameter value of a loaded event
		 * \param[eventInstanceName] ::String the name of the event that contains the parameter to set
		 * \param[paramName] ::String the name of the param to SET
		 * \param[value] float the new value to set the param to
		 */
        HL_PRIM extern void HL_NAME(fmod_set_event_instance_param)(vbyte *eventInstanceName, vbyte *paramName, float value);

        //// Callbacks

        /**
		 * Tracks playback callback events for a given event instance
		 * Callbacks can be checked with fmod_check_callbacks_for_event_instance
		 * \param[eventInstanceName] ::String the name of the loaded event instance to track
		 * \see https://tanneris.me/FMOD-Callback-Types
		 */
        HL_PRIM extern void HL_NAME(fmod_set_callback_tracking_for_event_instance)(vbyte *eventInstanceName);

        /**
		 * Can only be used after assigning the event listener to an event instance
		 * Checks for any FMOD_STUDIO_EVENT_CALLBACK_TYPE callbacks to have occured on the primary event instance
		 * Once a callback value specifiied by mask is read, that specific callback value is reset to 0
		 * \param[eventInstanceName] ::String the name of the registered event instance to check
		 * \param[callbackEventMask] ::unsigned int the bitmask that corresponds to the underlying callback type you want to check
		 * \see https://tanneris.me/FMOD-Callback-Types
		 */
        HL_PRIM extern bool HL_NAME(fmod_check_callbacks_for_event_instance)(vbyte *eventInstanceName, unsigned int callbackEventMask);