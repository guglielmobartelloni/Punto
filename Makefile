# Keep the bundle path and signing identity stable; display name is Punto.
APP := build/PadMac.app
CC := clang
SWIFTC := swiftc
ARCH := $(shell uname -m)
TARGET := $(ARCH)-apple-macos12.0
SIGN_IDENTITY := PadMac Local Development
CFLAGS := -Wall -Wextra -Werror -O2 -mmacosx-version-min=12.0
FRAMEWORKS := -framework Cocoa -framework SwiftUI -framework ApplicationServices -framework IOKit -framework UniformTypeIdentifiers

.PHONY: all run clean test test-dock test-launcher-ui
all: $(APP)/Contents/MacOS/PadMac

build/launcher.o: launcher.c launcher.h
	mkdir -p build
	$(CC) $(CFLAGS) -c launcher.c -o $@

build/longpress.o: longpress.c longpress.h
	mkdir -p build
	$(CC) $(CFLAGS) -c longpress.c -o $@

build/keyboard.o: keyboard.c keyboard.h
	mkdir -p build
	$(CC) $(CFLAGS) -c keyboard.c -o $@

build/input.o: input.c input.h keyboard.h
	mkdir -p build
	$(CC) $(CFLAGS) -c input.c -o $@

build/AppIcon.icns: scripts/generate-brand-icon.swift
	mkdir -p build
	swift scripts/generate-brand-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o $@

build/UI.o: UI.swift LauncherUI.swift UIController.h Makefile
	mkdir -p build
	$(SWIFTC) -target $(TARGET) -O -whole-module-optimization -parse-as-library -module-name PadMacUI -import-objc-header UIController.h -emit-objc-header -emit-objc-header-path build/PadMacUI-Swift.h -emit-object UI.swift LauncherUI.swift -o $@

build/main.o: main.m input.h keyboard.h longpress.h launcher.h UIController.h ShortcutRecorder.h build/UI.o
	$(CC) $(CFLAGS) -fobjc-arc -c main.m -o $@

build/ShortcutRecorder.o: ShortcutRecorder.m ShortcutRecorder.h
	mkdir -p build
	$(CC) $(CFLAGS) -fobjc-arc -c ShortcutRecorder.m -o $@

$(APP)/Contents/MacOS/PadMac: build/main.o build/UI.o build/ShortcutRecorder.o build/input.o build/keyboard.o build/longpress.o build/launcher.o build/AppIcon.icns Info.plist Makefile
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	$(SWIFTC) -target $(TARGET) build/main.o build/UI.o build/ShortcutRecorder.o build/input.o build/keyboard.o build/longpress.o build/launcher.o $(FRAMEWORKS) -o $@
	cp Info.plist $(APP)/Contents/Info.plist
	cp build/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign "$(SIGN_IDENTITY)" --identifier local.padmac.controller -r='designated => identifier "local.padmac.controller" and certificate leaf = H"22A376841C86C728ED146E0C23D8264596FC4513"' $(APP)

run: all
	open $(APP)

test:
	mkdir -p build
	$(CC) $(CFLAGS) tests/buttons.c keyboard.c -framework ApplicationServices -framework IOKit -o build/test-buttons
	./build/test-buttons
	$(CC) $(CFLAGS) -fobjc-arc tests/shortcuts.m ShortcutRecorder.m -framework Cocoa -o build/test-shortcuts
	./build/test-shortcuts
	$(CC) $(CFLAGS) tests/keyboard.c -framework ApplicationServices -framework IOKit -o build/test-keyboard
	./build/test-keyboard
	$(CC) $(CFLAGS) tests/longpress.c longpress.c -o build/test-longpress
	./build/test-longpress
	$(CC) $(CFLAGS) tests/launcher.c launcher.c -o build/test-launcher
	./build/test-launcher
	$(CC) $(CFLAGS) tests/scroll.c keyboard.c -framework ApplicationServices -framework IOKit -o build/test-scroll
	./build/test-scroll

test-dock: build/UI.o build/ShortcutRecorder.o build/input.o build/keyboard.o build/longpress.o build/launcher.o
	$(CC) $(CFLAGS) -fobjc-arc -c tests/dock.m -o build/test-dock.o
	$(SWIFTC) -target $(TARGET) build/test-dock.o build/UI.o build/ShortcutRecorder.o build/input.o build/keyboard.o build/longpress.o build/launcher.o $(FRAMEWORKS) -o build/test-dock
	./build/test-dock

test-launcher-ui: build/UI.o build/ShortcutRecorder.o build/input.o build/keyboard.o build/longpress.o build/launcher.o
	$(CC) $(CFLAGS) -fobjc-arc -c tests/launcher-ui.m -o build/test-launcher-ui.o
	$(SWIFTC) -target $(TARGET) build/test-launcher-ui.o build/UI.o build/ShortcutRecorder.o build/input.o build/keyboard.o build/longpress.o build/launcher.o $(FRAMEWORKS) -o build/test-launcher-ui
	./build/test-launcher-ui

clean:
	rm -rf build
