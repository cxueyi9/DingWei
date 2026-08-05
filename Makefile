ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:15.0    # SDK 16.5，最低要求 iOS 15.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = locationfaker
locationfaker_FILES = Tweak.xm
locationfaker_FRAMEWORKS = CoreLocation UIKit
locationfaker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk