#!/usr/bin/env bash
# Downloads real SDK packages into a fresh directory on a disposable CI runner.
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export EXPO_LOCAL_DOCTOR_NO_MAIN=1
# shellcheck source=../expo-local-doctor
source "$ROOT_DIR/expo-local-doctor"
resolve_sdk_versions 58
integration_root=$(mktemp -d)
trap 'rm -rf "$integration_root"' EXIT
export ANDROID_HOME="$integration_root/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
# Prefer the downloaded tools over any Android SDK bundled with the CI image.
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
# The install branch must download its own sdkmanager and packages.
fix_android_sdk
MISSING=0
CHECKS_FAILED=0
check_android_sdk
[ "$MISSING" -eq 0 ]
[ "$CHECKS_FAILED" -eq 0 ]
# A second fix must reuse the existing installation, rather than download again.
fix_android_sdk > "$integration_root/repeated-fix.log" 2>&1
cat "$integration_root/repeated-fix.log"
grep -Fq 'Android SDK is already configured' "$integration_root/repeated-fix.log"
# Simulate an existing SDK missing the platform required by the target SDK.
# sdkmanager --uninstall also removes package metadata so repair is realistic.
sdkmanager --uninstall "platforms;${ANDROID_PLATFORM_VERSION}"
[ ! -d "$ANDROID_HOME/platforms/$ANDROID_PLATFORM_VERSION" ]
fix_android_sdk
[ -f "$ANDROID_HOME/platforms/$ANDROID_PLATFORM_VERSION/android.jar" ]
MISSING=0
CHECKS_FAILED=0
check_android_sdk
[ "$MISSING" -eq 0 ]
[ "$CHECKS_FAILED" -eq 0 ]
printf 'SDK 58 Android installation, reuse, and missing-platform repair passed.\n'
