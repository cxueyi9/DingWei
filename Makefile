ARCHS = arm64 arm64e
TARGET = iphone:clang:15.0:15.0      # 新增：最低部署目标 iOS 15.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = LocationFaker
locationfaker_FILES = Tweak.xm
locationfaker_FRAMEWORKS = CoreLocation UIKit
locationfaker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk