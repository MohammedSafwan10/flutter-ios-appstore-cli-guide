# 🚀 Flutter iOS App Store CLI Automation & Agent Guide

> **Zero-GUI, headless build, signing, and distribution guide for Flutter iOS apps to Apple App Store Connect.**  
> Specifically engineered for DevOps engineers, CI/CD pipelines, and autonomous AI coding agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.x%2B-02569B.svg)]()

---

## 📖 Why This Guide Exists

Standard Flutter documentation often assumes a developer is seated in front of Xcode GUI with their Apple ID logged into the macOS Keychain. In automated CI/CD runners (GitHub Actions, GitLab CI) and autonomous AI agent sessions, this breaks down with common failures:
* `error: exportArchive No Accounts`
* `error: exportArchive No signing certificate "iOS Distribution" found`
* `PhaseScriptExecution: flutterfire: command not found`
* CocoaPods / Firebase SDK lockfile version mismatches.
* Conflicting TensorFlow / native framework duplicates.

This repository provides **the battle-tested, repeatable CLI workflow** to pull changes, test, build, cloud-sign with an App Store Connect API Key, and upload to TestFlight / App Store without touching the Xcode GUI.

---

## 🔒 Security First: Zero Secret Commit Policy

This repository is strictly designed with **zero hardcoded credentials**:
* Private keys (`.p8`, `.p12`) and `.env` files are strictly gitignored in [`.gitignore`](.gitignore).
* All automation scripts use environment variables:
  * `APPSTORE_KEY_ID`: 10-character key ID from App Store Connect.
  * `APPSTORE_ISSUER_ID`: App Store Connect Issuer UUID.
  * `APPSTORE_KEY_PATH`: Local path to the private `.p8` key file.
  * `APPLE_TEAM_ID`: 10-character Apple Developer Team ID.

See [`templates/.env.example`](templates/.env.example) for setup.

---

## 🤖 For AI Agents & LLMs

If you are an AI assistant (Antigravity, Cursor, Claude, Copilot, etc.) tasked with deploying a Flutter iOS app:
👉 **Read [`AGENTS.md`](AGENTS.md)** first. It contains your complete decision tree, operational checklist, and exact commands.

---

## ⚡ Quick Start: Automated Release

Run the preflight check to ensure your host has the required tools and keys configured:
```bash
./scripts/preflight_check.sh
```

Execute a full build and App Store upload for any Flutter project:
```bash
./scripts/build_and_upload.sh --project-dir /path/to/flutter_project
```

Or test the configuration without executing a build:
```bash
./scripts/build_and_upload.sh --project-dir /path/to/flutter_project --dry-run
```

---

## 🛠️ The 5-Step Core CLI Workflow

### 1. Sync & Validate Dependencies
```bash
flutter pub get
(cd ios && pod install || pod update)
flutter analyze
```

### 2. Build Release Archive via Flutter
```bash
flutter build ipa --release --export-method app-store 2>&1
```
*(Creates `build/ios/archive/Runner.xcarchive`)*

### 3. Re-sign & Export with App Store Connect API Key
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

### 4. Headless Upload via `xcrun altool`
```bash
xcrun altool --upload-app \
  --type ios \
  -f "build/ios/ipa/<YourApp>.ipa" \
  --apiKey "$APPSTORE_KEY_ID" \
  --apiIssuer "$APPSTORE_ISSUER_ID"
```

### 5. Finalize in App Store Connect
Wait 10–15 minutes for Apple processing, navigate to [App Store Connect](https://appstoreconnect.apple.com), attach the build to the version, and submit for review.

---

## 📚 Detailed Documentation

* [**Prerequisites & Authentication Setup**](docs/01-prerequisites-and-auth.md): How to create App Store Connect API keys and configure your environment.
* [**Full Build & Release Workflow**](docs/02-flutter-ios-build-workflow.md): Deep dive into what happens during each phase.
* [**Troubleshooting Playbook**](docs/03-troubleshooting-playbook.md): Detailed diagnoses and solutions for all real-world build and signing errors.
* [**App Store Connect Release Guide**](docs/04-app-store-connect-release.md): Post-upload verification and App Store review submission.

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
