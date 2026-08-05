ARCHS = armv7 armv7s arm64 arm64e
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = locationfaker
locationfaker_FILES = Tweak.xm
locationfaker_FRAMEWORKS = CoreLocation UIKit
locationfaker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk