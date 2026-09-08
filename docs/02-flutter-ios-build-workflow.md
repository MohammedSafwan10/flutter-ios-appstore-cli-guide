# Flutter iOS Build & Release Workflow

This document details the exact sequence of commands and rationale required to build, sign, and upload a Flutter iOS app to the App Store without opening Xcode.

---

## The Build Pipeline Overview

```
Repository Pull
      │
      ▼
Dependency Sync (pub get & pod install)
      │
      ▼
Static Analysis & Verification
      │
      ▼
Xcode Archive Creation (flutter build ipa)
      │
      ▼
Cloud Re-Signing & IPA Export (xcodebuild -exportArchive)
      │
      ▼
App Store Ingestion (xcrun altool)
```

---

## Detailed Step Breakdown

### 1. Codebase Sync & Version Check
Always ensure you are working on the intended branch with clean working tree:
```bash
git fetch origin
git checkout main
git pull origin main
```
Inspect `pubspec.yaml` to confirm that the build number has been bumped:
```yaml
version: 1.0.12+15 # Format: <marketing_version>+<build_number>
```
Apple requires each new upload to have a strictly higher build number than prior uploads.

---

### 2. Dependency Management
```bash
flutter pub get
```
Navigate to `ios/` and ensure native CocoaPods are installed and linked:
```bash
cd ios
pod install
cd ..
```
If a Flutter plugin updated its dependency constraint (such as Firebase Core/Firestore/Functions), run:
```bash
cd ios
pod update
cd ..
```

---

### 3. Quality & Static Analysis
Run static analysis to ensure there are no compilation or type errors:
```bash
flutter analyze
```
All errors must be resolved before proceeding to the archive build.

---

### 4. Create the Release Archive
Run Flutter's release IPA builder:
```bash
flutter build ipa --release --export-method app-store 2>&1
```
This performs:
- Ahead-of-Time (AOT) Dart compilation.
- Compilation of all CocoaPods frameworks for `arm64`.
- Building the Xcode archive at `build/ios/archive/Runner.xcarchive`.

---

### 5. Re-signing & IPA Export via `xcodebuild`
When running in headless CLI or CI/CD environments where no Apple ID is logged into the local Xcode GUI, `flutter build ipa` will error at the export step:
```
error: exportArchive No Accounts
error: exportArchive No signing certificate "iOS Distribution" found
```
**Resolution:** Use `xcodebuild -exportArchive` directly with Apple's Cloud Managed Certificate API:

```bash
xcodebuild -exportArchive \
  -archivePath "build/ios/archive/Runner.xcarchive" \
  -exportPath "build/ios/ipa" \
  -exportOptionsPlist "ios/ExportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$APPSTORE_KEY_PATH" \
  -authenticationKeyID "$APPSTORE_KEY_ID" \
  -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID"
```

#### Why This Works:
`-allowProvisioningUpdates` combined with `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID` tells Xcode to authenticate against App Store Connect directly via API, generate or fetch the Distribution Certificate, create the distribution provisioning profile, and sign every framework bundle automatically in the cloud.

The exported `.ipa` will be placed in `build/ios/ipa/`.

---

### 6. Headless App Store Upload via `xcrun altool`
Upload the `.ipa` package directly to App Store Connect:

```bash
xcrun altool --upload-app \
  --type ios \
  -f "build/ios/ipa/<AppName>.ipa" \
  --apiKey "$APPSTORE_KEY_ID" \
  --apiIssuer "$APPSTORE_ISSUER_ID" \
  2>&1
```

Upon successful upload, `altool` returns:
```
UPLOAD SUCCEEDED with no errors
Delivery UUID: <UUID>
```
Apple will now ingest the binary and process it for TestFlight and App Store submission.
