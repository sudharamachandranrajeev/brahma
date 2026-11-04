#!/usr/bin/env bash
# Release workflow: installs the APK on the emulator, starts Udyoga and checks
# it is still up 20 s later with no crash or startup failure in the log.
# Leaves a screenshot and the log in $1.
set -euo pipefail

out=${1:-smoke}
mkdir -p "$out"
apk=$(ls dist/*.apk | head -n1)
adb install -r "$apk"
adb logcat -c
adb shell am start -W -n dev.brahma.udyoga/.MainActivity
sleep 20
adb exec-out screencap -p >"$out/android.png" || true
adb logcat -d >"$out/logcat.txt" || true

if ! adb shell pidof dev.brahma.udyoga >/dev/null; then
  grep -E 'AndroidRuntime|FATAL|flutter' "$out/logcat.txt" | tail -80 || true
  echo "::error::Udyoga is not running 20 s after it started"
  exit 1
fi
if grep -qE 'FATAL EXCEPTION|Unhandled Exception|Udyoga startup failed' "$out/logcat.txt"; then
  grep -E -A20 'FATAL EXCEPTION|Unhandled Exception|Udyoga startup failed' "$out/logcat.txt" | head -80
  echo "::error::Udyoga failed at start"
  exit 1
fi
grep -E ' flutter ' "$out/logcat.txt" | tail -20 || true
echo "Udyoga is up on the emulator"
