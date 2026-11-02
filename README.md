<p align="center"><img width="200" height="200" align="center" alt="ablaut logo" src="./app/assets/ablaut-logo.png" /></p>

# ablaut-App

ablaut lets listeners join live translated audio from an [ablaut server](https://github.com/silvansan/ablaut-Studio) deployment, and lets translators publish their voice from the same app.

Scan an ablaut QR code, open a saved favorite, or paste a link, then listen through your phone or Bluetooth headphones. Scan a speaker QR code instead to publish your microphone to a channel.

## Download (Android)

Install the latest APK from [GitHub Releases](https://github.com/silvansan/ablaut-App/releases/latest):

**[Download app-release.apk](https://github.com/silvansan/ablaut-App/releases/latest/download/app-release.apk)**

After downloading, Android may ask you to allow installation from your browser or file manager. This app is distributed via GitHub (sideload), not the Google Play Store.

Older releases used different APK file names; the current release asset is always **`app-release.apk`** so the link above stays stable.

## Server

This repo is the **mobile** companion for the **[ablaut server](https://github.com/silvansan/ablaut-Studio)**: host events, create language channels, and print listener and speaker QR codes there. The QR PDFs the server prints end with a QR code for downloading this app.

| Repo | Role |
|------|------|
| [ablaut-Studio](https://github.com/silvansan/ablaut-Studio) | ablaut server — dashboard, LiveKit/HLS publishing |
| [ablaut-App](https://github.com/silvansan/ablaut-App) | Android / iOS listener and speaker app (this repo) |

The app reads the same links the server puts in its QR codes:

- `/listen/<event>/<channel>`: one channel
- `/listen/<event>`: all channels of an event (the server's **One QR for all languages** option), then pick a language
- `/speak/<event>/<channel>`: speaker mode

Events with **Private links** turned on use random codes in place of the event and channel names; the app handles both. If you use Private links, run ablaut-Studio **0.5.1 or later**: earlier versions printed broken links for channels added after Private links was turned on.

Older link formats still work, including legacy `/e/.../listen` URLs and `undersound://` deep links.

## Features

- Scan QR codes with the camera or from an image file.
- Paste or enter a link manually.
- Pick a language from an event-wide QR code.
- Save favorite channels and reopen them from the home screen.
- Save a whole event from its language list. A saved event opens its channel list, and any of its channels you also saved show inside it as one-tap shortcuts.
- Password-protected listener channels (verify with the event listener password, then reconnect with a saved session).
- Low-latency WebRTC (LiveKit) playback with HLS fallback when the server provides it.
- Android media notification controls for play, pause, and mute.
- Pause automatically when headphones or Bluetooth disconnect.
- **Speaker mode:** publish your microphone to a channel, mute and unmute, with speaker-password support. The app asks for microphone permission only when you start.
- Show a channel's listener QR on screen so people next to you can scan it.
- Get notified in the app when a newer Android release is out, and download it from the home screen.

## Privacy

ablaut is built for listening to live event audio. The app does not add advertising or tracking.

Camera access is used only for QR scanning. Microphone access is used only in speaker mode, while you publish. Listener passwords can be stored locally on your device (encrypted) so you do not have to re-enter them for saved favorites.

## Development

See [app/README.md](app/README.md) for Flutter setup, Android/iOS release builds, and API notes.
