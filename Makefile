APP_NAME = Notchy
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build run clean debug

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	codesign --force --sign - "$(APP_BUNDLE)"

debug:
	swift build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp ".build/debug/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	codesign --force --sign - "$(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

run-debug: debug
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
