APP      := SlightlyImprovedScreenshot
SCHEME   := $(APP)
BUNDLE   := com.williamhussey.$(APP)
DERIVED  := build
DEST     := $(HOME)/Applications

.PHONY: gen build test stop install run release clean reset-tcc

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration Release \
	  -destination 'platform=macOS' -derivedDataPath $(DERIVED) build | tail -20

test: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) \
	  -destination 'platform=macOS' -derivedDataPath $(DERIVED) test | tail -40

stop:
	-pkill -x $(APP)
	while pgrep -x $(APP) >/dev/null; do sleep 0.2; done

install: build stop
	mkdir -p $(DEST)
	rm -rf "$(DEST)/$(APP).app"
	ditto "$(DERIVED)/Build/Products/Release/$(APP).app" "$(DEST)/$(APP).app"
	codesign --verify --deep --strict "$(DEST)/$(APP).app"

run: install
	open "$(DEST)/$(APP).app" || (sleep 2 && open "$(DEST)/$(APP).app")

# Ad-hoc signed zip for GitHub Releases, so it runs on Macs without this team's certificate.
release: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration Release \
	  -destination 'generic/platform=macOS' -derivedDataPath $(DERIVED)/release \
	  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build | tail -5
	codesign --verify --deep --strict "$(DERIVED)/release/Build/Products/Release/$(APP).app"
	ditto -c -k --keepParent "$(DERIVED)/release/Build/Products/Release/$(APP).app" "$(DERIVED)/$(APP).zip"
	@echo "$(DERIVED)/$(APP).zip"

reset-tcc:
	tccutil reset ScreenCapture $(BUNDLE)

clean:
	rm -rf $(DERIVED) $(APP).xcodeproj
