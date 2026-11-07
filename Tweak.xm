#import "AgoraRecorder.h"

/*
 * IMPORTANT — READ BEFORE BUILDING
 * ---------------------------------
 * Agora's exact Objective-C method names for its audio-frame delegate
 * differ slightly between SDK versions (and some apps wrap the SDK in
 * their own classes). Before building, class-dump YOUR app's binary and
 * confirm:
 *   1) The real class name that implements AgoraAudioFrameDelegate
 *      (it might be AgoraRtcEngineKit itself, or a wrapper class your
 *      own app defines).
 *   2) The exact selector used for raw PCM frames, typically something
 *      shaped like:
 *        -(BOOL)onRecordAudioFrame:(AgoraAudioFrame *)frame;
 *      or, in newer SDKs:
 *        -(BOOL)onPlaybackAudioFrame:(AgoraAudioFrame *)frame;
 *   3) The AgoraAudioFrame struct/class layout (buffer pointer, length,
 *      sampleRate, channels fields) so appendPCMData: gets real bytes.
 *
 * Because this tweak only targets an app YOU own and control (set via
 * the `Filter` entry you add to `control`), you have legitimate access
 * to class-dump it yourself. The hook below assumes the common shape;
 * adjust the selector name/signature to match what you find.
 */

%hook AgoraRtcEngineKit

// Called by Agora's SDK when it hands your app's delegate a raw audio
// frame that was captured locally (i.e. this device's own microphone
// input during the call). We record it locally, then pass the frame
// through unchanged so the host app's own behavior is untouched.
- (BOOL)onRecordAudioFrame:(id)frame {
    @try {
        if ([[AgoraRecorder sharedRecorder] isRecordingEnabled]) {
            // Replace this with real field access once you've confirmed
            // AgoraAudioFrame's layout via class-dump, e.g.:
            //   NSData *pcm = [NSData dataWithBytes:frame.buffer length:frame.length];
            NSData *pcm = [self extractPCMDataFromFrame:frame];
            if (pcm) {
                [[AgoraRecorder sharedRecorder] appendPCMData:pcm];
            }
        }
    } @catch (NSException *e) {
        // Never let a recording failure break the actual call.
    }
    return %orig;
}

%new
- (NSData *)extractPCMDataFromFrame:(id)frame {
    // Placeholder: implement once you've confirmed the real AgoraAudioFrame
    // layout for your SDK version via class-dump.
    return nil;
}

%end

// Hook whatever call-lifecycle delegate callback your app uses to know
// a call has started/ended, so we can open/close the WAV file cleanly.
// AgoraRtcEngineDelegate's join/leave-channel callbacks are a common fit —
// confirm the exact selector names for your SDK version.
%hook AgoraRtcEngineKit

- (void)rtcEngine:(id)engine didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    %orig;
    [[AgoraRecorder sharedRecorder] startNewRecordingWithSampleRate:16000 channels:1];
}

- (void)rtcEngine:(id)engine didLeaveChannelWithStats:(id)stats {
    %orig;
    [[AgoraRecorder sharedRecorder] finishRecording];
}

%end
