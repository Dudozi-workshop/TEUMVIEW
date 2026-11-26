#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Flutter SDK required' >&2; exit 1; }
if [ ! -f android/app/src/main/AndroidManifest.xml ]; then
  scaffold="$(mktemp -d)"
  trap 'rm -rf "$scaffold"' EXIT
  flutter create --platforms=android --org com.dudozi --project-name teumview --no-pub "$scaffold/teumview"
  cp -R "$scaffold/teumview/android" ./android
fi
python3 - <<'PY'
from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
if 'android.permission.INTERNET' not in s:
    s=s.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
s=s.replace('android:label="teumview"', 'android:label="틈뷰"')
p.write_text(s)
PY
flutter pub get
