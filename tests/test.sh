#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/expo-local-doctor"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

PASS=0
FAIL=0

test_pass() { printf 'ok - %s\n' "$1"; PASS=$((PASS + 1)); }
test_fail() { printf 'not ok - %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then test_pass "$label"; else test_fail "$label"; fi
}
assert_equals() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then test_pass "$label"; else test_fail "$label (expected '$expected', got '$actual')"; fi
}

export EXPO_LOCAL_DOCTOR_NO_MAIN=1
# shellcheck source=../expo-local-doctor
source "$SCRIPT"

version_at_least "22.13.0" "22.13.0" && test_pass "Node version exactly at SDK 57 minimum passes" || test_fail "Node version exactly at SDK 57 minimum passes"
if version_at_least "22.0.0" "22.13.0"; then test_fail "Node below SDK 57 minimum fails"; else test_pass "Node below SDK 57 minimum fails"; fi
version_at_least "24.0.0" "22.13.0" && test_pass "Node above SDK 57 minimum passes" || test_fail "Node above SDK 57 minimum passes"

mkdir -p "$TEMP_DIR/sdk57-project"
printf '{"dependencies":{"expo":"~57.0.23"}}\n' > "$TEMP_DIR/sdk57-project/package.json"
(
    cd "$TEMP_DIR/sdk57-project"
    USER_SDK_OVERRIDE=""
    PROJECT_PKG_MANAGER=""
    detect_project
    assert_equals "$DETECTED_SDK_VERSION" "57" "SDK 57 is detected from package.json"
    assert_equals "$MIN_NODE_VERSION" "22.13.0" "SDK 57 uses exact Node minimum"
)

mkdir -p "$TEMP_DIR/no-project"
(
    cd "$TEMP_DIR/no-project"
    USER_SDK_OVERRIDE=""
    PROJECT_PKG_MANAGER=""
    detect_project
    assert_equals "$DETECTED_SDK_VERSION" "57" "No-project fallback uses SDK 57"
)

unset EXPO_LOCAL_DOCTOR_NO_MAIN
set +e
unknown_output=$("$SCRIPT" --sdk 58 2>&1)
unknown_status=$?
set -e
assert_equals "$unknown_status" "2" "Unknown --sdk exits with code 2"
assert_contains "$unknown_output" "Expo SDK 58 is not supported" "Unknown --sdk explains the failure"

mkdir -p "$TEMP_DIR/sdk58-project"
printf '{"dependencies":{"expo":"^58.0.0"}}\n' > "$TEMP_DIR/sdk58-project/package.json"
set +e
unknown_project_output=$(cd "$TEMP_DIR/sdk58-project" && "$SCRIPT" 2>&1)
unknown_project_status=$?
set -e
assert_equals "$unknown_project_status" "2" "Unknown project SDK exits with code 2"
assert_contains "$unknown_project_output" "found in $TEMP_DIR/sdk58-project/package.json" "Unknown project SDK identifies package.json source"

for shell_name in bash zsh fish; do
    profile_home="$TEMP_DIR/home-$shell_name"
    case "$shell_name" in
        bash) profile="$profile_home/.bashrc" ;;
        zsh) profile="$profile_home/.zshrc" ;;
        fish) profile="$profile_home/.config/fish/config.fish" ;;
    esac
    mkdir -p "$(dirname "$profile")"
    printf '%s\n%s\n%s\n%s\n' 'export USER_SETTING=preserved' '# >>> expo-local-doctor >>>' 'stale owned block' '# <<< expo-local-doctor <<<' > "$profile"
    HOME="$profile_home" SHELL="/bin/$shell_name" configure_shell_profile "/tmp/jdk-$shell_name" "/tmp/android-$shell_name" "/tmp/android-$shell_name/cmdline-tools/12.0/bin"
    HOME="$profile_home" SHELL="/bin/$shell_name" configure_shell_profile "/tmp/jdk-$shell_name" "/tmp/android-$shell_name" "/tmp/android-$shell_name/cmdline-tools/12.0/bin"
    assert_equals "$(grep -c '^# >>> expo-local-doctor >>>$' "$profile")" "1" "$shell_name profile block is idempotent"
    assert_contains "$(<"$profile")" "USER_SETTING=preserved" "$shell_name profile preserves user content"
    assert_contains "$(<"$profile")" "ANDROID_HOME" "$shell_name profile contains Android environment"
    assert_contains "$(<"$profile")" "cmdline-tools/12.0/bin" "$shell_name profile preserves versioned command-line tools path"
done

malformed_home="$TEMP_DIR/home-malformed"
mkdir -p "$malformed_home"
printf '%s\n%s\n' 'export USER_SETTING=preserved' '# >>> expo-local-doctor >>>' > "$malformed_home/.bashrc"
if HOME="$malformed_home" SHELL="/bin/bash" configure_shell_profile "/tmp/jdk" "/tmp/android" "/tmp/android/cmdline-tools/latest/bin"; then
    test_fail "Malformed profile block is rejected"
else
    test_pass "Malformed profile block is rejected"
fi
assert_contains "$(<"$malformed_home/.bashrc")" "USER_SETTING=preserved" "Malformed profile content is untouched"

FAKE_BIN="$TEMP_DIR/fake-bin"
mkdir -p "$FAKE_BIN"

printf '%s\n' '#!/usr/bin/env bash' '[ "${3:-}" = "firewalld" ] && exit 0' 'exit 1' > "$FAKE_BIN/systemctl"
printf '%s\n' '#!/usr/bin/env bash' '[ "${1:-}" = "-n" ] && shift' 'exec "$@"' > "$FAKE_BIN/sudo"
printf '%s\n' '#!/usr/bin/env bash' \
    '[ -n "${FIREWALL_LOG:-}" ] && printf "%s\\n" "$*" >> "$FIREWALL_LOG"' \
    'case " $* " in' \
    '  *" --get-active-zones "*) printf "work (default)\\n  interfaces: eth0\\n" ;;' \
    '  *" --add-port=8081/tcp --permanent "*) touch "$FIREWALL_STATE" ;;' \
    '  *" --list-ports "*) [ "${FIREWALL_MODE:-check}" = "check" ] || [ -f "${FIREWALL_STATE:-}" ] && printf "8081/tcp\\n" ;;' \
    '  *) exit 0 ;;' \
    'esac' > "$FAKE_BIN/firewall-cmd"
printf '%s\n' '#!/usr/bin/env bash' 'printf "v%s\\n" "${NODE_FIXTURE:-22.13.0}"' > "$FAKE_BIN/node"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FAKE_BIN/npm"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "17.0.15"'\'' >&2' > "$FAKE_BIN/java"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FAKE_BIN/adb"
chmod +x "$FAKE_BIN/systemctl" "$FAKE_BIN/sudo" "$FAKE_BIN/firewall-cmd"
chmod +x "$FAKE_BIN/node" "$FAKE_BIN/npm" "$FAKE_BIN/java" "$FAKE_BIN/adb"

node_old_output=$(PATH="$FAKE_BIN:$PATH" NODE_FIXTURE="22.0.0" MIN_NODE_VERSION="22.13.0" DETECTED_SDK_VERSION="57" check_node)
assert_contains "$node_old_output" "v22.13.0+ is required" "Node check rejects a version below the patch minimum"
node_exact_output=$(PATH="$FAKE_BIN:$PATH" NODE_FIXTURE="22.13.0" MIN_NODE_VERSION="22.13.0" DETECTED_SDK_VERSION="57" check_node)
assert_contains "$node_exact_output" "Node.js is installed: v22.13.0" "Node check accepts the exact minimum"

FAKE_JAVA_HOME="$TEMP_DIR/fake-jdk"
mkdir -p "$FAKE_JAVA_HOME"
java_output=$(PATH="$FAKE_BIN:$PATH" JAVA_HOME="$FAKE_JAVA_HOME" MIN_JDK_VERSION="17" check_java)
assert_contains "$java_output" "Java is installed: version 17" "Java check uses an isolated Java executable"

FAKE_ANDROID_HOME="$TEMP_DIR/fake-android-sdk"
mkdir -p "$FAKE_ANDROID_HOME/cmdline-tools/latest/bin" "$FAKE_ANDROID_HOME/platform-tools" \
    "$FAKE_ANDROID_HOME/build-tools/36.0.0" "$FAKE_ANDROID_HOME/platforms/android-36"
android_output=$(PATH="$FAKE_BIN:$PATH" ANDROID_HOME="$FAKE_ANDROID_HOME" ANDROID_PLATFORM_VERSION="android-36" ANDROID_BUILD_TOOLS_VERSION="36.0.0" check_android_sdk)
assert_contains "$android_output" "android-36 platform found" "Android SDK check uses an isolated SDK fixture"

FIREWALL_LOG="$TEMP_DIR/check-firewall.log"
firewall_output=$(PATH="$FAKE_BIN:$PATH" FIREWALL_LOG="$FIREWALL_LOG" check_firewall)
assert_contains "$firewall_output" "zone 'work' allows port 8081/tcp" "Firewalld checks the active interface zone"
assert_contains "$(<"$FIREWALL_LOG")" '--zone=work --list-ports' "Firewalld checks runtime ports in the active zone"
assert_contains "$(<"$FIREWALL_LOG")" '--permanent --zone=work --list-ports' "Firewalld checks permanent ports in the active zone"

FIREWALL_LOG="$TEMP_DIR/fix-firewall.log"
FIREWALL_STATE="$TEMP_DIR/fix-firewall.state"
PATH="$FAKE_BIN:$PATH" FIREWALL_MODE="fix" FIREWALL_LOG="$FIREWALL_LOG" FIREWALL_STATE="$FIREWALL_STATE" fix_firewall
assert_contains "$(<"$FIREWALL_LOG")" '--zone=work --add-port=8081/tcp --permanent' "Fix firewall adds permanent rule to active zone"
assert_contains "$(<"$FIREWALL_LOG")" '--reload' "Fix firewall reloads after changing permanent rules"

NOOP_MARKER="$TEMP_DIR/unsupported-fix.marker"
printf '%s\n' '#!/usr/bin/env bash' 'touch "$NOOP_MARKER"' > "$FAKE_BIN/dnf"
chmod +x "$FAKE_BIN/dnf"
set +e
noop_output=$(PATH="$FAKE_BIN:$PATH" NOOP_MARKER="$NOOP_MARKER" "$SCRIPT" --fix --sdk 58 2>&1)
noop_status=$?
set -e
assert_equals "$noop_status" "2" "Unsupported SDK --fix exits before fixes"
[ ! -e "$NOOP_MARKER" ] && test_pass "Unsupported SDK --fix performs no package-manager mutation" || test_fail "Unsupported SDK --fix performs no package-manager mutation"

help_output=$("$SCRIPT" --help)
version_output=$("$SCRIPT" --version)
assert_contains "$help_output" "50, 51, 52, 53, 54, 55, 56, 57" "Help lists SDK 57"
assert_equals "$version_output" "expo-local-doctor v1.3.0" "Version smoke test"

if [ "$FAIL" -gt 0 ]; then
    printf '%s test(s) failed; %s passed\n' "$FAIL" "$PASS" >&2
    exit 1
fi
printf '%s test(s) passed\n' "$PASS"
