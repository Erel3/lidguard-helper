APP_NAME = lidguard-helper
BUILD_DIR = .build/release
INSTALL_DIR = $(HOME)/Library/Application Support/LidGuard
PLIST_LABEL = com.lidguard.helper
PLIST_SRC = com.lidguard.helper.plist
PLIST_DST = $(HOME)/Library/LaunchAgents/$(PLIST_LABEL).plist
VERSION_FILE = VERSION

.PHONY: build run-debug install uninstall lint clean version

VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "1.0.0")

build:
	swift build -c release

run-debug:
	swift build && .build/debug/$(APP_NAME)

install: build
	@echo "Installing $(APP_NAME) v$(VERSION)"
	@mkdir -p "$(INSTALL_DIR)"
	@cp $(BUILD_DIR)/$(APP_NAME) "$(INSTALL_DIR)/"
	@sed 's|INSTALL_PATH|$(INSTALL_DIR)|g' $(PLIST_SRC) > "$(PLIST_DST)"
	@launchctl bootout gui/$$(id -u) "$(PLIST_DST)" 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) "$(PLIST_DST)"
	@echo "Installed and loaded $(PLIST_LABEL)"

uninstall:
	@launchctl bootout gui/$$(id -u) "$(PLIST_DST)" 2>/dev/null || true
	@rm -f "$(PLIST_DST)"
	@rm -f "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Uninstalled $(APP_NAME)"

lint:
	@TOOLCHAIN_DIR=$$(dirname "$$(dirname "$$(xcrun --find swiftc)")"); \
	DYLD_FRAMEWORK_PATH="$$TOOLCHAIN_DIR/lib" swiftlint lint --strict Sources/

clean:
	rm -rf .build

version:
	@cat $(VERSION_FILE)
