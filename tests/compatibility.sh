#!/usr/bin/env bash
# Exercise SDK detection independently of the machine's installed toolchain.
# Variables assigned here configure functions sourced from the doctor.
# shellcheck disable=SC2034
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export EXPO_LOCAL_DOCTOR_NO_MAIN=1
# shellcheck source=../expo-local-doctor
source "$ROOT_DIR/expo-local-doctor"
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT

for sdk in 50 51 52 53 54 55 56 57 58; do
    mkdir -p "$fixture_dir/$sdk"
    printf '{"dependencies":{"expo":"~%s.0.0"}}\n' "$sdk" > "$fixture_dir/$sdk/package.json"
    (
        cd "$fixture_dir/$sdk"
        USER_SDK_OVERRIDE=''
        PROJECT_PKG_MANAGER=''
        detect_project
        [ "$DETECTED_SDK_VERSION" = "$sdk" ]
        [ -n "$ANDROID_PLATFORM_VERSION" ]
        [ -n "$ANDROID_BUILD_TOOLS_VERSION" ]
        [ -n "$ANDROID_NDK_VERSION" ]
        node_version_supported "$MIN_NODE_VERSION"
        printf 'SDK %s: detection and minimum Node passed\n' "$sdk"
    )
done

# Optional CI argument checks a real Node binary installed by setup-node.
if [ "$#" -gt 0 ]; then
    resolve_sdk_versions 58
    node_actual=$(node --version)
    if node_version_supported "$node_actual"; then node_result=supported; else node_result=unsupported; fi
    if [ "$node_result" != "$1" ]; then
        printf 'Node %s: expected %s, got %s\n' "$node_actual" "$1" "$node_result" >&2
        exit 1
    fi
    printf 'SDK 58 with real Node %s: %s\n' "$node_actual" "$node_result"
fi
