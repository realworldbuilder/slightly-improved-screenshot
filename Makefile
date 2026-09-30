APP      := SlightlyImprovedScreenshot
SCHEME   := $(APP)
BUNDLE   := com.williamhussey.$(APP)
DERIVED  := build
DEST     := $(HOME)/Applications

.PHONY: gen build test install run clean reset-tcc

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration Release \
	  -destination 'platform=macOS' -derivedDataPath $(DERIVED) build | tail -20

test: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) \
	  -destination 'platform=macOS' -derivedDataPath $(DERIVED) test | tail -40

install: build
	mkdir -p $(DEST)
	rm -rf "$(DEST)/$(APP).app"
	ditto "$(DERIVED)/Build/Products/Release/$(APP).app" "$(DEST)/$(APP).app"
	codesign --verify --deep --strict "$(DEST)/$(APP).app"

run: install
	pkill -x $(APP) || true
	open "$(DEST)/$(APP).app"

reset-tcc:
	tccutil reset ScreenCapture $(BUNDLE)

clean:
	rm -rf $(DERIVED) $(APP).xcodeproj
