# Stretchu: build, app assembly, installation.
# Needs Xcode installed (SwiftUI's @State macro plugin ships with it, not with the Command Line Tools).

APP_NAME  := Stretchu
BUILD_DIR := build
APP       := $(BUILD_DIR)/$(APP_NAME).app
INSTALLED := /Applications/$(APP_NAME).app
SUPPORT   := $(HOME)/Library/Application Support/Stretchu

.PHONY: check-xcode build run debug demo test app install uninstall clean sprites

# Debug mode only exists in development builds (compiled with -DSTRETCHU_DEBUG):
# `make install` never includes it. `make debug` and `make demo` build it apart,
# in .build-debug, so the two kinds of build never overwrite each other.
DEBUG_FLAGS := -Xswiftc -DSTRETCHU_DEBUG
DEBUG_APP   := $(BUILD_DIR)/debug/$(APP_NAME).app

ifdef DEBUG_BUILD
  SWIFT_FLAGS := $(DEBUG_FLAGS)
  SCRATCH     := .build-debug
  APP         := $(DEBUG_APP)
else
  SWIFT_FLAGS :=
  SCRATCH     := .build
endif
BIN_PATH = $$(swift build -c release $(SWIFT_FLAGS) --scratch-path $(SCRATCH) --show-bin-path)

# The Pokémon sprites are not in the repository: they are downloaded at build time
# (scripts/fetch-sprites.sh). `make install` fetches them when they are missing or when
# Resources/lines.json (which pins the SpriteCollab commit) changed; `make sprites` forces it.
sprites:
	scripts/fetch-sprites.sh

Resources/Sprites/.fetched: Resources/lines.json scripts/fetch-sprites.swift
	scripts/fetch-sprites.sh

check-xcode:
	@test -e "$$(xcode-select -p)/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib" || { \
	  echo "error: SwiftUIMacros plugin not found in $$(xcode-select -p)."; \
	  echo "fix: install Xcode, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; \
	  exit 1; }

build: check-xcode
	swift build -c release $(SWIFT_FLAGS) --scratch-path $(SCRATCH)

run:
	swift run $(APP_NAME)

# Launches a development build directly in Debug mode (also reachable from the menu:
# "Debug", or ⌥ click on the icon). Debug works in state.debug.json, never in state.json.
debug:
	@$(MAKE) --no-print-directory app DEBUG_BUILD=1
	-@pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	@rm -f "$(SUPPORT)/state.debug.json"
	open -n --env STRETCHU_DEBUG=1 "$(DEBUG_APP)"

# make demo STATE=pichu-lv1: drops the scenario in state.debug.json, then launches in Debug.
# Your real state (state.json) is not touched. Add LANGUAGE=fr or LANGUAGE=en to force the interface language.
demo:
	@test -n "$(STATE)" || { echo "Usage: make demo STATE=<name> (see Tests/Fixtures/)"; exit 1; }
	@test -f "Tests/Fixtures/$(STATE).json" || { echo "Unknown state: $(STATE)"; ls Tests/Fixtures | sed 's/\.json$$//'; exit 1; }
	@$(MAKE) --no-print-directory app DEBUG_BUILD=1
	-@pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	@mkdir -p "$(SUPPORT)"
	@cp "Tests/Fixtures/$(STATE).json" "$(SUPPORT)/state.debug.json"
	open -n --env STRETCHU_DEBUG=1 $(if $(LANGUAGE),--env STRETCHU_LANGUAGE=$(LANGUAGE)) "$(DEBUG_APP)"

# Both configurations: the release one, and the one with the Debug code.
test:
	swift test
	swift test $(DEBUG_FLAGS) --scratch-path .build-debug

app: build Resources/Sprites/.fetched
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BIN_PATH)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp -R "$(BIN_PATH)/$(APP_NAME)_$(APP_NAME).bundle" "$(APP)/Contents/Resources/"
	cp Info.plist "$(APP)/Contents/Info.plist"
	cp -R Resources/ "$(APP)/Contents/Resources/"
	codesign --force --deep -s - "$(APP)"

install: app
	-@pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	rm -rf "$(INSTALLED)"
	cp -R "$(APP)" "$(INSTALLED)"
	open "$(INSTALLED)"

uninstall:
	-@pkill -x $(APP_NAME) 2>/dev/null
	rm -rf "$(INSTALLED)"

clean:
	rm -rf .build .build-debug $(BUILD_DIR)
