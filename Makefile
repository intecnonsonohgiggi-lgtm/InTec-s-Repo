THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:15.6:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SiriAIOverhaul
SiriAIOverhaul_FILES = Tweak.x
SiriAIOverhaul_FRAMEWORKS = UIKit Foundation AVFoundation Speech AudioToolbox QuartzCore
SiriAIOverhaul_CFLAGS = -Os -fobjc-arc -DNDEBUG -Wno-unused-variable -Wno-deprecated-declarations
SiriAIOverhaul_INSTALL_TARGET_PROCESSES = SpringBoard assistantd

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = SiriAIOverhaulPrefs
SiriAIOverhaulPrefs_FILES = SiriAIOverhaulPrefs/SAPRootListController.m
SiriAIOverhaulPrefs_INSTALL_PATH = /Library/PreferenceBundles
SiriAIOverhaulPrefs_FRAMEWORKS = UIKit Foundation
SiriAIOverhaulPrefs_PRIVATE_FRAMEWORKS = Preferences
SiriAIOverhaulPrefs_CFLAGS = -Os -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard || true"
