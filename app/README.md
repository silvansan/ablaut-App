# ablaut mobile app

Flutter listener client for [ablaut server](https://github.com/silvansan/ablaut-Studio) deployments.

## Playback

On the player screen, **WebRTC (LiveKit)** is the default for the lowest latency while a LiveKit session is active. Switch to **HLS** for buffered HTTP playback via **audio_service** and **just_audio** when the server exposes LL-HLS egress (`channel.hlsUrl`) or an Icecast fallback URL.

LiveKit credentials come from **`POST /api/livekit/listener-token`**. The response may use `url`, `livekitUrl`, or `websocketUrl` for the signaling endpoint; this client accepts whichever field the server returns.

## Listener access

Public metadata is loaded with:

`GET /api/public/listen/:eventSlug/:channelSlug`

Event directory (when `unifiedListenerQrEnabled` is on):

`GET /api/public/listen/:eventSlug`

The response includes an `access` block. When `listenerPasswordRequired` is true, the app calls:

`POST /api/listener/verify-password`

and sends the returned `listenerSessionToken` to the listener-token endpoint (body field and/or `X-Ablaut-Listener-Session` header).

Legacy listener URL shapes remain supported (`/listen/...`, `/listener/...`, `/listen/{event}` for event directories, `/e/.../listen`, `undersound://`).

### LAN HTTP listener links

Studio deployments often use plain `http://192.168.x.x:3000/listen/...` QR codes on event Wi‑Fi.

| Platform | Behavior |
|----------|----------|
| Android | Cleartext HTTP is allowed via `android/app/src/main/res/xml/network_security_config.xml`. Prefer HTTPS in production. |
| iOS | `NSAllowsLocalNetworking` is enabled in `ios/Runner/Info.plist` for local-network HTTP. Prefer HTTPS in production. |

### Deep links

| Platform | Scheme |
|----------|--------|
| iOS | `undersound://` registered in `Info.plist` |
| Android | `undersound://` intent filter in `AndroidManifest.xml` |

Paste a listener URL manually or scan a QR code if the deep link is not routed automatically on your device.

## App updates (Android sideload)

On launch, the home screen checks GitHub Releases for a newer tag than the installed app version. When an update exists, users see a banner and dialog with a **Download update** button that opens the latest `app-release.apk` URL.

Release a new APK by pushing a tag such as `v0.3.1` (see `.github/workflows/android-release.yml`) or running the workflow manually. The app compares semver tags (`v0.3.1` → `0.3.1`) against `pubspec.yaml` `version`.

True silent background install is not used (Play Store is not required); Android will prompt the user to install after the APK download completes.

## Getting started

Install [Flutter](https://docs.flutter.dev/get-started/install), then from this directory:

```bash
flutter pub get
flutter analyze
flutter test
```

Run on a connected device:

```bash
flutter run
```

## Release builds

### Android

Place signing config in `android/key.properties` (not committed). Then:

```bash
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

The Android **applicationId** stays `com.undersound.mobile` (legacy package id) so existing installs can upgrade in place. The visible app name is **ablaut**. Native code uses the `com.ablaut.mobile` namespace.

### iOS (iPhone and iPad)

Requires a Mac with Xcode 15+ and an [Apple Developer](https://developer.apple.com) account.

| Setting | Value |
|--------|--------|
| Bundle ID | `com.ablaut.mobile` |
| Minimum iOS | 15.0 |
| Devices | iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`) |
| Display name | ablaut |

**One-time setup**

1. Open `ios/Runner.xcworkspace` in Xcode (not the `.xcodeproj`).
2. Select the **Runner** target → **Signing & Capabilities** → choose your Team and enable **Automatically manage signing**.
3. Confirm the bundle identifier is `com.ablaut.mobile` and matches an App ID in the Developer portal.
4. Run `pod install` in `ios/` if CocoaPods prompts you (Flutter usually runs this on build).

**Archive for App Store / TestFlight**

```bash
flutter build ipa --release
```

Or in Xcode: **Product → Archive**, then distribute via Organizer.

For CI or `xcodebuild` export, copy `ios/ExportOptions.plist.example` to `ios/ExportOptions.plist`, set your `teamID`, and pass it to `xcodebuild -exportArchive`.

**App Store Connect checklist**

- Upload screenshots for **6.7" iPhone** and **12.9" iPad** (or use Xcode’s screenshot tools on simulators).
- Privacy: declare camera and photo library use (QR scan / gallery import). No tracking.
- Export compliance: app uses standard HTTPS only (`ITSAppUsesNonExemptEncryption` is false in `Info.plist`).
- Background **audio** is enabled for lock-screen playback.
- Legacy `undersound://` links are registered as a URL scheme for deep links.

**Simulator / device dev**

```bash
flutter run -d ios
```

## Launcher icons

Regenerate Android/iOS launcher assets after changing logo files:

```bash
dart run flutter_launcher_icons
```

Source assets:

- `assets/ablaut-launcher-icon.png` — full icon with brand background
- `assets/ablaut-icon-foreground.png` — centered mark for adaptive foreground
- `assets/ablaut-logo.png` — in-app logo

## iOS launch screen

Replace launch images under `ios/Runner/Assets.xcassets/LaunchImage.imageset/` or customize the launch storyboard in Xcode. See `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`.
