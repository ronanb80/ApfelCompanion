SCHEME = Ulog
PROJECT = Ulog.xcodeproj
DESTINATION = 'platform=macOS'
ARCHIVE_PATH = build/Ulog.xcarchive
EXPORT_PATH = build/export

.PHONY: build test lint clean archive release

# Build the project
build:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION)

# Run unit tests
test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION)

# Run SwiftLint
lint:
	swiftlint --strict

# Clean build artifacts
clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf build/

# Archive the app for release
archive:
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-archivePath $(ARCHIVE_PATH) \
		-destination $(DESTINATION)

# Build a release zip and create a GitHub release
# Usage: make release VERSION=1.0.0
release: clean archive
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=1.0.0)
endif
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist
	cd $(EXPORT_PATH) && zip -r ../../Ulog.zip Ulog.app
	gh release create v$(VERSION) Ulog.zip --title "v$(VERSION)" --generate-notes
