APP_NAME = lidguard-helper
BUILD_DIR = .build/release
INSTALL_DIR = $(HOME)/Library/Application Support/LidGuard
PLIST_LABEL = com.lidguard.helper
PLIST_SRC = com.lidguard.helper.plist
PLIST_DST = $(HOME)/Library/LaunchAgents/$(PLIST_LABEL).plist
VERSION_FILE = VERSION
BUMP ?= patch
CODESIGN_ID ?= Developer ID Application: Andrey Kim (73R36N2A46)
CODESIGN_REQ ?= designated => anchor apple generic and certificate leaf[subject.OU] = "73R36N2A46"
NOTARIZE_PROFILE ?= Notarize

.PHONY: build run-debug install uninstall release lint clean version

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

# Release: bump version, build, codesign, notarize, commit, tag, push, create GH release
#   BUMP=minor make release   — bump minor
#   Requires RELEASE_NOTES.md (deleted after publish)
release:
	@test -f RELEASE_NOTES.md || (echo "Error: RELEASE_NOTES.md is required. Write release notes first." && exit 1)
	@$(MAKE) _bump
	@$(MAKE) build
	@$(MAKE) _sign
	@$(MAKE) _notarize
	@VERSION=$$(cat $(VERSION_FILE)); \
	TITLE="$${TITLE:-v$$VERSION}"; \
	git add $(VERSION_FILE) Sources/main.swift && \
	git commit -m "chore: bump version to $$VERSION" && \
	git tag "v$$VERSION" && \
	mkdir -p dist && \
	cp $(BUILD_DIR)/$(APP_NAME) dist/ && \
	cd dist && zip -r $(APP_NAME)-$$VERSION.zip $(APP_NAME) && cd .. && \
	git push origin main --tags && \
	gh release create "v$$VERSION" "dist/$(APP_NAME)-$$VERSION.zip" \
		--title "$$TITLE" --notes-file RELEASE_NOTES.md && \
	rm -f RELEASE_NOTES.md && \
	echo "Released v$$VERSION"

_sign:
	@echo "Signing $(APP_NAME)..."
	codesign --force --sign "$(CODESIGN_ID)" \
		-o runtime --timestamp \
		-r='$(CODESIGN_REQ)' \
		$(BUILD_DIR)/$(APP_NAME)
	@echo "Signed"

_notarize:
	@echo "Notarizing $(APP_NAME)..."
	@mkdir -p dist
	@cp $(BUILD_DIR)/$(APP_NAME) dist/
	@cd dist && zip -r $(APP_NAME)-notarize.zip $(APP_NAME) && cd ..
	@xcrun notarytool submit dist/$(APP_NAME)-notarize.zip \
		--keychain-profile "$(NOTARIZE_PROFILE)" --wait
	@rm -f dist/$(APP_NAME)-notarize.zip dist/$(APP_NAME)
	@echo "Notarization complete"

_bump:
	@VERSION=$$(cat $(VERSION_FILE)); \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	MINOR=$$(echo $$VERSION | cut -d. -f2); \
	PATCH=$$(echo $$VERSION | cut -d. -f3); \
	case "$(BUMP)" in \
		major) MAJOR=$$((MAJOR + 1)); MINOR=0; PATCH=0;; \
		minor) MINOR=$$((MINOR + 1)); PATCH=0;; \
		patch) PATCH=$$((PATCH + 1));; \
	esac; \
	NEW="$$MAJOR.$$MINOR.$$PATCH"; \
	echo "$$NEW" > $(VERSION_FILE); \
	sed -i '' "s/let helperVersion = \".*\"/let helperVersion = \"$$NEW\"/" Sources/main.swift; \
	echo "Version bumped to $$NEW"

lint:
	@TOOLCHAIN_DIR=$$(dirname "$$(dirname "$$(xcrun --find swiftc)")"); \
	DYLD_FRAMEWORK_PATH="$$TOOLCHAIN_DIR/lib" swiftlint lint --strict Sources/

clean:
	rm -rf .build dist

version:
	@cat $(VERSION_FILE)
