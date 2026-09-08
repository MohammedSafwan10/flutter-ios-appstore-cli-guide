# Prerequisites & Authentication

This document describes the necessary credentials, tools, and environment variables needed to build and deploy Flutter iOS apps to Apple App Store Connect headlessly via the command line.

---

## 1. App Store Connect API Key Setup

An App Store Connect API Key allows CLI tools (`xcodebuild`, `xcrun altool`) to authenticate with Apple Developer services without interactive 2FA or GUI logins.

### Creating the API Key
1. Log in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Navigate to **Users and Access** → **Integrations** (or **Keys** tab).
3. Under **App Store Connect API**, click the **"+"** button to generate a new key.
4. Set the **Name** (e.g. `CI-CD-Deploy-Key`) and assign the **Admin** or **App Manager** role.
5. Note the following three items:
   - **Key ID**: A 10-character alphanumeric ID (e.g., `AB12CD34EF`).
   - **Issuer ID**: A UUID located at the top of the Keys page (e.g., `00000000-0000-0000-0000-000000000000`).
   - **Private Key File**: Download the `.p8` file (e.g., `AuthKey_AB12CD34EF.p8`).
     > [!CAUTION]
     > Apple only allows downloading the `.p8` private key **once**. Save it in a secure location on your machine (e.g., `~/.private_keys/` or `/Users/<username>/private_keys/`).

---

## 2. Environment Variables Configuration

Copy `templates/.env.example` to `.env` (or set these in your shell profile / CI secret manager):

```bash
# 10-character Key ID
export APPSTORE_KEY_ID="AB12CD34EF"

# Issuer UUID
export APPSTORE_ISSUER_ID="00000000-0000-0000-0000-000000000000"

# Path to the .p8 file
export APPSTORE_KEY_PATH="/Users/username/private_keys/AuthKey_AB12CD34EF.p8"

# 10-character Apple Developer Team ID
export APPLE_TEAM_ID="YOUR_TEAM_ID"
```

> [!WARNING]
> Never commit `.env` or any `.p8` files to git repositories.

---

## 3. Required CLI Tools

Verify the installed tools on the macOS host:

```bash
# 1. Xcode command-line tools
xcode-select -p
xcodebuild -version

# 2. Flutter SDK
flutter --version

# 3. CocoaPods
pod --version

# 4. ALTool (part of Xcode ContentDelivery framework)
xcrun altool --version
```

### Installing FlutterFire CLI (Required if using Crashlytics symbol upload)
```bash
dart pub global activate flutterfire_cli
# Symlink into Flutter root bin so Xcode script phases can locate it
ln -sf "$HOME/.pub-cache/bin/flutterfire" "$(dirname $(which flutter))/flutterfire"
```
