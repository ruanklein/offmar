.DEFAULT_GOAL := all

CONFIGURATION ?= Debug
BUILD_DIR := build
APP_PATH := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/OffMar.app

.PHONY: all build install uninstall clean test

all: build
	open "$(APP_PATH)"

build:
	xcodegen generate
	xcodebuild -quiet -project OffMar.xcodeproj -scheme OffMar -configuration "$(CONFIGURATION)" -derivedDataPath "$(BUILD_DIR)" build

install: build
	ditto "$(APP_PATH)" "/Applications/OffMar.app"

uninstall:
	rm -rf "/Applications/OffMar.app"

clean:
	rm -rf "$(BUILD_DIR)"

test:
	xcodegen generate
	xcodebuild -quiet -project OffMar.xcodeproj -scheme OffMar -configuration "$(CONFIGURATION)" -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(BUILD_DIR)" test
