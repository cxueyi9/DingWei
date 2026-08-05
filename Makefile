ARCHS = armv7 armv7s arm64 arm64e
TARGET = iphone:13.0                    # 只设置最低部署版本，不指定 SDK 版本
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = locationfaker
locationfaker_FILES = Tweak.xm
locationfaker_FRAMEWORKS = CoreLocation UIKit
locationfaker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk