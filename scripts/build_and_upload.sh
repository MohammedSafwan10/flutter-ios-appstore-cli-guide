#!/usr/bin/env bash
# ==============================================================================
# Complete Flutter iOS Build, Sign & App Store Upload Script
# Headless execution for CI/CD and AI Agent automation.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(pwd)"
SKIP_UPLOAD=false
DRY_RUN=false

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -p, --project-dir <path>   Path to Flutter project root (default: current directory)"
  echo "  --skip-upload              Build and export IPA only, do not upload to App Store"
  echo "  --dry-run                  Validate configuration without executing build"
  echo "  -h, --help                 Display this help message"
  exit 1
}

# Parse Arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--project-dir) PROJECT_DIR="$2"; shift ;;
    --skip-upload) SKIP_UPLOAD=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   Flutter iOS App Store Automated Release Script     ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Load Environment Variables
if [ -f "$PROJECT_DIR/.env" ]; then
  # shellcheck disable=SC1090
  source "$PROJECT_DIR/.env"
elif [ -f "$(dirname "$0")/../templates/.env" ]; then
  # shellcheck disable=SC1090
  source "$(dirname "$0")/../templates/.env"
fi

# 2. Validate Credentials
if [ -z "$APPSTORE_KEY_ID" ] || [ -z "$APPSTORE_ISSUER_ID" ] || [ -z "$APPSTORE_KEY_PATH" ]; then
  echo -e "${RED}Error: App Store Connect credentials missing.${NC}"
  echo "Please export APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, and APPSTORE_KEY_PATH"
  exit 1
fi

if [ ! -f "$APPSTORE_KEY_PATH" ]; then
  echo -e "${RED}Error: Private key file not found at: $APPSTORE_KEY_PATH${NC}"
  exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

if [ ! -f "pubspec.yaml" ]; then
  echo -e "${RED}Error: Not a valid Flutter project. pubspec.yaml missing in $PROJECT_DIR${NC}"
  exit 1
fi

VERSION=$(grep "^version:" pubspec.yaml | head -n1 | cut -d' ' -f2)
echo -e "${GREEN}Project:${NC} $PROJECT_DIR"
echo -e "${GREEN}Version:${NC} $VERSION"

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}Dry-run mode enabled. Exiting before build.${NC}"
  exit 0
fi

# 3. Ensure flutterfire CLI is linked
if [ -f "$HOME/.pub-cache/bin/flutterfire" ]; then
  FLUTTER_BIN_DIR="$(dirname "$(which flutter)")"
  if [ ! -f "$FLUTTER_BIN_DIR/flutterfire" ]; then
    echo "Linking flutterfire into $FLUTTER_BIN_DIR..."
    ln -sf "$HOME/.pub-cache/bin/flutterfire" "$FLUTTER_BIN_DIR/flutterfire" 2>/dev/null || true
  fi
fi

# 4. Sync Dependencies
echo -e "\n${BLUE}[1/5] Fetching Flutter dependencies...${NC}"
flutter pub get

# 5. Sync CocoaPods
echo -e "\n${BLUE}[2/5] Installing CocoaPods...${NC}"
(cd ios && pod install || pod update)

# 6. Static Analysis
echo -e "\n${BLUE}[3/5] Running static analysis...${NC}"
flutter analyze

# 7. Build Archive
echo -e "\n${BLUE}[4/5] Building Release Archive (Runner.xcarchive)...${NC}"
# Allow export failures in flutter build ipa because we handle export via xcodebuild below
set +e
flutter build ipa --release --export-method app-store 2>&1
BUILD_STATUS=$?
set -e

ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner.xcarchive"
if [ ! -d "$ARCHIVE_PATH" ]; then
  echo -e "${RED}Error: Archive failed to generate at $ARCHIVE_PATH${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Archive successfully created at: $ARCHIVE_PATH${NC}"

# 8. Export IPA with App Store Connect API Key
echo -e "\n${BLUE}[5/5] Re-signing & Exporting IPA via xcodebuild...${NC}"
EXPORT_PLIST="$PROJECT_DIR/ios/ExportOptions.plist"

# Generate ExportOptions.plist if missing
if [ ! -f "$EXPORT_PLIST" ]; then
  mkdir -p "$PROJECT_DIR/ios"
  TEAM_ID="${APPLE_TEAM_ID:-$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' ios/Runner.xcodeproj/project.pbxproj | cut -d' ' -f3)}"
  cat <<EOF > "$EXPORT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>generateAppStoreInformation</key>
	<false/>
	<key>manageAppVersionAndBuildNumber</key>
	<true/>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>testFlightInternalTestingOnly</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF
fi

mkdir -p "$PROJECT_DIR/build/ios/ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$PROJECT_DIR/build/ios/ipa" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$APPSTORE_KEY_PATH" \
  -authenticationKeyID "$APPSTORE_KEY_ID" \
  -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID"

IPA_FILE=$(find "$PROJECT_DIR/build/ios/ipa" -maxdepth 1 -name "*.ipa" | head -n1)
if [ -z "$IPA_FILE" ] || [ ! -f "$IPA_FILE" ]; then
  echo -e "${RED}Error: Exported IPA not found in $PROJECT_DIR/build/ios/ipa${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Successfully exported IPA: $IPA_FILE${NC}"

# 9. Upload to App Store Connect
if [ "$SKIP_UPLOAD" = true ]; then
  echo -e "${YELLOW}Upload skipped (--skip-upload provided).${NC}"
  echo -e "${GREEN}IPA ready at: $IPA_FILE${NC}"
  exit 0
fi

echo -e "\n${BLUE}Uploading IPA to App Store Connect...${NC}"
xcrun altool --upload-app \
  --type ios \
  -f "$IPA_FILE" \
  --apiKey "$APPSTORE_KEY_ID" \
  --apiIssuer "$APPSTORE_ISSUER_ID" \
  2>&1

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}  ✓ Upload Complete! Build submitted to Apple.        ${NC}"
echo -e "${GREEN}======================================================${NC}"
