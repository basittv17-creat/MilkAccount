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
SETTINGS="android/settings.gradle.kts"
WRAPPER="android/gradle/wrapper/gradle-wrapper.properties"
if [[ -f "$SETTINGS" ]]; then
  sed -i -E 's/(com\\.android\\.application.*version ")9\\.[^"]+(".*)/\\18.11.1\\2/' "$SETTINGS"
  if grep -q 'com.android.application.*version "9\\.' "$SETTINGS"; then
    echo "Could not pin Android Gradle Plugin below 9." >&2; exit 1
  fi
else
  echo "Missing generated Gradle settings file: $SETTINGS" >&2; exit 1
fi
if [[ -f "$WRAPPER" ]]; then
  sed -i -E 's#gradle-9\\.[^/]+-all\\.zip#gradle-8.13-all.zip#' "$WRAPPER"
  grep -Fq 'gradle-8.13-all.zip' "$WRAPPER" || { echo "Could not pin Gradle 8.13." >&2; exit 1; }
else
  echo "Missing generated Gradle wrapper properties file: $WRAPPER" >&2; exit 1
fi

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
