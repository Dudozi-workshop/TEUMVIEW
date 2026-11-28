# M6-5 release gate

Status: source only; no Flutter compiler or Android runtime validation yet.

1. Create the public TEUMVIEW repository under Dudozi-workshop. Review files for secrets before committing. Do not upload to an unrelated repository.
2. Commit the source, scripts and CI workflow. Run Android validation. Fix analyzer errors, failing tests and APK build errors before device QA.
3. Download the debug APK from Actions. Test fullscreen navigation, orientation, widget move/resize, persistence, backup with photos, skin settings, weather offline handling and Google Calendar authorization/revocation.
4. Register actual Android package and signing SHA-1 in Google Cloud; enable Calendar API. Configure consent and verify OAuth. Never commit signing keys or client secrets.
5. Confirm commercial weather API terms, Android minimum/target SDK, privacy disclosures, release signing and Play requirements. Debug APK is not a release bundle.

Local commands: `bash scripts/bootstrap_android.sh`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.
