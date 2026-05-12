# UnderSound Mobile

This folder contains the Flutter mobile app scaffold for the UnderSound listener app.

## Structure

- `app/` — Flutter project generated with the bundled SDK
- `flutter/` — local Flutter SDK checkout included in the repo
- `.gitignore` — excludes Flutter SDK and generated build artifacts

## How to run

From `UnderSound-Mobile/app`:

```powershell
..\flutter\bin\flutter pub get
..\flutter\bin\flutter run
```

## Next steps

Current app status:

- Manual listener-link entry is wired.
- QR scanning is wired for existing UnderSound listener links.
- The app loads public channel metadata from the current server API.
- HLS playback uses `just_audio` with `audio_session` configured for music playback.
- Android/iOS metadata now includes camera and background-audio basics.

Next steps:

1. Add `audio_service` foreground notification / lock-screen media controls.
2. Save and reopen the last listener link with `shared_preferences`.
3. Add the planned event overview flow once `/api/mobile/events/:eventId` exists.
4. Test on a physical Android phone against a live HLS stream.
