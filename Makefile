DERIVED := .build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Copy for LLM.app

.PHONY: bootstrap generate build test install clean dmg

bootstrap:
	@command -v xcodegen >/dev/null || brew install xcodegen
	xcodegen generate

generate:
	xcodegen generate

build: generate
	xcodebuild -project CopyForLLM.xcodeproj -scheme CopyForLLM \
		-configuration Debug -derivedDataPath $(DERIVED) build

test:
	cd CopyForLLMCore && swift test

install: build
	rm -rf "/Applications/Copy for LLM.app"
	ditto "$(APP)" "/Applications/Copy for LLM.app"
	@echo "Installed. Enable the Quick Actions in System Settings → General → Login Items & Extensions."

clean:
	rm -rf .build CopyForLLM.xcodeproj
	cd CopyForLLMCore && swift package clean

dmg:
	Packaging/make-dmg.sh
