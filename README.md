# TEUMVIEW / 틈뷰
M1 source prototype: immersive dashboard, responsive clock/date, three skins, persistent display settings and optional wake lock.

Requires Flutter SDK. Generate platform scaffolding in this directory with `flutter create --platforms=android,ios --org com.dudozi .` (preserve existing source files), then run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`.

Not yet implemented: editable grid, remaining widgets, calendar OAuth, weather, database, backup, localization, billing, burn-in mitigation. No build or device validation has been performed. Android package ID is provisional. Android minimum SDK and store target SDK require verification.

## M2 editor draft
Long press the dashboard to edit. Drag cards to move, tap to select, drag the bottom-right handle to resize. Add/remove clock and date cards, undo/redo, reset, and independent portrait/landscape persistence. Invalid moves are rejected. Resize preview and collision feedback are not yet implemented. Flutter SDK unavailable in authoring environment; analyze, tests and Android build remain unverified.

## M3 draft
Ten widget types are registered. Clock, date, calendar, local tasks, memo, device battery, D-day and photo have initial implementations. Weather and agenda are explicit unconnected states pending M4 integration. Photos are copied into app storage; cleanup and backup are pending. Widget content is stored by tile ID in SharedPreferences. Flutter build, plugin permissions and device testing have not been verified. Compact-card overflow and interaction behavior require QA.

## M4 partial implementation
- Weather: Open-Meteo development endpoint, manual latitude/longitude, 15-minute refresh, explicit errors. Commercial usage terms and production endpoint must be verified before release. Android INTERNET permission must be added to the generated main manifest.
- Night mode: optional OLED theme from 22:00 to 07:00 local time. Fixed hours are temporary; brightness control is not implemented.
- Pending: Google OAuth/calendar, multi-board, backup/restore, brightness and burn-in mitigation.
- Flutter SDK unavailable; analysis, tests and device builds not executed.

## M4-2
- Multiple dashboards selectable in edit toolbar; legacy default board retained.
- Versioned JSON settings backup via clipboard, overwrite confirmation. Photo files are not embedded; this is not a portable media backup.
- Optional small periodic layout shift; not guaranteed burn-in prevention.
- Brightness control, dashboard deletion/rename, Google Calendar, file-based media backup and runtime verification remain pending.

## M5 skin foundation
Built-in skin catalog and preview tiles are separated from dashboard content. Existing skin IDs and backup format remain unchanged. Custom backgrounds, font selection, per-card overrides and paid entitlements are not implemented. Flutter build and tests remain unexecuted in this environment.

## M5-2 custom skin
Global custom skin settings: accent presets, card opacity/radius, text scale, system/monospace font, local photo background. Settings persist as JSON and are included in clipboard backup; photo bytes are not included. Night OLED overrides custom settings. One custom profile is supported. Flutter analysis/build/tests not run (SDK unavailable). Photo cleanup and contrast validation remain pending.

## M6-1
Dashboard rename and confirmed deletion added; last dashboard protected. Deleted dashboard content keys are retained to avoid deleting shared or historical widget data; cleanup remains pending. Brightness, calendar OAuth and file backup remain pending. Flutter tests not executed (SDK unavailable).

## M6-2
- Application brightness override/reset, persisted low-power setting (minute-level clock repaint).
- Grid-snapped move/resize preview with collision feedback.
- Flutter SDK unavailable; dependency resolution, analyzer, tests and device behavior remain unverified. Low-power mode does not reduce weather polling or timer wakeups.

## M6-3
File backup v2 embeds photos and skin background, restores into app storage, accepts v1 JSON files. 40 MiB media limit. Flutter build and device picker behavior unverified.

## M6-4 Google Calendar (source integration, not validated on device)
- `google_sign_in` 7.x OAuth flow; user-triggered read-only scope approval.
- Calendar selection, events retrieval (30 days, pagination), local cache and offline fallbacks.
- Agenda card and settings screen, account disconnect/cache clearing.
- Read `docs/google_calendar_setup.md`: Google Cloud OAuth/client IDs/consent, Android app signing SHA-1 and Calendar API enabling are required.
- Public GitHub repository `Dudozi-workshop/TEUMVIEW` does not exist in accessible account as of 2026-11-26; connected GitHub tool can commit to existing repos but cannot create new repositories. No project source is pushed.
- Flutter SDK unavailable in execution environment; tests/build not executed. This is a source draft.
- Static inspection also corrected one missing closing parenthesis in the M6-3 dashboard grid rendering branch. This was not a Flutter compiler validation.

## M6-5 Android validation preparation
Run `bash scripts/bootstrap_android.sh` to generate missing Android scaffolding and configure Internet permission. CI now attempts analysis, tests and a debug APK build, then uploads the APK only after success. See `docs/release_gate.md`. The script and workflow have not run with Flutter; no APK exists yet. Repository creation remains blocked by the available connector. Earlier milestone notes above are historical, not the current feature checklist.
