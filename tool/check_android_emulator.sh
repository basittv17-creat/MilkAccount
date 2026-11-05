#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts
RAW_LOG="artifacts/android-logcat.txt"
FATAL_LOG="artifacts/fatal-logs.txt"
EXIT_INFO="artifacts/app-exit-info.txt"
CHECK_STATUS="artifacts/emulator-check-status.txt"
PACKAGE="com.awasigogera.milkaccount"

: > "$RAW_LOG"
: > "$FATAL_LOG"
: > "$EXIT_INFO"
: > "$CHECK_STATUS"

collect_diagnostics() {
  local script_status=$?
  trap - EXIT
  set +e

  # Preserve the complete emulator log so non-fatal startup errors and
  # process-death messages can be diagnosed, not just fatal exception lines.
  adb logcat -d -v threadtime > "$RAW_LOG" 2>&1
  grep -E -i -B 8 -A 60 "FATAL EXCEPTION|Fatal signal [0-9]+|am_crash|ANR in |has died|has crashed" "$RAW_LOG" > "$FATAL_LOG"

  # Android 11+ records why an app process exited (crash, ANR, low memory, etc.).
  adb shell dumpsys activity exit-info "$PACKAGE" > "$EXIT_INFO" 2>&1
  printf 'emulator_check_exit_code=%s\n' "$script_status" > "$CHECK_STATUS"

  exit "$script_status"
}
trap collect_diagnostics EXIT

adb logcat -c
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1

echo "Keeping the app running in the emulator for 4 minutes..."
sleep 240

adb logcat -d -v threadtime > "$RAW_LOG" 2>&1
if grep -E -i "FATAL EXCEPTION|Fatal signal [0-9]+|am_crash|ANR in |has died|has crashed" "$RAW_LOG"; then
  echo "Fatal crash, ANR, or app process death detected. See emulator diagnostics artifact." >&2
  exit 1
fi

if ! adb shell pidof "$PACKAGE" >/dev/null; then
  echo "App process is not running after the 4-minute emulator test." >&2
  exit 1
fi
