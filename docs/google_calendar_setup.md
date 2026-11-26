# Google Calendar production setup

1. In Google Cloud create or select a project, enable **Google Calendar API**, configure OAuth consent screen, add Calendar readonly scope `https://www.googleapis.com/auth/calendar.readonly` and required testing users before production verification.
2. Create **Android OAuth 2.0 Client ID** with the final package name (`com.dudozi.teumview` is provisional) and SHA-1 of the signing certificate. Debug and Play App Signing certificates require appropriate registrations. Do not check in signing private keys.
3. Create a **Web application OAuth client ID** if the Android google_sign_in flow requires `serverClientId` (check the actual google_sign_in_android integration configuration). Supply it using platform configuration or a compile-time value; do not embed a client secret.
4. Check release requirements for Google Calendar restricted/sensitive scope verification and privacy policy. The scope is read-only, and user-facing account linking is explicit.
5. Generate Android/iOS scaffolding with Flutter, add Android INTERNET permission in the main AndroidManifest.xml, then validate OAuth on a physical device.
6. Test connect, permission decline, expired/revoked permission, multiple calendars, all-day events, cancellation, pagination, offline cached display and disconnect clearing local data.

Calendar event summaries are cached locally as `google_calendar_cache`; `BoardStore.allowed` excludes all `google_calendar_*` keys from backups. No OAuth tokens are manually saved by application code.
