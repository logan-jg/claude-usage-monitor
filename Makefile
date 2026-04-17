APP_NAME := ClaudeUsageMonitor
BUILD    := build
BIN      := $(BUILD)/$(APP_NAME)
BUNDLE   := $(BUILD)/$(APP_NAME).app
CONTENTS := $(BUNDLE)/Contents
MACOS    := $(CONTENTS)/MacOS

SDK      := $(shell xcrun --show-sdk-path --sdk macosx)
TARGET   := arm64-apple-macosx14.0
SOURCES  := $(shell find Sources/$(APP_NAME) -name '*.swift')

SWIFTC_FLAGS := \
	-parse-as-library \
	-sdk $(SDK) \
	-target $(TARGET) \
	-O

DIST        := dist
VERSION     ?= 0.1.0
RELEASE_ZIP := $(DIST)/$(APP_NAME)-$(VERSION).zip

.PHONY: all build bundle run clean install release

all: bundle

$(BIN): $(SOURCES)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTC_FLAGS) -o $(BIN) $(SOURCES)

build: $(BIN)

bundle: $(BIN)
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(MACOS)" "$(CONTENTS)/Resources"
	@cp "$(BIN)" "$(MACOS)/$(APP_NAME)"
	@cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	@printf "APPL????" > "$(CONTENTS)/PkgInfo"
	@codesign --force --sign - --identifier com.logan.ClaudeUsageMonitor --deep "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

run: bundle
	@open "$(BUNDLE)"

clean:
	rm -rf $(BUILD)

install: bundle
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed to /Applications/$(APP_NAME).app"

# Ship a redistributable zip. `ditto` preserves the app bundle's code
# signature and extended attributes — plain `zip` would corrupt them and
# macOS would refuse to launch on another machine.
release: bundle
	@mkdir -p $(DIST)
	@rm -f $(RELEASE_ZIP)
	@/usr/bin/ditto -c -k --keepParent "$(BUNDLE)" "$(RELEASE_ZIP)"
	@echo "Created $(RELEASE_ZIP)"
	@shasum -a 256 "$(RELEASE_ZIP)"
