ARCHS = arm64
TARGET := iphone:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DeArrow-iOS

DeArrow-iOS_FILES = Tweak.xm PXLDeArrow.m PXLDeArrowBranding.m
DeArrow-iOS_CFLAGS = -Wno-deprecated-declarations -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
