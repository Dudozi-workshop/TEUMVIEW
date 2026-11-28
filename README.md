# TEUMVIEW / 틈뷰

Minimal fullscreen personal dashboard built with Flutter. Android first; iOS planned.

## Development
Run `bash scripts/bootstrap_android.sh`, then `flutter analyze`, `flutter test`, and `flutter build apk --debug`. Long press the dashboard to edit. CI builds debug APK artifacts.

## Implemented in source
- Editable grid, ten widget types, multiple boards, undo/redo and responsive layouts.
- Built-in and custom skins, brightness, wake lock, night mode and optional layout shift.
- Local storage and versioned file backup with media.
- Weather development endpoint and read-only Google Calendar source integration.

## Verification
CI run 45776962613 passed analysis, tests and debug APK build before branding changes. Device QA and production OAuth are not verified.

## Release blockers
- Register approved branding assets under `branding/android-res`; bootstrap overlays these resources. Validate adaptive masking and splash.
- Configure production OAuth and signing, verify weather service commercial terms, privacy disclosures and target SDK.
- Build signed AAB, run device QA and Play testing, prepare listing assets.

See `docs/release_setup.md`, `docs/google_calendar_setup.md` and `docs/release_gate.md`. Package ID com.dudozi.teumview is approved; Play developer account ready. Two premium skin previews and three presets are implemented; production billing and entitlement validation are beta release gates. iOS is post-beta. See docs/beta_release_checklist.md.
