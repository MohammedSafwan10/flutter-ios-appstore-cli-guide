# Troubleshooting Playbook: Real-World Build & Export Errors

This document catalogs real-world issues encountered when automating Flutter iOS App Store builds and provides field-tested resolutions.

---

## 1. Export Error: `No Accounts / No signing certificate "iOS Distribution" found`

### Symptoms
When running `flutter build ipa --release --export-method app-store`:
```
Encountered error while creating the IPA:
error: exportArchive No Accounts
error: exportArchive No signing certificate "iOS Distribution" found
```
However, the archive `Runner.xcarchive` was successfully created under `build/ios/archive/`.

### Cause
`flutter build ipa` invokes `xcodebuild -exportArchive` without passing App Store Connect API Key arguments. Xcode requires an active Apple Developer account to fetch the Distribution Certificate from the keychain or Apple portal.

### Fix
Do not re-archive! Export the existing `.xcarchive` directly using `xcodebuild -exportArchive` with the API key flags:
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

---

## 2. Xcode Script Error: `flutterfire: command not found`

### Symptoms
During Xcode compilation phase:
```
/Users/.../Script-5304108602EFE5196D233F98.sh: line 15: flutterfire: command not found
Command PhaseScriptExecution failed with a nonzero exit code
```

### Cause
Firebase Crashlytics injects a Run Script phase into Xcode (`FlutterFire: "flutterfire upload-crashlytics-symbols"`). In isolated Xcode execution environments, user home pub cache binaries (`$HOME/.pub-cache/bin`) might not be on the subshell's `$PATH`.

### Fix
1. Activate `flutterfire_cli`:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Symlink `flutterfire` into the Flutter SDK's `bin` directory (which Xcode always includes on `$PATH`):
   ```bash
   ln -sf "$HOME/.pub-cache/bin/flutterfire" "$(dirname $(which flutter))/flutterfire"
   ```

---

## 3. Duplicate Frameworks: `TensorFlowLiteC.xcframework` / Duplicate Symbols

### Symptoms
CocoaPods or Xcode linker fails with duplicate target/framework names or colliding symbols:
```
Multiple commands produce '.../TensorFlowLiteC.xcframework'
```

### Cause
Occurs when two dependencies simultaneously pull TensorFlow Lite. For example:
- `tflite_flutter` pulls CocoaPod `TensorFlowLiteC`.
- `flutter_litert` (vendored in modern face matching packages like `face_match_kit`) also vendors `TensorFlowLiteC.xcframework`.

### Fix
Migrate away from legacy `tflite_flutter`:
1. Comment out `tflite_flutter` in `pubspec.yaml`:
   ```yaml
   # tflite_flutter: ^0.12.1
   ```
2. Run `flutter pub get`.
3. In `ios/`, clean and re-install pods:
   ```bash
   cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
   ```

---

## 4. CocoaPods Firebase SDK Version Conflict

### Symptoms
```
[!] CocoaPods could not find compatible versions for pod "Firebase/Functions":
  In snapshot (Podfile.lock):
    Firebase/Functions (= 12.12.0)
  In Podfile:
    cloud_functions depends on Firebase/Functions (= 12.18.0)
```

### Cause
A Flutter Firebase plugin was upgraded in `pubspec.yaml` (e.g. `cloud_functions: ^6.4.0`), but `ios/Podfile.lock` is pinned to older Firebase SDK versions.

### Fix
Run `pod update` inside the `ios/` directory:
```bash
cd ios
pod update
cd ..
```
This updates the locked dependencies across all Firebase pods consistently.

---

## 5. Host Native Assets CMake Error During Unit Tests

### Symptoms
When running `flutter test` on macOS host:
```
CMake Error ... OpenCV 4.x requires C++11, but your compiler does not support it
Building native assets failed.
```

### Cause
Packages using Dart Native Assets (such as `dartcv4`) attempt to compile C/C++ libraries for the macOS host machine during unit tests, requiring host CMake and toolchains.

### Fix
This error only affects host desktop unit tests. For iOS builds (`flutter build ipa`), CocoaPods and Xcode compile for `arm64-apple-ios` directly without invoking host desktop CMake. Run `flutter analyze` to verify code correctness, and proceed to `flutter build ipa`.

---

## 6. Xcode License Agreement Block on Headless CLI

### Symptoms
`git`, `flutter`, or `dart` commands fail or hang with:
```
You have not agreed to the Xcode license agreements. Please run 'sudo xcodebuild -license'
```

### Cause
When Xcode is updated to a new major version (e.g., Xcode 27), Apple requires a root-level license agreement before CLI toolchains linked to `/Applications/Xcode.app` can execute.

### Fix
1. For git or static analysis operations that don't need the full Xcode IDE SDK, bypass using Command Line Tools:
   ```bash
   DEVELOPER_DIR=/Library/Developer/CommandLineTools git <subcommand>
   DEVELOPER_DIR=/Library/Developer/CommandLineTools dart analyze
   ```
2. For Xcode builds (`flutter build ipa` or `xcodebuild`), accept the updated license:
   ```bash
   sudo xcodebuild -license accept
   ```

---

## 7. Xcode 27+ Deployment Target Integrity Error

### Symptoms
During `flutter build ipa`:
```
Target Integrity (Xcode): The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET'
is set to 9.0 (or 11.0, 12.0, 14.0), but the range of supported deployment target versions is 15.0 to 27.0.x.
Encountered error while archiving for device.
```

### Cause
Xcode 27 and newer dropped support for iOS deployment targets below `15.0`. Older CocoaPods plugins specify legacy minimums (e.g. 9.0 or 12.0).

### Fix
Enforce a minimum deployment target of `15.0` inside `ios/Podfile` under the `post_install` hook:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end

  installer.pods_project.build_configurations.each do |config|
    if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```
Then run `pod install` in `ios/` to regenerate `Pods.xcodeproj`.
