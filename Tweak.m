//
//  Tweak.m
//  Raw Cydia Substrate version of the tweak.
//
//  This replaces Tweak.xm (which used Theos/Logos' `%hook` sugar) with
//  direct calls to CydiaSubstrate's MSHookMessageEx, so the project
//  builds as a plain Objective-C dylib without the Logos preprocessor
//  step. Behavior is identical to the original Tweak.xm.
//
//  IMPORTANT — READ BEFORE BUILDING
//  ---------------------------------
//  Agora's exact Objective-C method names for its audio-frame delegate
//  differ slightly between SDK versions (and some apps wrap the SDK in
//  their own classes). Before building, class-dump YOUR app's binary
//  and confirm:
//    1) The real class name that implements AgoraAudioFrameDelegate
//       (it might be AgoraRtcEngineKit itself, or a wrapper class your
//       own app defines).
//    2) The exact selector used for raw PCM frames, typically shaped
//       like -(BOOL)onRecordAudioFrame:(AgoraAudioFrame *)frame; or,
//       in newer SDKs, -(BOOL)onPlaybackAudioFrame:(AgoraAudioFrame *)frame;
//    3) The AgoraAudioFrame struct/class layout (buffer pointer, length,
//       sampleRate, channels) so ExtractPCMDataFromFrame() below gets
//       real bytes instead of returning nil.
//
//  Because this tweak only targets an app YOU own and control (set via
//  the `Filter` entry in `control`), you have legitimate access to
//  class-dump it yourself. Update the class name / selector constants
//  and ExtractPCMDataFromFrame() below to match what you find.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>   // CydiaSubstrate: MSHookMessageEx / MSFindSymbol
#import "AgoraRecorder.h"

// ---------------------------------------------------------------------
// Original-IMP storage. One static pointer per hooked selector so the
// replacement functions can still call through to Agora's real
// implementation (the equivalent of Logos' `%orig`).
// ---------------------------------------------------------------------

static BOOL (*orig_onRecordAudioFrame)(id self, SEL _cmd, id frame);

static void (*orig_didJoinChannel)(id self, SEL _cmd, id engine, NSString *channel, NSUInteger uid, NSInteger elapsed);

static void (*orig_didLeaveChannelWithStats)(id self, SEL _cmd, id engine, id stats);

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

// Placeholder: implement once you've confirmed the real AgoraAudioFrame
// layout for your SDK version via class-dump. Same contract as the
// `extractPCMDataFromFrame:` method in the original Tweak.xm.
static NSData * _Nullable ExtractPCMDataFromFrame(id frame) {
    // Replace this with real field access once you've confirmed
    // AgoraAudioFrame's layout via class-dump, e.g.:
    //   return [NSData dataWithBytes:frame.buffer length:frame.length];
    return nil;
}

// ---------------------------------------------------------------------
// Replacement implementations (equivalent to the %hook bodies).
// ---------------------------------------------------------------------

static BOOL replaced_onRecordAudioFrame(id self, SEL _cmd, id frame) {
    @try {
        if ([[AgoraRecorder sharedRecorder] isRecordingEnabled]) {
            NSData *pcm = ExtractPCMDataFromFrame(frame);
            if (pcm) {
                [[AgoraRecorder sharedRecorder] appendPCMData:pcm];
            }
        }
    } @catch (NSException *e) {
        // Never let a recording failure break the actual call.
    }
    return orig_onRecordAudioFrame(self, _cmd, frame);
}

static void replaced_didJoinChannel(id self, SEL _cmd, id engine, NSString *channel, NSUInteger uid, NSInteger elapsed) {
    orig_didJoinChannel(self, _cmd, engine, channel, uid, elapsed);
    [[AgoraRecorder sharedRecorder] startNewRecordingWithSampleRate:16000 channels:1];
}

static void replaced_didLeaveChannelWithStats(id self, SEL _cmd, id engine, id stats) {
    orig_didLeaveChannelWithStats(self, _cmd, engine, stats);
    [[AgoraRecorder sharedRecorder] finishRecording];
}

// ---------------------------------------------------------------------
// Entry point. Runs when the dylib is loaded into the target process
// (the `Filter` block in `control` is what restricts that to your own
// app's bundle ID — this file does not re-check the bundle ID itself,
// so keep that Filter in place).
// ---------------------------------------------------------------------

__attribute__((constructor))
static void AgoraRecorderTweakInit(void) {
    @autoreleasepool {
        Class targetClass = objc_getClass("AgoraRtcEngineKit");
        if (!targetClass) {
            // The class Agora's SDK links in under this name isn't loaded
            // yet (or your app wraps it under a different class name —
            // see the class-dump note at the top of this file).
            NSLog(@"[AgoraRecorder] AgoraRtcEngineKit not found; hooks not installed.");
            return;
        }

        SEL selRecordFrame = @selector(onRecordAudioFrame:);
        if ([targetClass instancesRespondToSelector:selRecordFrame]) {
            MSHookMessageEx(targetClass, selRecordFrame,
                             (IMP)replaced_onRecordAudioFrame,
                             (IMP *)&orig_onRecordAudioFrame);
        } else {
            NSLog(@"[AgoraRecorder] onRecordAudioFrame: not found on AgoraRtcEngineKit; "
                   "confirm the real selector name for your SDK version (see header comment).");
        }

        SEL selJoin = @selector(rtcEngine:didJoinChannel:withUid:elapsed:);
        if ([targetClass instancesRespondToSelector:selJoin]) {
            MSHookMessageEx(targetClass, selJoin,
                             (IMP)replaced_didJoinChannel,
                             (IMP *)&orig_didJoinChannel);
        }

        SEL selLeave = @selector(rtcEngine:didLeaveChannelWithStats:);
        if ([targetClass instancesRespondToSelector:selLeave]) {
            MSHookMessageEx(targetClass, selLeave,
                             (IMP)replaced_didLeaveChannelWithStats,
                             (IMP *)&orig_didLeaveChannelWithStats);
        }
    }
}
