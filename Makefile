PROJECT = MacMonitor.xcodeproj
SCHEME = MacMonitor
DEST = platform=macOS

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' build

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' test

ci: build test

package-test:
	./scripts/create-test-build.sh
