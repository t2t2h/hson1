ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_DEVICE_IP = 

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AgoraRecorder

# Tweak.m is a plain Objective-C file that hooks AgoraRtcEngineKit
# directly via CydiaSubstrate's MSHookMessageEx (no Logos/%hook sugar),
# so the build below produces a straight Substrate dylib.
AgoraRecorder_FILES = Tweak.m AgoraRecorder.m RecordingsListController.m
AgoraRecorder_CFLAGS = -fobjc-arc
AgoraRecorder_FRAMEWORKS = UIKit AVFoundation Foundation
AgoraRecorder_LIBRARIES = substrate
# If you link against Agora's real framework headers for stronger typing,
# add it here, e.g.:
# AgoraRecorder_FRAMEWORKS += AgoraRtcKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += agorarecorderprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
