.DEFAULT_GOAL := all

CONFIGURATION ?= Debug
BUILD_DIR := build
APP_PATH := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/OffMar.app

.PHONY: all build test

all: build
	open "$(APP_PATH)"

build:
	xcodegen generate
	xcodebuild -quiet -project OffMar.xcodeproj -scheme OffMar -configuration "$(CONFIGURATION)" -derivedDataPath "$(BUILD_DIR)" build

test:
	xcodegen generate
	xcodebuild -quiet -project OffMar.xcodeproj -scheme OffMar -configuration "$(CONFIGURATION)" -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(BUILD_DIR)" test
