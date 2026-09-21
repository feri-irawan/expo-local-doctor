# 🩺 expo-local-doctor

> Diagnose and fix your Expo/React Native local build environment on Linux — in one command.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](#supported-distros)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](expo-local-doctor)

Setting up a local Expo build environment on Linux can be tedious — you need Node.js, JDK, Android SDK, EAS CLI, environment variables, and more. **expo-local-doctor** checks everything for you and can auto-fix what's missing.

---

## ✨ Features

- 🔍 **One-command diagnostics** — instantly see what's missing or misconfigured
- 🛠️ **Auto-fix mode** — install all missing dependencies with `--fix`
- 🎯 **SDK-aware** — auto-detects Expo SDK 50–57 from `package.json` and checks the correct requirements
- 📦 **PM-aware** — detects your project's package manager (yarn, pnpm, bun) and checks it's installed
- 🛡️ **Firewall-aware** — checks UFW / Firewalld status and ensures port 8081 (Metro) is open for physical devices
- 🐧 **Multi-distro support** — works on Debian/Ubuntu, Fedora/RHEL, and Arch Linux
- 🏗️ **Architecture-aware** — handles x86_64, aarch64, and armv7l
- 🎨 **Colored output** — beautiful terminal output with auto-detection for piped/redirected output
- 📦 **Zero dependencies** — just Bash. No need to install anything first

---

## 🚀 Quick Start

### Run instantly (no file saved)

```bash
# Check mode
curl -fsSL https://raw.githubusercontent.com/feri-irawan/expo-local-doctor/main/expo-local-doctor | bash

# Fix mode
curl -fsSL https://raw.githubusercontent.com/feri-irawan/expo-local-doctor/main/expo-local-doctor | bash -s -- --fix
```

### Download & keep

```bash
curl -fsSL https://raw.githubusercontent.com/feri-irawan/expo-local-doctor/main/expo-local-doctor -o expo-local-doctor && chmod +x expo-local-doctor
```

### Git Clone

```bash
git clone https://github.com/feri-irawan/expo-local-doctor.git
cd expo-local-doctor
chmod +x expo-local-doctor
```

---

## 📖 Usage

### Check your system (default)

Run inside your Expo project directory — it auto-detects the SDK version:

```bash
./expo-local-doctor
```

**Example output:**
```
🔍 expo-local-doctor v1.3.1 — Checking system readiness...
ℹ  Detected: apt on x86_64
ℹ  Expo SDK: 57 (from ./package.json)
ℹ  Requirements: Node ≥22.13.0, JDK 17, android-36, build-tools 36.0.0
────────────────────────────────────────────────────────

📦 Basic Utilities & Build Tools
✅ curl is installed: /usr/bin/curl
✅ git is installed: /usr/bin/git
✅ unzip is installed: /usr/bin/unzip
✅ wget is installed: /usr/bin/wget
✅ Build essentials (gcc, make) are installed.

🟢 Node.js & Package Managers
✅ Node.js is installed: v22.13.0
✅ npm is installed: /usr/bin/npm

⚙️  EAS CLI
✅ eas is installed: /usr/bin/eas

☕ Java JDK (OpenJDK 17+ required)
✅ Java is installed: version 17
✅ JAVA_HOME is set: /usr/lib/jvm/java-17-openjdk-amd64

🤖 Android SDK (android-36, build-tools 36.0.0)
✅ ANDROID_HOME is set: /home/user/Android/Sdk
✅ cmdline-tools directory found.
✅ platform-tools directory found.
✅ build-tools 36.0.0 found.
✅ android-36 platform found.

👀 Watchman
✅ Watchman is installed.

🛡️  Firewall (UFW / Firewalld)
✅ UFW firewall is active. (Run with sudo to verify port 8081 rules)
ℹ  If LAN connection to Metro fails on physical devices, allow port 8081: sudo ufw allow 8081/tcp comment 'Expo'

────────────────────────────────────────────────────────
📋 Summary
   Passed:  17
   Warnings: 0
   Failed:  0
────────────────────────────────────────────────────────

✅ Your system is ready for Expo local builds! 🎉
```

### Auto-fix missing dependencies

```bash
./expo-local-doctor --fix
```

### Target a specific SDK version

```bash
# Check against SDK 57 requirements (even without a project)
./expo-local-doctor --sdk 57

# Auto-fix for a specific SDK
./expo-local-doctor --fix --sdk 57
```

### Other options

```bash
./expo-local-doctor --help      # Show help
./expo-local-doctor --version   # Show version
```

---

## 🔍 What Gets Checked

| Component | Details |
|---|---|
| **Basic Utilities** | `curl`, `git`, `unzip`, `wget`, `gcc`, `make` |
| **Node.js** | Exact minimum version per Expo SDK (e.g., ≥22.13.0 for SDK 57) |
| **npm** | Always required |
| **yarn / pnpm / bun** | Checked if detected as the project's package manager (via `packageManager` field or lock file) |
| **EAS CLI** | Expo Application Services CLI |
| **Java JDK** | OpenJDK 17+ |
| **JAVA_HOME** | Environment variable pointing to JDK; `--fix` writes an idempotent block to the active Bash, Zsh, or Fish profile |
| **Android SDK** | `ANDROID_HOME`, `cmdline-tools`, `platform-tools`, exact `build-tools` and platform per SDK |
| **adb in PATH** | Warns if `$ANDROID_HOME/platform-tools` is not on `$PATH` |
| **Watchman** | Recommended for Metro on Expo SDK 55 and earlier; not required on SDK 56+ |
| **Firewall** | UFW / Firewalld status & Metro port `8081` accessibility (active default Firewalld zone; container zones are skipped) |

> Version requirements are sourced from the [Expo SDK documentation](https://docs.expo.dev/versions/latest/) and automatically matched to your project.

If a project uses an Expo SDK not yet in the tool's version map, the command exits with an error instead of checking against a different SDK. Update `expo-local-doctor` first, then run it again.

---

## 🛠️ What `--fix` Installs

| Component | Method |
|---|---|
| Build essentials | System package manager (`apt`/`dnf`/`pacman`) |
| Node.js LTS | [NVM](https://github.com/nvm-sh/nvm) |
| EAS CLI | `npm install -g eas-cli` |
| OpenJDK 17 | System package manager |
| Android SDK | Official Google command-line tools |
| Watchman | System package manager when needed for Expo SDK 55 or earlier |
| Firewall | `sudo ufw allow 8081/tcp comment 'Expo'` or `firewall-cmd` |

---

## 🐧 Supported Distros

| Distribution | Package Manager | Status |
|---|---|---|
| Debian / Ubuntu | `apt` | ✅ Fully supported |
| Fedora / RHEL / CentOS | `dnf` | ✅ Fully supported |
| Arch Linux / Manjaro | `pacman` | ✅ Fully supported |

> Other distros with `apt`, `dnf`, or `pacman` should also work.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

Run the portable test harness before submitting a change:

```bash
bash -n expo-local-doctor tests/test.sh
bash tests/test.sh
```

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Supporting a new Expo SDK

The per-SDK requirements live in the `SDK_VERSION_MAP` table near the top of the
`expo-local-doctor` script. Each row is `sdk|min_node|min_jdk|compile_sdk|build_tools`.
`min_node` uses an exact semantic version. To add a new SDK, append a row (cross-checked against the
[Expo SDK docs](https://docs.expo.dev/versions/latest/)) and bump
`DEFAULT_SDK_VERSION` to the newest entry.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
