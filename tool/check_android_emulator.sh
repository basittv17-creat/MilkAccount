#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts
RAW_LOG="/tmp/milk-account-emulator-logcat.txt"
FATAL_LOG="artifacts/fatal-logs.txt"
FATAL_ZIP="artifacts/fatal-crash-logs.zip"

: > "$FATAL_LOG"

collect_fatal_logs() {
  adb logcat -d -v threadtime > "$RAW_LOG" 2>&1 || true
  grep -E -i -B 5 -A 40 "FATAL EXCEPTION|Fatal signal [0-9]+|am_crash|ANR in " "$RAW_LOG" > "$FATAL_LOG" || true
  rm -f "$FATAL_ZIP"
  zip -j -q "$FATAL_ZIP" "$FATAL_LOG"
  rm -f "$RAW_LOG"
}
trap collect_fatal_logs EXIT

adb logcat -c
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell monkey -p com.awasigogera.milkaccount -c android.intent.category.LAUNCHER 1

echo "Keeping the app running in the emulator for 4 minutes..."
sleep 240

adb logcat -d -v threadtime > "$RAW_LOG" 2>&1
if grep -E -i "FATAL EXCEPTION|Fatal signal [0-9]+|am_crash|ANR in " "$RAW_LOG"; then
  echo "Fatal crash or ANR detected. See the fatal crash ZIP artifact." >&2
  exit 1
fi

if ! adb shell pidof com.awasigogera.milkaccount >/dev/null; then
  echo "App process is not running after the 4-minute emulator test." >&2
  exit 1
fi
