#!/usr/bin/env bash
set -euo pipefail

# The repository keeps Flutter's app source as the source of truth.
# Generate platform scaffolding with the same stable Flutter SDK used by CI.
if [[ ! -d android || ! -f web/index.html ]]; then
  flutter create \
    --platforms=android,web \
    --project-name milk_account \
    --org com.milkaccount \
    .
else
  echo "Android and Web platform folders already exist; leaving them unchanged."
fi

# Keep the generated app compatible with Android plugins that require API 36.
# compileSdk is a build-time setting; minSdk/targetSdk remain unchanged.
APP_GRADLE="android/app/build.gradle.kts"
if [[ -f "$APP_GRADLE" ]]; then
  if grep -q 'compileSdk = flutter.compileSdkVersion' "$APP_GRADLE"; then
    sed -i 's/compileSdk = flutter\.compileSdkVersion/compileSdk = 36/' "$APP_GRADLE"
  elif ! grep -qE 'compileSdk[[:space:]]*=[[:space:]]*36' "$APP_GRADLE"; then
    echo "Could not safely set Android compileSdk to 36 in $APP_GRADLE" >&2
    exit 1
  fi
fi

# Add the runtime permission required for explicitly opted-in direct SMS sending.
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]] && ! grep -q 'android.permission.SEND_SMS' "$MANIFEST"; then
  sed -i '/<application/i\\    <uses-permission android:name="android.permission.SEND_SMS" />\\n    <uses-feature android:name="android.hardware.telephony" android:required="false" />' "$MANIFEST"
fi

# Keep legacy Android Gradle DSL enabled for plugins that still cast Android
# source sets to the legacy AndroidLibrarySourceSet API (telephony_sms 0.1.0).
# Flutter's newer Android DSL otherwise causes a ClassCastException in that plugin.
GRADLE_PROPERTIES="android/gradle.properties"
if [[ -f "$GRADLE_PROPERTIES" ]]; then
  grep -q '^android.newDsl=' "$GRADLE_PROPERTIES" || printf '\nandroid.newDsl=false\n' >> "$GRADLE_PROPERTIES"
  grep -q '^android.builtInKotlin=' "$GRADLE_PROPERTIES" || printf 'android.builtInKotlin=false\n' >> "$GRADLE_PROPERTIES"
else
  echo "Missing generated Gradle properties file: $GRADLE_PROPERTIES" >&2
  exit 1
fi

# Fail early if the generated application Gradle file did not receive API 36.
if [[ ! -f "$APP_GRADLE" ]] || ! grep -qE 'compileSdk[[:space:]]*=[[:space:]]*36' "$APP_GRADLE"; then
  echo "Android app compileSdk must be 36; generated configuration is not correct." >&2
  exit 1
fi
