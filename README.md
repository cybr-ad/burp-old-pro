# 🚀 Burp Suite Professional — Easy Setup

<div align="center">

[![OS - Kali | Debian | Ubuntu](https://img.shields.io/badge/OS-Kali%20%7C%20Debian%20%7C%20Ubuntu-1793d1?style=for-the-badge&logo=linux&logoColor=white)](https://www.kali.org/)
[![Modern - JDK 17-26](https://img.shields.io/badge/Modern%20Burp-JDK%2017--26-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)](https://portswigger.net/burp)
[![Legacy - Java 8](https://img.shields.io/badge/Legacy%20v1.7.37-Java%208-007396?style=for-the-badge&logo=java&logoColor=white)](https://portswigger.net/burp)
[![Bash - 100% Automated](https://img.shields.io/badge/Installer-100%25%20Automated-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

**Automated, one-command installer for Burp Suite Professional on Kali Linux & Debian.**  
*Includes automatic Java installation, official downloads, desktop shortcuts, and auto-trust fixes.*

[⚡ Quick Start](#-quick-start) • [🔑 Easy Activation](#-3-step-activation) • [🖥️ How to Launch](#-how-to-launch) • [📊 Versions](#-which-version-should-i-use) • [❓ Quick Fixes](#-quick-fixes)

</div>

---

## ⚡ Quick Start

Open your terminal and run:

```bash
# 1. Clone repository
git clone https://github.com/cybr-ad/burp-old-pro.git
cd burp-old-pro

# 2. Make scripts executable
chmod +x *.sh
```

### Choose Your Version:

| 🟢 Modern Version *(Recommended)* | 🟠 Classic / Old Version |
| :--- | :--- |
| **Latest Releases (2016 – 2026)**<br>Includes JDK 17–26 auto-setup, Chromium browser, HTTP/2/3 | **Classic v1.7.37**<br>Includes Java 8 auto-setup, lightweight, classic layout |
| ```bash<br>sudo ./burp-pro-setup.sh<br>``` | ```bash<br>sudo ./burp-old-pro-setup.sh<br>``` |

---

## ✨ What the Script Does Automatically

- ☕ **Installs & Configures Java**: Automatically sets up Java (JDK 21/23 for Modern, Zulu Java 8 for Legacy).
- 📥 **Downloads Burp Suite Pro**: Pulls the official JAR directly with high-speed download progress.
- 🪟 **Opens the Keygen**: Spawns the activation loader window automatically.
- 🖥️ **Creates Desktop Launchers**: Adds desktop and application menu shortcuts with official Burp Suite icons.
- 🛡️ **Fixes XFCE "Untrusted Launcher"**: Automatically applies SHA-256 integrity checksums so you can launch directly with no warning prompts.

---

## 🔑 3-Step Activation

When the installer opens the loader/keygen window:

```
┌─────────────────────────────────────────────────────────────┐
│  1. In Loader: Enter License Name & Click [Copy Key]        │
│  2. In Burp:   Paste Key -> Click Next -> Manual Activation │
│  3. In Burp:   Copy "Activation Request"                    │
│  4. In Loader: Paste into "Activation Request"              │
│  5. In Burp:   Paste generated "Activation Response" -> OK! │
└─────────────────────────────────────────────────────────────┘
```

> [!TIP]
> After Burp activates, return to your terminal and press **Enter** (or paste your loader command). The script will finish setting up your desktop shortcut!

---

## 🖥️ How to Launch

Once installed, you can launch Burp Suite anytime from anywhere:

### 1. From Terminal
```bash
# Launch Modern Burp:
burp-pro

# Launch Legacy Burp:
burp-old-pro
```

### 2. From Desktop
Simply double-click the **Burp-pro** (or **Burp-Old-Pro**) icon on your Desktop or search for it in your Applications menu!

---

## 📊 Which Version Should I Use?

| Feature | 🟢 Modern (`burp-pro-setup.sh`) | 🟠 Legacy (`burp-old-pro-setup.sh`) |
| :--- | :--- | :--- |
| **Burp Version** | Official Latest (2024 / 2025 / 2026) | Classic v1.7.37 |
| **Java Version** | Java 21 LTS / Java 23 | Java 8 (Zulu 8) |
| **Terminal Command** | `burp-pro` | `burp-old-pro` |
| **Desktop Shortcut** | `Burp-pro` | `Burp-Old-Pro` |
| **Install Folder** | `~/Documents/burp/` | `~/Documents/burp/old/` |
| **Best For** | Modern web apps, API testing, HTTP/3 | Quick assessments, low RAM usage |

*You can install both versions side-by-side on the same machine without conflicts.*

---

## ❓ Quick Fixes

<details>
<summary><b>1. Desktop shortcut says "Untrusted application launcher"</b></summary>

The script fixes this automatically. If you ever see this prompt in XFCE, simply click **"Mark As Secure And Launch"**, or run:
```bash
gio set -t string ~/Desktop/Burp-pro.desktop metadata::trusted true
gio set -t string ~/Desktop/Burp-pro.desktop metadata::xfce-exe-checksum "$(sha256sum ~/Desktop/Burp-pro.desktop | awk '{print $1}')"
```
</details>

<details>
<summary><b>2. How to switch default Java version</b></summary>

If you want to manually change your system default Java:
```bash
# Set to Java 8 (Legacy):
sudo update-alternatives --config java
# Choose the Zulu 8 or OpenJDK 8 number
```
</details>

<details>
<summary><b>3. Need more RAM for Burp Suite?</b></summary>

Edit your startup script:
- For Modern: `nano ~/Documents/burp/burp.sh`
- For Legacy: `nano ~/Documents/burp/old/burp-old.sh`

Add `-Xmx4g` or `-Xmx8g` before `-jar`:
```bash
java -Xms1g -Xmx8g -jar ...
```
</details>

---

## 📜 Disclaimer

> [!NOTE]
> This tool is intended for educational purposes and authorized penetration testing only. Please support PortSwigger by purchasing an official license at [portswigger.net](https://portswigger.net).

---

<div align="center">
⭐ If this made your setup easier, give it a star!
</div>
