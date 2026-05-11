#!/usr/bin/env bash
set -e

REPO="zhianyunai-hub/yuanlo-core-os-release"
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
OPENAI_API_KEY=sk-your-api-key-here
OPENAI_BASE_URL=
OPENAI_MODEL=gpt-4o
ENVEOF
    echo ""
    echo -e "  ${CYAN}Config file created at ${CONFIG_DIR}/.env${NC}"
    echo -e "  ${CYAN}Edit it to set your API key:${NC}"
    echo ""
    echo -e "    vim ${CONFIG_DIR}/.env"
    echo ""
    read -rp "  Set API key now? [y/N] " SET_KEY
    if [ "$SET_KEY" = "y" ] || [ "$SET_KEY" = "Y" ]; then
        read -rp "  API Key: " API_KEY
        sed -i "s/sk-your-api-key-here/$API_KEY/" "$CONFIG_DIR/.env"
        info "API key configured"
    fi
else
    info "Config already exists: $CONFIG_DIR/.env"
fi

# ── Systemd service ──
echo ""
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
ExecStart=$INSTALL_DIR/$BIN_NAME
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
    sudo systemctl enable --now yuanlo-core-os
    info "Service installed and running"
    echo ""
    echo -e "  Manage with:"
    echo -e "    sudo systemctl status yuanlo-core-os"
    echo -e "    sudo journalctl -u yuanlo-core-os -f"
else
    echo ""
    echo -e "  ${CYAN}Run manually:${NC}"
    echo ""
    echo -e "    YUANLO_CONFIG_DIR=$CONFIG_DIR $INSTALL_DIR/$BIN_NAME"
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
