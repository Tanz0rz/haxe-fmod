# platforms-ios

## Handling Interruptions
kind: example
index: 0
heading: Handling Interruptions

### objective-c
```text
void Common_DefaultSuspendCallback(bool suspend)

void (*gSuspendCallback)(bool suspend) = &Common_DefaultSuspendCallback;
bool gIsSuspended = false;
bool gNeedsReset = false;

void Common_DefaultSuspendCallback(bool suspend)
{
    NSLog(@"Common_DefaultSuspendCallback(%s)\n", suspend ? "true" : "false");
}

/*
    Pass a function pointer to a function handling suspend/resume from your own code to Common_RegisterSuspendCallback
*/
void Common_RegisterSuspendCallback(void (*callback)(bool))
{
    gSuspendCallback = callback ? callback : &Common_DefaultSuspendCallback;
}

/*
    Set up some observers for various notifications
*/
[[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil usingBlock:^(NSNotification *notification)
{
    AVAudioSessionInterruptionType type = (AVAudioSessionInterruptionType)[[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan)
    {
        NSLog(@"Interruption Began");
        // Ignore deprecated warnings regarding AVAudioSessionInterruptionReasonAppWasSuspended and
        // AVAudioSessionInterruptionWasSuspendedKey, we protect usage for the versions where they are available
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"

        // If the audio session was deactivated while the app was in the background, the app receives the
        // notification when relaunched. Identify this reason for interruption and ignore it.
        if (@available(iOS 16.0, tvOS 14.5, *))
        {
            // Delayed suspend-in-background notifications no longer exist, this must be a real interruption
        }
        #if !TARGET_OS_TV // tvOS never supported "AVAudioSessionInterruptionReasonAppWasSuspended"
        else if (@available(iOS 14.5, *))
        {
            if ([[notification.userInfo valueForKey:AVAudioSessionInterruptionReasonKey] intValue] == AVAudioSessionInterruptionReasonAppWasSuspended)
            {
                NSLog(@"Ignoring delayed AVAudioSessionInterruptionNotification");
                return; // Ignore delayed suspend-in-background notification
            }
        }
        #endif
        else
        {
            if ([[notification.userInfo valueForKey:AVAudioSessionInterruptionWasSuspendedKey] boolValue])
            {
                NSLog(@"Ignoring delayed AVAudioSessionInterruptionNotification");
                return; // Ignore delayed suspend-in-background notification
            }
        }

        gSuspendCallback(true);
        gIsSuspended = true;

        #pragma clang diagnostic pop
    }
    else if (type == AVAudioSessionInterruptionTypeEnded)
    {
        NSLog(@"Interruption Ended");
        NSError *errorMessage = nullptr;
        if (![[AVAudioSession sharedInstance] setActive:TRUE error:&errorMessage])
        {
            // Interruption like Siri can prevent session activation, wait for did-become-active notification
            NSLog(@"AVAudioSessionInterruptionNotification: AVAudioSession.setActive() failed: %@", errorMessage);
            return;
        }

        gSuspendCallback(false);
        gIsSuspended = false;
    }
}];

[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *notification)
{
    NSLog(@"Application did become active");

    if (gNeedsReset)
    {
        gSuspendCallback(true);
        gIsSuspended = true;
    }

    NSError *errorMessage = nullptr;
    if (![[AVAudioSession sharedInstance] setActive:TRUE error:&errorMessage])
    {
        if ([errorMessage code] == AVAudioSessionErrorCodeCannotStartPlaying)
        {
            // Interruption like Screen Time can prevent session activation, but will not trigger an interruption-ended notification.
            // There is no other callback or trigger to hook into after this point, we are not in the background and there is no other audio playing.
            // Our only option is to have a sleep loop until the Audio Session can be activated again.
            while (![[AVAudioSession sharedInstance] setActive:TRUE error:nil])
            {
                usleep(20000);
            }
        }
        else
        {
            // Interruption like Siri can prevent session activation, wait for interruption-ended notification.
            NSLog(@"UIApplicationDidBecomeActiveNotification: AVAudioSession.setActive() failed: %@", errorMessage);
            return;
        }
    }

    // It's possible the system missed sending us an interruption end, so recover here
    if (gIsSuspended)
    {
        gSuspendCallback(false);
        gNeedsReset = false;
        gIsSuspended = false;
    }
}];

[[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:nil queue:nil usingBlock:^(NSNotification *notification)
{
    NSLog(@"Media services were reset");
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground || gIsSuspended)
    {
        // Received the reset notification while in the background, need to reset the AudioUnit when we come back to foreground.
        gNeedsReset = true;
    }
    else
    {
        // In the foregound but something chopped the media services, need to do a reset.
        gSuspendCallback(true);
        gSuspendCallback(false);
    }
}];
```

## Latency
kind: example
index: 1
heading: Latency

### objective-c
```text
AVAudioSession *session = [AVAudioSession sharedInstance];
double rate = 24000.0; // This should match System::setSoftwareFormat 'samplerate' which defaults to 24000
int blockSize = 512; // This should match System::setDSPBufferSize 'bufferlength' which defaults to 512

BOOL success = [session setPreferredSampleRate:rate error:nil];
assert(success);

success = [session setPreferredIOBufferDuration:blockSize / rate error:nil];
assert(success);

success = [session setActive:TRUE error:nil];
assert(success);
```

## Multi-channel Output
kind: example
index: 2
heading: Multi-channel Output

### objective-c
```text
AVAudioSession *session = [AVAudioSession sharedInstance];
long maxChannels = [session maximumOutputNumberOfChannels];

BOOL success = [session setPreferredOutputNumberOfChannels:maxChannels error:nil];
assert(success);

success = [session setActive:TRUE error:nil];
assert(success);
```

