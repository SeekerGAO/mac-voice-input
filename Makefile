APP_NAME := MacVoiceInput
BUILD_DIR := .build
CONFIG ?= release
APP_DIR := $(BUILD_DIR)/$(CONFIG)/$(APP_NAME).app
EXECUTABLE := $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)
ICON_FILE := AppBundle/AppIcon.icns

.PHONY: build run install clean icon

build: icon
	swift build -c $(CONFIG)
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp AppBundle/Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp "$(ICON_FILE)" "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	cp "$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	codesign --force --sign - "$(APP_DIR)"

icon:
	swift Tools/generate_icon.swift

run: build
	open "$(APP_DIR)"

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_DIR)" "/Applications/$(APP_NAME).app"
	codesign --force --sign - "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)"
