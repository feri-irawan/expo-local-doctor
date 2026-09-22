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
export TERM=dumb
# shellcheck source=../expo-local-doctor
source "$SCRIPT"
RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''

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
    mkdir -p android
    printf '%s\n' 'android { ndkVersion "26.1.10909125" }' > android/build.gradle
    detect_project_ndk_override
    assert_equals "$ANDROID_NDK_VERSION" "26.1.10909125" "Literal Gradle NDK override is detected"
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

symlink_home="$TEMP_DIR/home-symlink"
mkdir -p "$symlink_home/dotfiles"
target_file="$symlink_home/dotfiles/bashrc"
printf '%s\n' 'export USER_SETTING=preserved' > "$target_file"
ln -s "$target_file" "$symlink_home/.bashrc"
HOME="$symlink_home" SHELL="/bin/bash" configure_shell_profile "/tmp/jdk" "/tmp/android" "/tmp/android/cmdline-tools/latest/bin"
[ -L "$symlink_home/.bashrc" ] && test_pass "configure_shell_profile preserves symbolic links" || test_fail "configure_shell_profile preserves symbolic links"
assert_contains "$(<"$target_file")" "export JAVA_HOME=\"/tmp/jdk\"" "configure_shell_profile writes through symlinks to target"


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
    '  *" --get-active-zones "*) printf "work (default)\\n  interfaces: eth0\\ndocker\\n  interfaces: docker0\\n" ;;' \
    '  *" --get-default-zone "*) printf "work\\n" ;;' \
    '  *" --add-port=8081/tcp --permanent "*) touch "$FIREWALL_STATE" ;;' \
    '  *" --list-ports "*) if [ "${FIREWALL_MODE:-check}" = "range" ]; then printf "1025-65535/tcp\\n"; elif [ "${FIREWALL_MODE:-check}" = "check" ] || [ -f "${FIREWALL_STATE:-}" ]; then printf "8081/tcp\\n"; fi ;;' \
    '  *) exit 0 ;;' \
    'esac' > "$FAKE_BIN/firewall-cmd"
printf '%s\n' '#!/usr/bin/env bash' 'printf "v%s\\n" "${NODE_FIXTURE:-22.13.0}"' > "$FAKE_BIN/node"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FAKE_BIN/npm"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "17.0.15"'\'' >&2' > "$FAKE_BIN/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "javac ${JAVAC_FIXTURE:-17.0.15}" >&2' > "$FAKE_BIN/javac"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FAKE_BIN/adb"
chmod +x "$FAKE_BIN/systemctl" "$FAKE_BIN/sudo" "$FAKE_BIN/firewall-cmd"
chmod +x "$FAKE_BIN/node" "$FAKE_BIN/npm" "$FAKE_BIN/java" "$FAKE_BIN/javac" "$FAKE_BIN/adb"

node_old_output=$(PATH="$FAKE_BIN:$PATH" NODE_FIXTURE="22.0.0" MIN_NODE_VERSION="22.13.0" DETECTED_SDK_VERSION="57" check_node)
assert_contains "$node_old_output" "v22.13.0+ is required" "Node check rejects a version below the patch minimum"
node_exact_output=$(PATH="$FAKE_BIN:$PATH" NODE_FIXTURE="22.13.0" MIN_NODE_VERSION="22.13.0" DETECTED_SDK_VERSION="57" check_node)
assert_contains "$node_exact_output" "Node.js is installed: v22.13.0" "Node check accepts the exact minimum"

watchman_sdk57_output=$(PATH="$FAKE_BIN" DETECTED_SDK_VERSION="57" check_watchman)
assert_contains "$watchman_sdk57_output" "not required for Expo SDK 56+" "Watchman is non-blocking for SDK 57"
if [[ "$watchman_sdk57_output" == *"⚠️"* ]]; then test_fail "SDK 57 Watchman check has no warning"; else test_pass "SDK 57 Watchman check has no warning"; fi
watchman_fix_sdk57_output=$(PATH="$FAKE_BIN" DETECTED_SDK_VERSION="57" fix_watchman)
assert_contains "$watchman_fix_sdk57_output" "skipping installation" "SDK 57 fix mode skips Watchman installation"

FAKE_JAVA_HOME="$TEMP_DIR/fake-jdk"
mkdir -p "$FAKE_JAVA_HOME/bin"
ln -s "$FAKE_BIN/javac" "$FAKE_JAVA_HOME/bin/javac"
ln -s "$FAKE_BIN/java" "$FAKE_JAVA_HOME/bin/java"
java_output=$(PATH="$FAKE_BIN:$PATH" JAVA_HOME="$FAKE_JAVA_HOME" MIN_JDK_VERSION="17" check_java)
assert_contains "$java_output" "Java is installed: version 17" "Java check uses an isolated Java executable"
assert_contains "$java_output" "Java compiler is installed: version 17.0.15" "Java check requires an isolated javac compiler"

FAKE_JAVA_NO_JAVA="$TEMP_DIR/fake-jdk-no-java"
mkdir -p "$FAKE_JAVA_NO_JAVA/bin"
ln -s "$FAKE_BIN/javac" "$FAKE_JAVA_NO_JAVA/bin/javac"
java_no_java_output=$(PATH="$FAKE_BIN:$PATH" JAVA_HOME="$FAKE_JAVA_NO_JAVA" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" check_java)
assert_contains "$java_no_java_output" "JAVA_HOME points to '$FAKE_JAVA_NO_JAVA', but it does not contain bin/java." "Java check fails when JAVA_HOME lacks bin/java"

JAVA_HIGH_BIN="$TEMP_DIR/java-high-bin"
mkdir -p "$JAVA_HIGH_BIN"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "25.0.4.1"'\'' >&2' > "$JAVA_HIGH_BIN/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "javac 25.0.4.1" >&2' > "$JAVA_HIGH_BIN/javac"
chmod +x "$JAVA_HIGH_BIN/java" "$JAVA_HIGH_BIN/javac"
java_high_output=$(PATH="$JAVA_HIGH_BIN:$PATH" JAVA_HOME="" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" check_java)
assert_contains "$java_high_output" "Java 25 is installed, but version 17-21 is required" "Java check rejects versions above maximum supported JDK"
assert_contains "$java_high_output" "Java compiler version 25.0.4 is installed, but version 17-21 is required" "Java check rejects javac versions above maximum supported JDK"

JAVA_11_BIN="$TEMP_DIR/java-11-bin"
mkdir -p "$JAVA_11_BIN"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "11.0.22"'\'' >&2' > "$JAVA_11_BIN/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "javac 11.0.22" >&2' > "$JAVA_11_BIN/javac"
chmod +x "$JAVA_11_BIN/java" "$JAVA_11_BIN/javac"
java_11_output=$(PATH="$JAVA_11_BIN:$PATH" JAVA_HOME="" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" check_java)
assert_contains "$java_11_output" "Java 11 is installed, but version 17-21 is required" "Java check rejects versions below minimum supported JDK"
assert_contains "$java_11_output" "Java compiler version 11.0.22 is installed, but version 17-21 is required" "Java check rejects javac versions below minimum supported JDK"

JAVA_OPTS_BIN="$TEMP_DIR/java-opts-bin"
mkdir -p "$JAVA_OPTS_BIN"
printf '%s\n' '#!/usr/bin/env bash' 'echo "Picked up JAVA_TOOL_OPTIONS: -Xmx2048m -Dfile.encoding=UTF-8" >&2' 'echo '\''openjdk version "17.0.15"'\'' >&2' > "$JAVA_OPTS_BIN/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "Picked up JAVA_TOOL_OPTIONS: -Xmx2048m" >&2' 'echo "javac 17.0.15" >&2' > "$JAVA_OPTS_BIN/javac"
chmod +x "$JAVA_OPTS_BIN/java" "$JAVA_OPTS_BIN/javac"
java_opts_output=$(PATH="$JAVA_OPTS_BIN:$PATH" JAVA_HOME="" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" check_java)
assert_contains "$java_opts_output" "Java is installed: version 17" "Java check extracts version despite JAVA_TOOL_OPTIONS noise"
assert_contains "$java_opts_output" "Java compiler is installed: version 17.0.15" "Java check extracts javac version despite JAVA_TOOL_OPTIONS with numbers"

JAVA_21_BIN="$TEMP_DIR/java-21-bin"
mkdir -p "$JAVA_21_BIN"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "21.0.6"'\'' >&2' > "$JAVA_21_BIN/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "javac 21.0.6" >&2' > "$JAVA_21_BIN/javac"
chmod +x "$JAVA_21_BIN/java" "$JAVA_21_BIN/javac"
java_21_output=$(PATH="$JAVA_21_BIN:$PATH" JAVA_HOME="" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" check_java)
assert_contains "$java_21_output" "Java is installed: version 21" "Java check accepts JDK 21 LTS"
assert_contains "$java_21_output" "Java compiler is installed: version 21.0.6" "Java check accepts javac 21 LTS"

FAKE_JAVA25_HOME="$TEMP_DIR/fake-java25-home"
mkdir -p "$FAKE_JAVA25_HOME/bin"
ln -s "$JAVA_HIGH_BIN/javac" "$FAKE_JAVA25_HOME/bin/javac"
ln -s "$JAVA_HIGH_BIN/java" "$FAKE_JAVA25_HOME/bin/java"
java_home_bad_output=$(PATH="$FAKE_BIN:$PATH" JAVA_HOME="$FAKE_JAVA25_HOME" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" check_java)
assert_contains "$java_home_bad_output" "JAVA_HOME points to '$FAKE_JAVA25_HOME' (version 25), but version 17-21 is required" "Java check rejects JAVA_HOME with incompatible version"

DISCOVERY_DIR="$TEMP_DIR/mock-discovery"
mkdir -p "$DISCOVERY_DIR/temurin-17-jdk/bin" "$DISCOVERY_DIR/java-25-openjdk/bin"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "17.0.14"'\'' >&2' > "$DISCOVERY_DIR/temurin-17-jdk/bin/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "javac 17.0.14" >&2' > "$DISCOVERY_DIR/temurin-17-jdk/bin/javac"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "25.0.4.1"'\'' >&2' > "$DISCOVERY_DIR/java-25-openjdk/bin/java"
printf '%s\n' '#!/usr/bin/env bash' 'echo "javac 25.0.4.1" >&2' > "$DISCOVERY_DIR/java-25-openjdk/bin/javac"
chmod +x "$DISCOVERY_DIR/temurin-17-jdk/bin/java" "$DISCOVERY_DIR/temurin-17-jdk/bin/javac" \
         "$DISCOVERY_DIR/java-25-openjdk/bin/java" "$DISCOVERY_DIR/java-25-openjdk/bin/javac"
found_jdk_val=$(JAVA_HOME="$DISCOVERY_DIR/temurin-17-jdk" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" find_compatible_jdk_home)
assert_equals "$found_jdk_val" "$DISCOVERY_DIR/temurin-17-jdk" "find_compatible_jdk_home validates compatible JAVA_HOME"
found_active_val=$(JAVA_HOME="" PATH="$DISCOVERY_DIR/temurin-17-jdk/bin:$PATH" MIN_JDK_VERSION="17" MAX_JDK_VERSION="21" find_compatible_jdk_home)
assert_equals "$found_active_val" "$DISCOVERY_DIR/temurin-17-jdk" "find_compatible_jdk_home discovers active compatible java"

JAVA_ONLY_BIN="$TEMP_DIR/java-only-bin"
mkdir -p "$JAVA_ONLY_BIN" "$TEMP_DIR/fake-jre"
printf '%s\n' '#!/usr/bin/env bash' 'echo '\''openjdk version "17.0.15"'\'' >&2' > "$JAVA_ONLY_BIN/java"
chmod +x "$JAVA_ONLY_BIN/java"
ln -s /usr/bin/grep "$JAVA_ONLY_BIN/grep"
ln -s /usr/bin/head "$JAVA_ONLY_BIN/head"
java_runtime_only_output=$(PATH="$JAVA_ONLY_BIN" JAVA_HOME="$TEMP_DIR/fake-jre" MIN_JDK_VERSION="17" check_java)
assert_contains "$java_runtime_only_output" "Java compiler (javac) is not installed" "Java runtime-only installation fails readiness"

FAKE_ANDROID_HOME="$TEMP_DIR/fake-android-sdk"
mkdir -p "$FAKE_ANDROID_HOME/cmdline-tools/latest/bin" "$FAKE_ANDROID_HOME/platform-tools" \
    "$FAKE_ANDROID_HOME/build-tools/36.0.0" "$FAKE_ANDROID_HOME/platforms/android-36" \
    "$FAKE_ANDROID_HOME/ndk/27.1.12297006" "$FAKE_ANDROID_HOME/ndk/27.0.12077973/.installer" \
    "$FAKE_ANDROID_HOME/ndk/backup/.installer"
printf '%s\n' 'Pkg.Revision= 27.1.12297006' > "$FAKE_ANDROID_HOME/ndk/27.1.12297006/source.properties"
android_output=$(PATH="$FAKE_BIN:$PATH" ANDROID_HOME="$FAKE_ANDROID_HOME" ANDROID_PLATFORM_VERSION="android-36" ANDROID_BUILD_TOOLS_VERSION="36.0.0" ANDROID_NDK_VERSION="27.1.12297006" check_android_sdk)
assert_contains "$android_output" "android-36 platform found" "Android SDK check uses an isolated SDK fixture"
assert_contains "$android_output" "NDK 27.1.12297006 found" "Android SDK check validates the required NDK revision"
assert_contains "$android_output" "Incomplete NDK installations detected: 27.0.12077973" "Android SDK check reports incomplete NDK directories"
clean_incomplete_ndk_dirs "$FAKE_ANDROID_HOME/ndk"
[ ! -d "$FAKE_ANDROID_HOME/ndk/27.0.12077973" ] && test_pass "Fix removes only incomplete NDK directories" || test_fail "Fix removes only incomplete NDK directories"
[ -d "$FAKE_ANDROID_HOME/ndk/backup" ] && test_pass "Fix preserves non-version NDK directories" || test_fail "Fix preserves non-version NDK directories"

FIREWALL_LOG="$TEMP_DIR/check-firewall.log"
firewall_output=$(PATH="$FAKE_BIN:$PATH" FIREWALL_LOG="$FIREWALL_LOG" check_firewall)
assert_contains "$firewall_output" "default zone 'work' allows port 8081/tcp" "Firewalld checks the active default zone"
assert_contains "$(<"$FIREWALL_LOG")" '--zone=work --list-ports' "Firewalld checks runtime ports in the active zone"
assert_contains "$(<"$FIREWALL_LOG")" '--permanent --zone=work --list-ports' "Firewalld checks permanent ports in the active zone"
if grep -q -- '--zone=docker' "$FIREWALL_LOG"; then test_fail "Firewalld skips container zones"; else test_pass "Firewalld skips container zones"; fi

range_firewall_output=$(PATH="$FAKE_BIN:$PATH" FIREWALL_MODE="range" check_firewall)
assert_contains "$range_firewall_output" "default zone 'work' allows port 8081/tcp" "Firewalld recognizes a port range covering Metro"

FIREWALL_LOG="$TEMP_DIR/fix-firewall.log"
FIREWALL_STATE="$TEMP_DIR/fix-firewall.state"
PATH="$FAKE_BIN:$PATH" FIREWALL_MODE="fix" FIREWALL_LOG="$FIREWALL_LOG" FIREWALL_STATE="$FIREWALL_STATE" fix_firewall
assert_contains "$(<"$FIREWALL_LOG")" '--zone=work --add-port=8081/tcp --permanent' "Fix firewall adds permanent rule to default zone"
assert_contains "$(<"$FIREWALL_LOG")" '--reload' "Fix firewall reloads after changing permanent rules"
if grep -q -- '--zone=docker' "$FIREWALL_LOG"; then test_fail "Fix firewall skips container zones"; else test_pass "Fix firewall skips container zones"; fi

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
assert_equals "$version_output" "expo-local-doctor v1.3.5" "Version smoke test"

if [ "$FAIL" -gt 0 ]; then
    printf '%s test(s) failed; %s passed\n' "$FAIL" "$PASS" >&2
    exit 1
fi
printf '%s test(s) passed\n' "$PASS"
