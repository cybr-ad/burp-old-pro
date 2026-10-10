#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║      BurpSuite Pro (Legacy v1.7.37) ─ Universal Setup Script        ║
# ║      Supports: Kali Linux · Debian · Ubuntu · Fedora · Arch         ║
# ║      Features: Java 8 Provisioning · Clean Networking · Trusted UI   ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -uo pipefail

# ── Colors & Formatting ──────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';   BOLD='\033[1m';  NC='\033[0m'
MAGENTA='\033[0;35m'

# ── Helper Functions ─────────────────────────────────────────────────────
banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║   BurpSuite Pro (Legacy v1.7.37) ─ Setup Script            ║"
    echo "  ║   Java 8 Setup · Dual Launcher (CLI & Desktop)             ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

step()  { echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${BOLD}${GREEN}  $*${NC}\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ ✔ ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[ ! ]${NC}  $*"; }
err()   { echo -e "${RED}[ ✘ ]${NC}  $*"; }
pause() { echo -e "\n${YELLOW}▶  Press ENTER to continue...${NC}"; read -r; }
die()   { err "$*"; exit 1; }

# ════════════════════════════════════════════════════════════════════════
#  CRITICAL: Identify the REAL user (not root even if run with sudo)
# ════════════════════════════════════════════════════════════════════════
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$USER"
fi

REAL_HOME=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)
[ -z "$REAL_HOME" ] && REAL_HOME="$HOME"

REAL_DISPLAY="${DISPLAY:-:0}"
REAL_XAUTH="${XAUTHORITY:-${REAL_HOME}/.Xauthority}"
REAL_UID=$(id -u "$REAL_USER" 2>/dev/null || echo "1000")
REAL_DBUS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/${REAL_UID}/bus}"

as_user() {
    if [ "$EUID" -eq 0 ] && [ "$REAL_USER" != "root" ]; then
        sudo -u "$REAL_USER" \
             DISPLAY="$REAL_DISPLAY" \
             XAUTHORITY="$REAL_XAUTH" \
             DBUS_SESSION_BUS_ADDRESS="$REAL_DBUS" \
             HOME="$REAL_HOME" \
             "$@"
    else
        DISPLAY="$REAL_DISPLAY" \
        XAUTHORITY="$REAL_XAUTH" \
        DBUS_SESSION_BUS_ADDRESS="$REAL_DBUS" \
        HOME="$REAL_HOME" \
        "$@"
    fi
}

banner
info "Executing user    : $(whoami) (EUID=$EUID)"
info "Real desktop user : $REAL_USER"
info "Real home dir     : $REAL_HOME"
info "Target workspace  : ${REAL_HOME}/Documents/burp/old"

# ════════════════════════════════════════════════════════════════════════
#  NETWORK SANITATION: Clean leftover iptables/hosts blocks
# ════════════════════════════════════════════════════════════════════════
step "NETWORK ── Inspecting & Sanitizing Network State"

if [ "$EUID" -eq 0 ]; then
    if [ -f /etc/hosts ]; then
        if grep -qE "portswigger|burpsuite" /etc/hosts 2>/dev/null; then
            warn "Detected PortSwigger / BurpSuite overrides in /etc/hosts. Cleaning..."
            sed -i '/portswigger/d' /etc/hosts
            sed -i '/burpsuite/d'   /etc/hosts
            ok "/etc/hosts cleaned."
        else
            ok "/etc/hosts contains no blocking rules."
        fi
    fi

    if command -v iptables &>/dev/null; then
        for domain in "portswigger.net" "burpsuite.net" "drive.google.com"; do
            mapfile -t ips < <(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u)
            for ip in "${ips[@]}"; do
                iptables -D OUTPUT -d "$ip" -j DROP 2>/dev/null || true
            done
        done
        ok "Verified firewall OUTPUT rules."
    fi
fi

# ════════════════════════════════════════════════════════════════════════
#  PROXYCHAINS CONFIGURATION & NETWORK MODE
# ════════════════════════════════════════════════════════════════════════
HAS_PROXYCHAINS=0
PROXYCHAINS_BIN=""

if command -v proxychains4 &>/dev/null; then
    HAS_PROXYCHAINS=1; PROXYCHAINS_BIN="proxychains4"
elif command -v proxychains &>/dev/null; then
    HAS_PROXYCHAINS=1; PROXYCHAINS_BIN="proxychains"
fi

USE_PROXY=0
if [ "$HAS_PROXYCHAINS" -eq 1 ]; then
    echo -e "Choose how download operations should be routed:"
    echo -e "  ${CYAN}1)${NC} ${BOLD}Direct Connection${NC} (Recommended — fastest and most reliable)"
    echo -e "  ${CYAN}2)${NC} ${BOLD}Proxychains Mode${NC} (Routes traffic via $PROXYCHAINS_BIN)"
    read -rp "Enter choice [1 or 2, default=1]: " NET_CHOICE
    NET_CHOICE="${NET_CHOICE:-1}"
    if [ "$NET_CHOICE" -eq 2 ]; then
        USE_PROXY=1
        info "Proxychains routing enabled ($PROXYCHAINS_BIN)."
    fi
fi

net_run() {
    if [ "$USE_PROXY" -eq 1 ] && [ -n "$PROXYCHAINS_BIN" ]; then
        $PROXYCHAINS_BIN -q "$@"
    else
        "$@"
    fi
}

is_valid_jar() {
    local f="$1"
    local min_size="${2:-1000}"
    [ ! -f "$f" ] && return 1
    local sz; sz=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || wc -c < "$f" 2>/dev/null || echo 0)
    [ "$sz" -lt "$min_size" ] && return 1
    local magic; magic=$(head -c 2 "$f" 2>/dev/null)
    [ "$magic" != "PK" ] && return 1
    unzip -t "$f" &>/dev/null && return 0
    return 1
}

# ════════════════════════════════════════════════════════════════════════
#  Google Drive Downloader with Multiple Fallback Methods
# ════════════════════════════════════════════════════════════════════════
gdrive_download() {
    local id="$1"
    local out="$2"

    # Method 1: Direct curl
    info "  [Method 1] Trying curl..."
    net_run curl -# -L \
         -A "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0" \
         --max-time 180 --retry 2 \
         "https://drive.google.com/uc?export=download&id=${id}" \
         -o "$out"
    if is_valid_jar "$out" 5000; then ok "  curl: download verified! ✔"; return 0; fi
    rm -f "$out"

    # Method 2: Python 3 urllib (form / cookie aware)
    info "  [Method 2] Trying Python urllib (handling Drive confirmation)..."
    python3 - <<PYEOF
import urllib.request, http.cookiejar, re, sys, urllib.parse

file_id = "$id"
out_path = "$out"
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0'}

url = f'https://drive.google.com/uc?export=download&id={file_id}'
try:
    resp = opener.open(urllib.request.Request(url, headers=headers), timeout=60)
    data = resp.read()
    if data.startswith(b'PK'):
        with open(out_path, 'wb') as f:
            f.write(data)
        sys.exit(0)
    html = data.decode('utf-8', errors='ignore')
    action_match = re.search(r'action="([^"]+)"', html)
    action_url = action_match.group(1) if action_match else "https://drive.usercontent.google.com/download"
    inputs = dict(re.findall(r'<input type="hidden" name="([^"]+)" value="([^"]*)">', html))
    if not inputs:
        token_match = re.search(r'confirm=([0-9A-Za-z_-]+)', html)
        token = token_match.group(1) if token_match else 't'
        confirm_url = f"https://drive.google.com/uc?export=download&confirm={token}&id={file_id}"
    else:
        confirm_url = f"{action_url}?{urllib.parse.urlencode(inputs)}"
    resp2 = opener.open(urllib.request.Request(confirm_url, headers=headers), timeout=180)
    with open(out_path, 'wb') as f:
        while True:
            chunk = resp2.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)
    sys.exit(0)
except Exception as e:
    sys.exit(1)
PYEOF
    if is_valid_jar "$out" 5000; then ok "  Python urllib: download verified! ✔"; return 0; fi
    rm -f "$out"

    # Method 3: wget with session cookies
    info "  [Method 3] Trying wget..."
    net_run wget --no-check-certificate -q --show-progress \
         --user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0" \
         --save-cookies /tmp/gd_ck.txt --keep-session-cookies \
         "https://drive.google.com/uc?export=download&id=${id}" \
         -O "$out" 2>/dev/null || true

    if is_valid_jar "$out" 5000; then
        rm -f /tmp/gd_ck.txt
        ok "  wget: download verified! ✔"
        return 0
    fi

    local token
    token=$(grep -oP 'confirm=\K[^&"]+' "$out" 2>/dev/null | head -1)
    if [ -n "$token" ]; then
        net_run wget --no-check-certificate -q --show-progress \
             --user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0" \
             --load-cookies /tmp/gd_ck.txt \
             "https://drive.google.com/uc?export=download&confirm=${token}&id=${id}" \
             -O "$out" 2>/dev/null || true
    fi
    rm -f /tmp/gd_ck.txt

    if is_valid_jar "$out" 5000; then ok "  wget (confirm token): download verified! ✔"; return 0; fi
    rm -f "$out"

    # Method 4: gdown fallback
    info "  [Method 4] Trying gdown..."
    if command -v gdown &>/dev/null || python3 -m gdown --version &>/dev/null 2>&1; then
        net_run python3 -m gdown "https://drive.google.com/uc?id=${id}" -O "$out" --fuzzy 2>/dev/null || true
        if is_valid_jar "$out" 5000; then ok "  gdown: download verified! ✔"; return 0; fi
    fi
    rm -f "$out"

    return 1
}

# ════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT ── System Detection & Core Dependencies
# ════════════════════════════════════════════════════════════════════════
step "PRE-FLIGHT ── System Detection & Dependencies"

ARCH=$(uname -m)
DISTRO=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
info "Detected OS   : $DISTRO"
info "Architecture  : $ARCH"

if command -v apt-get &>/dev/null; then
    info "Installing prerequisites via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y wget curl ca-certificates unzip python3 python3-pip \
        imagemagick libxrender1 libxtst6 libxi6 2>/dev/null
    sudo update-ca-certificates -f 2>/dev/null || true
elif command -v dnf &>/dev/null; then
    sudo dnf install -y wget curl ca-certificates unzip python3 python3-pip ImageMagick 2>/dev/null
elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm wget curl ca-certificates unzip python python-pip imagemagick 2>/dev/null
fi

ok "Core prerequisites verified."

# ════════════════════════════════════════════════════════════════════════
#  STEP 01 ── Install & Configure Java 8 (Required for Burp 1.7.37)
# ════════════════════════════════════════════════════════════════════════
step "STEP 01 ── Installing & Configuring Java 8 Runtime"

echo -e "${BOLD}${YELLOW}Burp Suite Pro v1.7.37 and legacy loaders require Java 8 (1.8).${NC}"
info "Searching for existing Java 8 installations on this system..."

find_java8_bin() {
    # 1. Check current active java
    if command -v java &>/dev/null; then
        if java -version 2>&1 | grep -qE '"1\.8\.|openjdk version "1\.8\.|zulu-8'; then
            readlink -f "$(which java)" 2>/dev/null && return 0
        fi
    fi

    # 2. Check update-alternatives list for Java 8 entries
    if command -v update-alternatives &>/dev/null; then
        local alt_j8
        alt_j8=$(update-alternatives --list java 2>/dev/null | grep -E '8|1\.8|zulu-8' | head -1 || true)
        if [ -n "$alt_j8" ] && [ -x "$alt_j8" ]; then
            echo "$alt_j8"
            return 0
        fi
    fi

    # 3. Check known JVM locations (including Zulu, OpenJDK, Temurin, Oracle)
    for candidate in \
        /usr/lib/jvm/zulu-8*/jre/bin/java \
        /usr/lib/jvm/zulu-8*/bin/java \
        /usr/lib/jvm/zulu8*/jre/bin/java \
        /usr/lib/jvm/zulu8*/bin/java \
        /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java \
        /usr/lib/jvm/java-8-openjdk-amd64/bin/java \
        /usr/lib/jvm/java-8-openjdk/jre/bin/java \
        /usr/lib/jvm/java-8-openjdk/bin/java \
        /usr/lib/jvm/jdk8/bin/java \
        /usr/lib/jvm/adoptopenjdk-8*/bin/java \
        /usr/lib/jvm/temurin-8*/bin/java \
        /usr/lib/jvm/oracle-jdk8/bin/java \
        /usr/lib/jvm/jdk1.8*/bin/java \
        /opt/zulu8*/bin/java \
        /opt/jdk8/bin/java \
        /opt/java8/bin/java; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

JAVA8_BIN=$(find_java8_bin || true)

if [ -z "$JAVA8_BIN" ]; then
    warn "Java 8 is not yet installed on this system."
    echo ""
    echo -e "Choose how to install Java 8:"
    echo -e "  ${CYAN}1)${NC} ${BOLD}Automated Install (Azul Zulu / OpenJDK 8 package)${NC}  ${GREEN}★ Recommended${NC}"
    echo -e "  ${CYAN}2)${NC} ${BOLD}Automated Install (Adoptium Temurin OpenJDK 8 tarball)${NC}"
    echo -e "  ${CYAN}3)${NC} ${BOLD}Use local Oracle Java 8 archive (.deb or .tar.gz)${NC}"
    echo ""
    read -rp "Enter choice [1-3, default=1]: " J8_CHOICE
    J8_CHOICE="${J8_CHOICE:-1}"

    JAVA_DIR="${REAL_HOME}/java8"
    mkdir -p "$JAVA_DIR"

    case "$J8_CHOICE" in
        1)
            # Try apt first if on Debian/Ubuntu/Kali
            J8_INSTALLED=0
            if command -v apt-get &>/dev/null; then
                info "Attempting apt install of openjdk-8-jdk..."
                if sudo apt-get install -y openjdk-8-jdk 2>/dev/null || sudo apt-get install -y openjdk-8-jre 2>/dev/null; then
                    J8_INSTALLED=1
                fi
            fi

            # Fallback to direct official Zulu JDK 8 debian package
            if [ "$J8_INSTALLED" -eq 0 ] && command -v dpkg &>/dev/null; then
                ZULU_DEB_URL="https://cdn.azul.com/zulu/bin/zulu8.84.0.15-ca-jdk8.0.442-linux_amd64.deb"
                DEB_FILE="${JAVA_DIR}/zulu8_jdk.deb"
                info "Downloading verified Java 8 package (Azul Zulu JDK 8)..."
                net_run wget --no-check-certificate -q --show-progress "$ZULU_DEB_URL" -O "$DEB_FILE"
                if [ -s "$DEB_FILE" ]; then
                    info "Installing Java 8 package via dpkg..."
                    sudo dpkg -i "$DEB_FILE" 2>/dev/null || sudo apt-get install -f -y 2>/dev/null || true
                    rm -f "$DEB_FILE"
                fi
            fi
            ;;
        2)
            # Adoptium Temurin OpenJDK 8 tarball
            ADOPT_URL="https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse"
            TAR_FILE="${JAVA_DIR}/openjdk8.tar.gz"
            info "Downloading Adoptium OpenJDK 8..."
            net_run curl -# -L "$ADOPT_URL" -o "$TAR_FILE"
            if [ -s "$TAR_FILE" ]; then
                info "Extracting OpenJDK 8 to /usr/lib/jvm/jdk8..."
                sudo mkdir -p /usr/lib/jvm/jdk8
                sudo tar -xzf "$TAR_FILE" -C /usr/lib/jvm/jdk8 --strip-components=1
                rm -f "$TAR_FILE"
            fi
            ;;
        3)
            echo -e "\nIf you manually downloaded an Oracle Java 8 archive from:"
            echo -e "${CYAN}https://www.oracle.com/java/technologies/javase/javase8-archive-downloads.html${NC}"
            read -rp "Enter path to the downloaded file (.deb or .tar.gz): " USER_PKG
            if [ -f "$USER_PKG" ]; then
                if [[ "$USER_PKG" == *.deb ]]; then
                    sudo dpkg -i "$USER_PKG"
                elif [[ "$USER_PKG" == *.tar.gz ]]; then
                    sudo mkdir -p /usr/lib/jvm/oracle-jdk8
                    sudo tar -xzf "$USER_PKG" -C /usr/lib/jvm/oracle-jdk8 --strip-components=1
                fi
            else
                warn "File not found. Falling back to automated package installation..."
                sudo apt-get install -y openjdk-8-jdk 2>/dev/null || true
            fi
            ;;
    esac

    JAVA8_BIN=$(find_java8_bin || true)
    if [ -z "$JAVA8_BIN" ]; then
        JAVA8_BIN=$(readlink -f "$(which java)" 2>/dev/null || echo "java")
    fi
fi

# Automatically configure update-alternatives to switch system default Java to Java 8
if [ -n "$JAVA8_BIN" ] && [ -x "$JAVA8_BIN" ]; then
    if command -v update-alternatives &>/dev/null; then
        info "Automatically configuring update-alternatives to default to Java 8 ($JAVA8_BIN)..."
        sudo update-alternatives --install /usr/bin/java java "$JAVA8_BIN" 2000000000 2>/dev/null || true
        sudo update-alternatives --set java "$JAVA8_BIN" 2>/dev/null || true

        JAVA8_JAVAC=$(echo "$JAVA8_BIN" | sed 's#/bin/java#/bin/javac#' | sed 's#/jre/bin/java#/bin/javac#')
        if [ -x "$JAVA8_JAVAC" ]; then
            sudo update-alternatives --install /usr/bin/javac javac "$JAVA8_JAVAC" 2000000000 2>/dev/null || true
            sudo update-alternatives --set javac "$JAVA8_JAVAC" 2>/dev/null || true
        fi
    fi

    JAVA8_HOME=$(dirname "$(dirname "$JAVA8_BIN")")
    [[ "$JAVA8_HOME" == */jre ]] && JAVA8_HOME=$(dirname "$JAVA8_HOME")
    export JAVA_HOME="$JAVA8_HOME"
    export PATH="$(dirname "$JAVA8_BIN"):$PATH"
fi

ok "Java 8 configured: $JAVA8_BIN"
info "Active system Java runtime:"
java -version 2>&1 | head -2

# ════════════════════════════════════════════════════════════════════════
#  STEP 02 ── Download Burp Suite Pro v1.7.37 & Loader Keygen
# ════════════════════════════════════════════════════════════════════════
step "STEP 02 ── Downloading Legacy BurpSuite Pro & Keygen"

# Dedicated workspace directory for Old Burp Pro
BURP_DIR="${REAL_HOME}/Documents/burp/old"
mkdir -p "$BURP_DIR"
chown -R "$REAL_USER":"$REAL_USER" "${REAL_HOME}/Documents/burp" 2>/dev/null || true

KEYGEN_NAME="burp-loader-keygen.jar"
KEYGEN_ID="1CTqzUZvBrNTieBD_yQwJgy6tYP0zdnvI"
BURP_JAR="burpsuite_pro_v1.7.37.jar"
BURP_ID="1wMLtbVJjIxW5rMy_NQLZJiqq8PvzOXfl"

echo -e "Destination Directory : ${BOLD}${BURP_DIR}${NC}"
echo ""

# ── Download burp-loader-keygen.jar ─────────────────────────────────────
info "Downloading ${KEYGEN_NAME} (~65 KB)..."
if [ ! -s "${BURP_DIR}/${KEYGEN_NAME}" ] || ! is_valid_jar "${BURP_DIR}/${KEYGEN_NAME}" 5000; then
    gdrive_download "$KEYGEN_ID" "${BURP_DIR}/${KEYGEN_NAME}" \
        || die "Failed to download ${KEYGEN_NAME} from Google Drive."
else
    ok "${KEYGEN_NAME} is already downloaded and verified! ✔"
fi

# ── Download burpsuite_pro_v1.7.37.jar ──────────────────────────────────
info "Downloading ${BURP_JAR} (~28 MB)..."
if [ ! -s "${BURP_DIR}/${BURP_JAR}" ] || ! is_valid_jar "${BURP_DIR}/${BURP_JAR}" 5000000; then
    gdrive_download "$BURP_ID" "${BURP_DIR}/${BURP_JAR}" \
        || die "Failed to download ${BURP_JAR} from Google Drive."
else
    ok "${BURP_JAR} is already downloaded and verified! ✔"
fi

chown -R "$REAL_USER":"$REAL_USER" "$BURP_DIR" 2>/dev/null || true
ok "All legacy JAR components downloaded and verified in ${BURP_DIR}!"

# ════════════════════════════════════════════════════════════════════════
#  STEP 03 ── Launch Keygen & Burp Suite Activation
# ════════════════════════════════════════════════════════════════════════
step "STEP 03 ── Launching Keygen & Activation Workflow"

echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                     ★ ACTIVATION INSTRUCTIONS ★                      ║${NC}"
echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "  ${CYAN}1.${NC} The Keygen window (${BOLD}${KEYGEN_NAME}${NC}) will open shortly."
echo -e "  ${CYAN}2.${NC} In the Keygen window:"
echo -e "       • Set your desired ${BOLD}License Name${NC}."
echo -e "       • Click ${BOLD}'Run'${NC} in the Keygen window to launch Burp Suite Pro."
echo -e "  ${CYAN}3.${NC} In Burp Suite Pro:"
echo -e "       • Copy the License string from the Keygen into Burp Suite."
echo -e "       • Choose ${BOLD}Manual Activation${NC}."
echo -e "       • Copy the activation Request into the Keygen, then paste the Response back."
echo -e "  ${CYAN}4.${NC} Once Burp Suite shows activation success, return to this terminal."
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

info "Launching ${KEYGEN_NAME} with Java 8..."
cd "${BURP_DIR}" || true
as_user bash -c "cd '${BURP_DIR}' && '$JAVA8_BIN' -jar '${BURP_DIR}/${KEYGEN_NAME}'" >/dev/null 2>&1 &
KEYGEN_PID=$!

echo ""
ok "${KEYGEN_NAME} GUI is now open (PID: $KEYGEN_PID)."
echo -e "${GREEN}★ In the Keygen window, click 'Run' to launch Burp Suite Pro.${NC}"
echo -e "${YELLOW}★ Keep the Keygen window OPEN so you can copy the Loader Command.${NC}"
echo ""

echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}  Have you finished Burp Suite setup & activation?           ${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Take your time to complete activation in the GUI."
read -rp "Press ENTER when activation is finished (or type 'r' to re-open Keygen): " USER_CONFIRM

while [[ "${USER_CONFIRM,,}" == "r"* ]] || [[ "${USER_CONFIRM,,}" == "retry"* ]]; do
    info "Re-opening ${KEYGEN_NAME} GUI..."
    cd "${BURP_DIR}" || true
    as_user bash -c "cd '${BURP_DIR}' && '$JAVA8_BIN' -jar '${BURP_DIR}/${KEYGEN_NAME}'" >/dev/null 2>&1 &
    KEYGEN_PID=$!
    ok "${KEYGEN_NAME} re-opened (PID: $KEYGEN_PID)."
    read -rp "Press ENTER when activation is finished: " USER_CONFIRM
done

ok "Activation marked complete! ✔"
echo ""

# ── Step 03b: Paste Loader Command ─────────────────────────────────────
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}  STEP 03b ── PASTE THE LOADER COMMAND FROM KEYGEN           ${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${CYAN}1.${NC} In the Keygen window, copy the text inside the ${BOLD}'Loader Command'${NC} field."
echo -e "  ${CYAN}2.${NC} Paste that command below."
echo -e "  ${CYAN}3.${NC} (Or press ENTER to use the auto-detected command: ${BOLD}java -Xbootclasspath/p:...${NC})"
echo ""
read -rp "Paste Loader Command here [or press ENTER]: " CUSTOM_LOADER_CMD

if [ -n "$CUSTOM_LOADER_CMD" ]; then
    LOADER_CMD="$CUSTOM_LOADER_CMD"
else
    LOADER_CMD="\"$JAVA8_BIN\" -Xbootclasspath/p:\"${BURP_DIR}/${KEYGEN_NAME}\" -jar \"${BURP_DIR}/${BURP_JAR}\""
fi

echo ""
ok "Configured Loader Command:"
echo -e "  ${CYAN}${LOADER_CMD}${NC}"
echo ""

# ── Create Startup Wrapper Script ─────────────────────────────────────
BURP_SH="${BURP_DIR}/burp-old.sh"
info "Creating startup script at $BURP_SH..."

cat > "$BURP_SH" <<EOF
#!/bin/bash
cd "${BURP_DIR}"
nohup ${LOADER_CMD} >/dev/null 2>&1 &
EOF

chmod +x "$BURP_SH"
chown "$REAL_USER":"$REAL_USER" "$BURP_SH" 2>/dev/null || true
ok "Startup script created: $BURP_SH ✔"

# ── Create Global CLI Command: burp-old-pro ───────────────────────────
info "Creating system CLI symlink: /usr/local/bin/burp-old-pro -> $BURP_SH..."
sudo rm -f /usr/local/bin/burp-old-pro
sudo ln -sf "$BURP_SH" /usr/local/bin/burp-old-pro
ok "CLI command created: type ${BOLD}burp-old-pro${NC} in any terminal to launch!"

# ════════════════════════════════════════════════════════════════════════
#  STEP 04 ── Create Desktop Launcher (Burp-Old-Pro)
# ════════════════════════════════════════════════════════════════════════
step "STEP 04 ── Creating Desktop Launcher (Burp-Old-Pro)"

ICON_DIR="${REAL_HOME}/.local/share/icons"
mkdir -p "$ICON_DIR"
ICON_PATH="${ICON_DIR}/burpsuite-old.png"
PIXMAP_ICON="/usr/share/pixmaps/burpsuite-old.png"
BURP_DIR_ICON="${BURP_DIR}/burpsuite.png"

info "Configuring Burp Suite Pro icon..."
if command -v unzip &>/dev/null && [ -f "${BURP_DIR}/${BURP_JAR}" ]; then
    for candidate in "resources/Media/icon64.png" "resources/Media/icon32.png" "resources/Media/icon28.png" "resources/Media/icon20.png" "resources/Media/icon16.png"; do
        if unzip -p "${BURP_DIR}/${BURP_JAR}" "$candidate" > "$ICON_PATH" 2>/dev/null && [ -s "$ICON_PATH" ]; then
            ok "Official icon extracted: $candidate"
            break
        fi
    done
fi

# Fallback embedded official Burp icon if extraction failed
if [ ! -s "$ICON_PATH" ]; then
    info "Embedding official Burp Suite icon..."
    base64 -d > "$ICON_PATH" 2>/dev/null <<'EOF_ICON'
iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAnFBMVEVbT/9jV/9tYv+qo/////+6tf+Lgv/9/f90af/19f+Hfv9kWf/l5P+po/9cUP/Py//IxP+xrP/h3/9iVv+Si//y8f9vZf95cP/4+P/8/P+Ee/9nXP/r6f+hmv9dUf/W0//BvP/7+v+uqP+Ad/+ak/9/dv9sYf/v7v9gVP/c2v96cP+moP/Rzv/6+v+/uv+gmf9hVf/g3v/Hw//19P8g0/xMAAAA2klEQVR4Ae3WNXrFMBRE4XnRfczMzLbD+99bPJVTBebmS6W/n9MYJETRt0oPuRJ0wXLBFYiBsjNQqfoCtTr31QZEzZZRG6JO16gHVd9oMIRoZDSeQDSdcT9fQLRcGa0h2myNdr430PaHQEf82skKypt43vsCl6u5Are7+QJJWsjiL+2PAllaSJTAJ/ebL3C9wBXYn+ELnPBrx0CHR6MyVE9G2w1Ez0arJUSLOfezKUSTsdEIopdXoz5Ub0bdDkRto1YTokaV+/ea72usVuALlOMv7R8D+nU/ij4AkKERE6vBiJsAAAAASUVORK5CYII=
EOF_ICON
fi

if [ -s "$ICON_PATH" ]; then
    mkdir -p /usr/share/pixmaps 2>/dev/null || true
    cp -f "$ICON_PATH" "$PIXMAP_ICON" 2>/dev/null || true
    cp -f "$ICON_PATH" "$BURP_DIR_ICON" 2>/dev/null || true
    chmod 644 "$ICON_PATH" "$PIXMAP_ICON" "$BURP_DIR_ICON" 2>/dev/null || true
    chown "$REAL_USER":"$REAL_USER" "$ICON_PATH" "$BURP_DIR_ICON" 2>/dev/null || true
    ACTIVE_ICON="$PIXMAP_ICON"
else
    ACTIVE_ICON="application-x-java"
fi

# Create Desktop Entry directly
DESKTOP_DIR="${REAL_HOME}/Desktop"
mkdir -p "$DESKTOP_DIR"
DESKTOP_FILE="${DESKTOP_DIR}/Burp-Old-Pro.desktop"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Burp-Old-Pro
GenericName=BurpSuite Professional (Legacy v1.7.37)
Comment=BurpSuite Pro v1.7.37 (Java 8) - Web Security Testing
Exec=${LOADER_CMD}
Path=${BURP_DIR}
Icon=${ACTIVE_ICON}
Terminal=false
Categories=Security;Network;Development;
Keywords=burpsuite;security;web;proxy;pentest;old;legacy;
StartupNotify=true
StartupWMClass=burp-StartBurp
EOF

chmod +x "$DESKTOP_FILE"
chown "$REAL_USER":"$REAL_USER" "$DESKTOP_FILE" 2>/dev/null || true

# Mark launcher as trusted & secure across XFCE (4.18+ SHA-256 checksum) and GNOME/KDE
if command -v gio &>/dev/null; then
    DESK_CHECKSUM=$(sha256sum "$DESKTOP_FILE" 2>/dev/null | awk '{print $1}')
    if [ -n "$DESK_CHECKSUM" ]; then
        gio set -t string "$DESKTOP_FILE" metadata::xfce-exe-checksum "$DESK_CHECKSUM" 2>/dev/null || true
        as_user gio set -t string "$DESKTOP_FILE" metadata::xfce-exe-checksum "$DESK_CHECKSUM" 2>/dev/null || true
    fi
    gio set -t string "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true
    as_user gio set -t string "$DESKTOP_FILE" metadata::trusted true 2>/dev/null || true
fi

# Duplicate to /root/Desktop if root Desktop exists
if [ -d "/root/Desktop" ] && [ "$DESKTOP_DIR" != "/root/Desktop" ]; then
    cp -f "$DESKTOP_FILE" "/root/Desktop/Burp-Old-Pro.desktop" 2>/dev/null || true
    chmod +x "/root/Desktop/Burp-Old-Pro.desktop" 2>/dev/null || true
    if command -v gio &>/dev/null; then
        ROOT_CHECKSUM=$(sha256sum "/root/Desktop/Burp-Old-Pro.desktop" 2>/dev/null | awk '{print $1}')
        [ -n "$ROOT_CHECKSUM" ] && gio set -t string "/root/Desktop/Burp-Old-Pro.desktop" metadata::xfce-exe-checksum "$ROOT_CHECKSUM" 2>/dev/null || true
        gio set -t string "/root/Desktop/Burp-Old-Pro.desktop" metadata::trusted true 2>/dev/null || true
    fi
fi

# Register in applications menu
APPS_MENU_DIR="${REAL_HOME}/.local/share/applications"
mkdir -p "$APPS_MENU_DIR"
cp -f "$DESKTOP_FILE" "${APPS_MENU_DIR}/Burp-Old-Pro.desktop" 2>/dev/null || true
chown "$REAL_USER":"$REAL_USER" "${APPS_MENU_DIR}/Burp-Old-Pro.desktop" 2>/dev/null || true
mkdir -p /usr/share/applications 2>/dev/null || true
cp -f "$DESKTOP_FILE" /usr/share/applications/Burp-Old-Pro.desktop 2>/dev/null || true

ok "Desktop launcher created at: $DESKTOP_FILE"
ok "Launcher command set to: ${LOADER_CMD}"
ok "Launcher icon set to: ${ACTIVE_ICON}"

# ════════════════════════════════════════════════════════════════════════
#  STEP 05 ── System & Installation Diagnostics
# ════════════════════════════════════════════════════════════════════════
step "DIAGNOSTICS ── System Summary"

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║        ✔   Burp-Old-Pro Installation Summary                 ║"
echo "  ╠══════════════════════════════════════════════════════════════╣"
printf "  ║  %-58s║\n" "  OS / Distro   : $DISTRO ($ARCH)"
printf "  ║  %-58s║\n" "  User Account  : $REAL_USER"
printf "  ║  %-58s║\n" "  Burp Version  : v1.7.37 (Legacy)"
printf "  ║  %-58s║\n" "  Java Runtime  : $JAVA8_BIN"
printf "  ║  %-58s║\n" "  Workspace     : $BURP_DIR"
printf "  ║  %-58s║\n" "  CLI Command   : burp-old-pro"
printf "  ║  %-58s║\n" "  Desktop Icon  : Burp-Old-Pro"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "You can launch BurpSuite Pro (Legacy v1.7.37) in two ways:"
echo -e "  ${GREEN}1.${NC} In any terminal, run: ${BOLD}${CYAN}burp-old-pro${NC}"
echo -e "  ${GREEN}2.${NC} Double-click the ${BOLD}${CYAN}Burp-Old-Pro${NC} icon on your Desktop.\n"
ok "Installation complete! Enjoy testing with BurpSuite Pro Legacy! 🚀"
