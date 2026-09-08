# App Store Connect Release & Processing

Once your `.ipa` has been uploaded via `xcrun altool`, Apple begins processing the build on App Store Connect. This document covers what happens next.

---

## 1. Apple Processing Timeline

* **Binary Processing:** Apple processes the uploaded build for 5 to 20 minutes. During this period, the build status in App Store Connect will appear as **"Processing"**.
* **Automated Email:** The team account owner receives an email when the build has finished processing (or if Apple detected any critical missing metadata such as missing Privacy Manifest entries).

---

## 2. Attaching the Build in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/apps).
2. Select your application.
3. If this is a new release version:
   - Click the **"+"** button next to **iOS App** in the left sidebar.
   - Enter the version number matching `pubspec.yaml` (e.g., `1.0.12`).
4. Scroll down to the **Build** section:
   - Click **"Add Build"**.
   - Select the newly uploaded build number (e.g., `Build 15`).
   - If prompted for **Export Compliance Information**, answer whether the app uses non-exempt encryption (typically **No** if using standard HTTPS/Firebase).
5. In **What's New in This Version**, provide release notes for users.
6. Click **Save** in the top right, then click **Add for Review**.
7. In the Review Submission page, click **Submit to App Review**.

---

## 3. Review Statuses
* **Waiting for Review:** The submission is queued for Apple's review team.
* **In Review:** An Apple reviewer has started testing the build (typically 24–48 hours).
* **Pending Developer Release / Ready for Sale:** The update has been approved and is ready to be published to users.
