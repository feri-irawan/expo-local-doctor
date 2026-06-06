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

```bash
./expo-local-doctor
```

**Example output:**
```
🔍 expo-local-doctor v1.0.0 — Checking system readiness...
ℹ  Detected: apt on x86_64
────────────────────────────────────────────────────────

📦 Basic Utilities & Build Tools
✅ curl is installed: /usr/bin/curl
✅ git is installed: /usr/bin/git
✅ unzip is installed: /usr/bin/unzip
✅ wget is installed: /usr/bin/wget
✅ Build essentials (gcc, make) are installed.

🟢 Node.js & Ecosystem
✅ Node.js is installed: v20.11.0
✅ npm is installed: /usr/bin/npm

⚙️  EAS CLI
✅ eas is installed: /usr/bin/eas

☕ Java JDK (OpenJDK 17+ required)
✅ Java is installed: version 17
✅ JAVA_HOME is set: /usr/lib/jvm/java-17-openjdk-amd64

🤖 Android SDK
✅ ANDROID_HOME is set: /home/user/Android/Sdk
✅ cmdline-tools directory found.
✅ platform-tools directory found.
✅ build-tools directory found.
✅ Android platform(s) found.

👀 Watchman
✅ Watchman is installed.

────────────────────────────────────────────────────────
📋 Summary
   Passed:  15
   Warnings: 0
   Failed:  0
────────────────────────────────────────────────────────

✅ Your system is ready for Expo local builds! 🎉
```

### Auto-fix missing dependencies

```bash
./expo-local-doctor --fix
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
| **Node.js** | Version 18+ (LTS recommended) |
| **npm** | Node package manager |
| **EAS CLI** | Expo Application Services CLI |
| **Java JDK** | OpenJDK 17+ |
| **JAVA_HOME** | Environment variable pointing to JDK |
| **Android SDK** | `ANDROID_HOME`, `cmdline-tools`, `platform-tools`, `build-tools`, platforms |
| **Watchman** | Optional, recommended for Metro bundler performance |

---

## 🛠️ What `--fix` Installs

| Component | Method |
|---|---|
| Build essentials | System package manager (`apt`/`dnf`/`pacman`) |
| Node.js LTS | [NVM](https://github.com/nvm-sh/nvm) |
| EAS CLI | `npm install -g eas-cli` |
| OpenJDK 17 | System package manager |
| Android SDK | Official Google command-line tools |
| Watchman | System package manager (when available) |

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

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

