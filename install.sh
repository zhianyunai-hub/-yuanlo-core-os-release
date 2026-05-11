#!/usr/bin/env bash
set -e

REPO="zhianyunai-hub/yuanlo-os"
VERSION="${YUANLO_VERSION:-latest}"
BIN_NAME="yuanlo-core-os"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/yuanlo-core-os"

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║       Yuanlo Core OS Installer           ║${NC}"
    echo -e "${CYAN}  ║       AI Employee OS v0.2.0             ║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════╝${NC}"
    echo ""
}

err() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
info() { echo -e "${GREEN}  ✓${NC} $1"; }

# ── OS check ──
banner

case "$(uname -s)" in
    Linux)  PLATFORM="linux" ;;
    *)      err "Unsupported OS. Yuanlo Core OS currently supports Linux only." ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="arm64" ;;
    *)       err "Unsupported architecture: $ARCH" ;;
esac

info "Platform: $PLATFORM / $ARCH"

# ── Download binary ──
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ "$VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/${BIN_NAME}-${PLATFORM}-${ARCH}"
else
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/${VERSION}/${BIN_NAME}-${PLATFORM}-${ARCH}"
fi

echo -e "  Downloading ${BIN_NAME}..."
if command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "$TMP_DIR/$BIN_NAME" "$DOWNLOAD_URL" || err "Download failed. Check: $DOWNLOAD_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -fSL --progress-bar -o "$TMP_DIR/$BIN_NAME" "$DOWNLOAD_URL" || err "Download failed. Check: $DOWNLOAD_URL"
else
    err "Need curl or wget to download."
fi

info "Downloaded binary"

# ── Install binary ──
sudo mkdir -p "$INSTALL_DIR"
sudo cp "$TMP_DIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
sudo chmod +x "$INSTALL_DIR/$BIN_NAME"
info "Installed to $INSTALL_DIR/$BIN_NAME"

# ── Config setup ──
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/.env" ]; then
    cat > "$CONFIG_DIR/.env" << 'ENVEOF'
LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=
DEEPSEEK_MODEL=deepseek-chat
OPENAI_API_KEY=
OPENAI_BASE_URL=
OPENAI_MODEL=gpt-4o
QQ_ENABLED=false
QQ_ONEBOT_HOST=0.0.0.0
QQ_ONEBOT_PORT=8090
QQ_ONEBOT_ACCESS_TOKEN=
PANEL_MODE=web
SETUP_COMPLETED=false
ENVEOF
    info "Config template created at $CONFIG_DIR/.env"
else
    info "Config already exists: $CONFIG_DIR/.env"
fi

# ── Setup wizard prompt ──
echo ""
echo -e "  ${CYAN}Run the setup wizard to configure:${NC}"
echo ""
echo -e "    $INSTALL_DIR/$BIN_NAME setup"
echo ""

# ── Systemd service ──
read -rp "  Install systemd service (auto-start on boot)? [y/N] " INSTALL_SVC

if [ "$INSTALL_SVC" = "y" ] || [ "$INSTALL_SVC" = "Y" ]; then
    SERVICE_FILE="/etc/systemd/system/yuanlo-core-os.service"
    sudo tee "$SERVICE_FILE" > /dev/null << SVC_EOF
[Unit]
Description=Yuanlo Core OS AI Employee OS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="YUANLO_CONFIG_DIR=$CONFIG_DIR"
EnvironmentFile=$CONFIG_DIR/.env
ExecStart=$INSTALL_DIR/$BIN_NAME serve
WorkingDirectory=$CONFIG_DIR
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=yuanlo-core-os

NoNewPrivileges=yes
PrivateTmp=yes
MemoryMax=2G

[Install]
WantedBy=multi-user.target
SVC_EOF
    sudo systemctl daemon-reload
    sudo systemctl enable yuanlo-core-os
    info "Service installed (disabled by default, run: sudo systemctl start yuanlo-core-os)"
    echo ""
    echo -e "  Manage with:"
    echo -e "    sudo systemctl start yuanlo-core-os"
    echo -e "    sudo systemctl status yuanlo-core-os"
    echo -e "    sudo journalctl -u yuanlo-core-os -f"
else
    echo ""
    echo -e "  ${CYAN}Run manually:${NC}"
    echo ""
    echo -e "    YUANLO_CONFIG_DIR=$CONFIG_DIR $INSTALL_DIR/$BIN_NAME serve"
fi

# ── Done ──
echo ""
echo -e "${GREEN}  ══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Yuanlo Core OS installed successfully!${NC}"
echo -e "${GREEN}  ══════════════════════════════════════════${NC}"
echo ""
echo -e "  Health:  curl http://localhost:8000/health"
echo -e "  Config:  $CONFIG_DIR/.env"
echo ""
