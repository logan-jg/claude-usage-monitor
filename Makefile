APP_NAME := ClaudeUsageMonitor
BUILD    := build
BIN      := $(BUILD)/$(APP_NAME)
BUNDLE   := $(BUILD)/$(APP_NAME).app
CONTENTS := $(BUNDLE)/Contents
MACOS    := $(CONTENTS)/MacOS
FRAMEWORKS := $(CONTENTS)/Frameworks

SDK      := $(shell xcrun --show-sdk-path --sdk macosx)
TARGET   := arm64-apple-macosx14.0
SOURCES  := $(shell find Sources/$(APP_NAME) -name '*.swift')

VENDOR_DIR        := Vendor
SPARKLE_FRAMEWORK := $(VENDOR_DIR)/Sparkle.framework
SPARKLE_SIGN      := $(VENDOR_DIR)/bin/sign_update

SWIFTC_FLAGS := \
	-parse-as-library \
	-sdk $(SDK) \
	-target $(TARGET) \
	-O \
	-F $(VENDOR_DIR) \
	-framework Sparkle \
	-Xlinker -rpath -Xlinker @executable_path/../Frameworks

DIST        := dist
VERSION     ?= 0.3.0
RELEASE_ZIP := $(DIST)/$(APP_NAME)-$(VERSION).zip
LATEST_ZIP  := $(DIST)/$(APP_NAME).zip

.PHONY: all build bundle run clean install release sign-release appcast

all: bundle

$(BIN): $(SOURCES)
	@mkdir -p $(BUILD)
	swiftc $(SWIFTC_FLAGS) -o $(BIN) $(SOURCES)

build: $(BIN)

bundle: $(BIN)
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(MACOS)" "$(CONTENTS)/Resources" "$(FRAMEWORKS)"
	@cp "$(BIN)" "$(MACOS)/$(APP_NAME)"
	@cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	@printf "APPL????" > "$(CONTENTS)/PkgInfo"
	@cp -R "$(SPARKLE_FRAMEWORK)" "$(FRAMEWORKS)/"
	@codesign --force --deep --sign - --identifier com.logan.ClaudeUsageMonitor "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

run: bundle
	@open "$(BUNDLE)"

clean:
	rm -rf $(BUILD)

install: bundle
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Installed to /Applications/$(APP_NAME).app"

# Redistributable zip. `ditto` preserves code signature + extended attributes.
# Also emits an un-versioned copy so the download URL can be stable:
#   https://github.com/<org>/<repo>/releases/latest/download/ClaudeUsageMonitor.zip
release: bundle
	@mkdir -p $(DIST)
	@rm -f $(RELEASE_ZIP) $(LATEST_ZIP)
	@/usr/bin/ditto -c -k --keepParent "$(BUNDLE)" "$(RELEASE_ZIP)"
	@/usr/bin/ditto -c -k --keepParent "$(BUNDLE)" "$(LATEST_ZIP)"
	@echo "Created $(RELEASE_ZIP) and $(LATEST_ZIP)"
	@shasum -a 256 "$(RELEASE_ZIP)"

# Sign the release zip with the EdDSA private key stored in this Mac's Keychain
# (generated once via Vendor/bin/generate_keys). Prints the sparkle:edSignature
# and length attributes that need to go into appcast.xml's <enclosure> element.
sign-release:
	@echo "Signing $(RELEASE_ZIP) with EdDSA key..."
	@$(SPARKLE_SIGN) "$(RELEASE_ZIP)"

# Regenerate appcast.xml from the existing GitHub releases. Expects
# Vendor/bin/generate_appcast to have access to the signing key.
appcast:
	@$(VENDOR_DIR)/bin/generate_appcast $(DIST) -o appcast.xml
	@echo "Wrote appcast.xml"
