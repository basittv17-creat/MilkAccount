#!/usr/bin/env bash
set -euo pipefail

# The repository keeps Flutter's app source as the source of truth.
# Generate platform scaffolding with the same stable Flutter SDK used by CI.
if [[ ! -d android || ! -f web/index.html ]]; then
  flutter create \
    --platforms=android,web \
    --project-name milkaccount \
    --org com.awasigogera \
    .
else
  echo "Android and Web platform folders already exist; leaving them unchanged."
fi

# Keep the generated app compatible with Android plugins that require API 36.
# compileSdk and targetSdk are explicitly pinned to the Google Play API 36 requirement.
APP_GRADLE="android/app/build.gradle.kts"
if [[ -f "$APP_GRADLE" ]]; then
  if grep -q 'compileSdk = flutter.compileSdkVersion' "$APP_GRADLE"; then
    sed -i 's/compileSdk = flutter\.compileSdkVersion/compileSdk = 36/' "$APP_GRADLE"
  elif ! grep -qE 'compileSdk[[:space:]]*=[[:space:]]*36' "$APP_GRADLE"; then
    echo "Could not safely set Android compileSdk to 36 in $APP_GRADLE" >&2
    exit 1
  fi
fi

# Play Console target API requirement: compileSdk alone is not sufficient.
if grep -q 'targetSdk = flutter.targetSdkVersion' "$APP_GRADLE"; then
  sed -i 's/targetSdk = flutter\.targetSdkVersion/targetSdk = 36/' "$APP_GRADLE"
elif ! grep -qE 'targetSdk[[:space:]]*=[[:space:]]*36' "$APP_GRADLE"; then
  echo "Could not safely set Android targetSdk to 36 in $APP_GRADLE" >&2
  exit 1
fi

# SMS sharing uses Android's external message composer; no SMS permission is needed.
# Nearby Connections uses Bluetooth, Wi-Fi and legacy Location permission for direct transfers.
# Camera is used only to scan the nearby-transfer QR code.
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]] && ! grep -q 'android.permission.BLUETOOTH_ADVERTISE' "$MANIFEST"; then
  sed -i '/<application/i\\    <uses-permission android:maxSdkVersion="31" android:name="android.permission.ACCESS_WIFI_STATE" />\\n    <uses-permission android:maxSdkVersion="31" android:name="android.permission.CHANGE_WIFI_STATE" />\\n    <uses-permission android:maxSdkVersion="30" android:name="android.permission.BLUETOOTH" />\\n    <uses-permission android:maxSdkVersion="30" android:name="android.permission.BLUETOOTH_ADMIN" />\\n    <uses-permission android:maxSdkVersion="28" android:name="android.permission.ACCESS_COARSE_LOCATION" />\\n    <uses-permission android:minSdkVersion="29" android:maxSdkVersion="31" android:name="android.permission.ACCESS_FINE_LOCATION" />\\n    <uses-permission android:minSdkVersion="31" android:name="android.permission.BLUETOOTH_ADVERTISE" />\\n    <uses-permission android:minSdkVersion="31" android:name="android.permission.BLUETOOTH_CONNECT" />\\n    <uses-permission android:minSdkVersion="31" android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />\\n    <uses-permission android:minSdkVersion="32" android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />\\n    <uses-permission android:name="android.permission.CAMERA" />\\n    <uses-feature android:name="android.hardware.camera" android:required="false" />' "$MANIFEST"
fi

# Pin the generated Android toolchain below AGP 9: AGP 9's new DSL currently
# breaks this Flutter app's legacy Android plugin configuration and AAB signing.
# Use Python regexes here so the generated Gradle version strings are matched
# reliably (the previous sed expressions over-escaped the literal dots).
python3 - <<'PY'
from pathlib import Path
import re

settings = Path("android/settings.gradle.kts")
wrapper = Path("android/gradle/wrapper/gradle-wrapper.properties")
if not settings.is_file():
    raise SystemExit(f"Missing generated Gradle settings file: {settings}")
if not wrapper.is_file():
    raise SystemExit(f"Missing generated Gradle wrapper properties file: {wrapper}")

settings_text = settings.read_text()
# Flutter's generated Kotlin DSL uses: id("com.android.application") version "x.y.z" apply false
# Match that exact plugin declaration and replace only its version.
agp_pattern = re.compile(
    r'(^[ \t]*id\(["\']com\.android\.application["\']\)[ \t]+version[ \t]+["\'])[^"\']+(["\'].*$)',
    re.MULTILINE,
)
settings_text, agp_count = agp_pattern.subn(
    r'\g<1>8.11.1\g<2>',
    settings_text,
    count=1,
)
if agp_count != 1:
    raise SystemExit(
        "Could not find exactly one Kotlin DSL declaration for "
        "id(\"com.android.application\") and its version."
    )
if re.search(
    r'id\(["\']com\.android\.application["\']\)[^\n]*version[ \t]+["\']9\.',
    settings_text,
):
    raise SystemExit("Android Gradle Plugin 9 is still configured.")
settings.write_text(settings_text)

wrapper_text = wrapper.read_text()
wrapper_text, gradle_count = re.subn(
    r'gradle-[0-9][^/]*-all\.zip',
    'gradle-8.14-all.zip',
    wrapper_text,
    count=1,
)
if gradle_count != 1 or 'gradle-8.13-all.zip' not in wrapper_text:
    raise SystemExit("Could not pin Gradle 8.13.")
wrapper.write_text(wrapper_text)
PY

# Keep compatibility switches for the current Flutter plugin set, which still
# uses the external Kotlin Gradle Plugin and legacy Android Gradle DSL.
GRADLE_PROPERTIES="android/gradle.properties"
if [[ -f "$GRADLE_PROPERTIES" ]]; then
  grep -q '^android.newDsl=' "$GRADLE_PROPERTIES" || printf '\nandroid.newDsl=false\n' >> "$GRADLE_PROPERTIES"
  grep -q '^android.builtInKotlin=' "$GRADLE_PROPERTIES" || printf 'android.builtInKotlin=false\n' >> "$GRADLE_PROPERTIES"
else
  echo "Missing generated Gradle properties file: $GRADLE_PROPERTIES" >&2
  exit 1
fi

# Fail early if the generated Android configuration does not use the official
# application ID in both the namespace and installed APK metadata.
EXPECTED_APP_ID="com.awasigogera.milkaccount"
if [[ ! -f "$APP_GRADLE" ]] ||
   ! grep -Fq "namespace = \"$EXPECTED_APP_ID\"" "$APP_GRADLE" ||
   ! grep -Fq "applicationId = \"$EXPECTED_APP_ID\"" "$APP_GRADLE"; then
  echo "Android namespace and applicationId must both be $EXPECTED_APP_ID." >&2
  exit 1
fi

# Fail early if the generated application Gradle file did not receive API 36.
if ! grep -qE 'compileSdk[[:space:]]*=[[:space:]]*36' "$APP_GRADLE"; then
  echo "Android app compileSdk must be 36; generated configuration is not correct." >&2
  exit 1
fi

if ! grep -qE 'targetSdk[[:space:]]*=[[:space:]]*36' "$APP_GRADLE"; then
  echo "Android app targetSdk must be 36 for the current Play target requirement." >&2
  exit 1
fi
