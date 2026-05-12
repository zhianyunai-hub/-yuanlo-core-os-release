#!/usr/bin/env bash
set -e

# ──────────────────────────────────────────────
#  Yuanlo Core OS — One-Line Installer
#  Usage: curl -fsSL https://raw.githubusercontent.com/zhianyunai-hub/yuanlo-os/main/install.sh | bash
# ──────────────────────────────────────────────

REPO_URL="https://github.com/zhianyunai-hub/yuanlo-core.git"
INSTALL_DIR="${YUANLO_INSTALL_DIR:-$HOME/.yuanlo-core}"
BIN_DIR="${YUANLO_BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${YUANLO_CONFIG_DIR:-$HOME/.config/yuanlo-core-os}"
BIN_NAME="yuanlo-core-os"
VERSION="${YUANLO_VERSION:-main}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║       Yuanlo Core OS Installer           ║${NC}"
    echo -e "${CYAN}  ║       AI Employee OS v0.4.2              ║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════╝${NC}"
    echo ""
}

err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
info() { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }

# ── Pre-flight checks ──
banner

# Check Python
PYTHON=""
for py in python3.12 python3.11 python3.10 python3; do
    if command -v "$py" &>/dev/null; then
        PYVER=$("$py" -c 'import sys; print(sys.version_info[:2])' 2>/dev/null || echo "(0,0)")
        MAJOR=$(echo "$PYVER" | grep -oP '\d+' | head -1)
        if [ "$MAJOR" -ge 10 ] 2>/dev/null; then
            PYTHON="$py"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    err "Python 3.10+ required. Install: sudo apt install python3 python3-pip"
fi
info "Python: $($PYTHON --version)"

# Check git
if ! command -v git &>/dev/null; then
    err "git required. Install: sudo apt install git"
fi

# ── Clone / update repo ──
if [ -d "$INSTALL_DIR" ]; then
    info "Updating existing install at $INSTALL_DIR"
    cd "$INSTALL_DIR"
    git fetch origin "$VERSION" 2>/dev/null || true
    git checkout "$VERSION" 2>/dev/null || git checkout main
    git pull origin "$VERSION" 2>/dev/null || true
else
    info "Cloning repository to $INSTALL_DIR"
    git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || \
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# ── Install Python dependencies ──
echo ""
echo -e "  Installing Python dependencies..."

if [ -f "requirements.txt" ]; then
    $PYTHON -m pip install --quiet --upgrade pip 2>/dev/null || true
    $PYTHON -m pip install --quiet -r requirements.txt || \
        warn "Some deps failed to install — try: pip install -r requirements.txt"
    info "Dependencies installed"
else
    warn "requirements.txt not found — skipping pip install"
fi

# ── Install CLI entry point ──
echo ""
echo -e "  Installing CLI entry point..."

# Write wrapper script
WRAPPER="$BIN_DIR/$BIN_NAME"
if [ ! -w "$BIN_DIR" ]; then
    BIN_DIR="$HOME/.local/bin"
    WRAPPER="$BIN_DIR/$BIN_NAME"
    mkdir -p "$BIN_DIR"
fi

cat > "$WRAPPER" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Yuanlo Core OS — CLI entry point
INSTALL_DIR="${YUANLO_INSTALL_DIR:-$HOME/.yuanlo-core}"
cd "$INSTALL_DIR/backend" 2>/dev/null || cd "$INSTALL_DIR" 2>/dev/null || true
exec python3 -m cli_main "$@"
WRAPPER_EOF

chmod +x "$WRAPPER"
info "CLI installed: $WRAPPER"

# Add to PATH if needed
if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$BIN_DIR"; then
    SHELL_RC=""
    case "$SHELL" in
        */zsh)  SHELL_RC="$HOME/.zshrc" ;;
        */bash) SHELL_RC="$HOME/.bashrc" ;;
        */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    esac
    if [ -n "$SHELL_RC" ]; then
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        info "Added $BIN_DIR to PATH in $SHELL_RC"
    fi
fi

# ── Create config directory ──
echo ""
mkdir -p "$CONFIG_DIR"
info "Config directory: $CONFIG_DIR"

# Create .env template if missing
if [ ! -f "$CONFIG_DIR/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$CONFIG_DIR/.env" 2>/dev/null || \
        $PYTHON -c "
import os
from pathlib import Path
d = Path(os.environ.get('YUANLO_CONFIG_DIR', Path.home() / '.config/yuanlo-core-os'))
d.mkdir(parents=True, exist_ok=True)
env = d / '.env'
if not env.exists():
    env.write_text('''LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=
DEEPSEEK_MODEL=deepseek-chat
OPENAI_API_KEY=
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o
CUSTOM_API_KEY=
CUSTOM_BASE_URL=
CUSTOM_MODEL=
OLLAMA_BASE_URL=http://localhost:11434/v1
OLLAMA_MODEL=llama3:latest
EMBEDDING_MODEL=text-embedding-3-small
HOST=127.0.0.1
PORT=8000
API_AUTH_ENABLED=true
API_TOKEN=
CORS_ORIGINS=*
DATABASE_URL=sqlite+aiosqlite:///yuanlo.db
QQ_ENABLED=false
QQ_PROTOCOL=onebot
QQ_ONEBOT_HOST=0.0.0.0
QQ_ONEBOT_PORT=8090
QQ_ONEBOT_ACCESS_TOKEN=
FEISHU_ENABLED=false
FEISHU_APP_ID=
FEISHU_APP_SECRET=
FEISHU_VERIFICATION_TOKEN=
FEISHU_WEBHOOK_URL=
DINGTALK_ENABLED=false
DINGTALK_WEBHOOK_URL=
DINGTALK_SECRET=
DINGTALK_APP_KEY=
DINGTALK_APP_SECRET=
PANEL_MODE=web
SETUP_COMPLETED=false
LOG_LEVEL=INFO
LOG_FILE=logs/yuanlo.log
LOG_ROTATION=10 MB
''')
    info ".env template created at $CONFIG_DIR/.env"
else
    info ".env already exists"
fi

# ── Systemd service ──
echo ""
read -rp "  Install systemd service (auto-start on boot)? [y/N] " INSTALL_SVC

if [ "$INSTALL_SVC" = "y" ] || [ "$INSTALL_SVC" = "Y" ]; then
    USER_NAME="${YUANLO_SERVICE_USER:-$USER}"
    SERVICE_FILE="/etc/systemd/system/yuanlo-core-os.service"

    sudo tee "$SERVICE_FILE" > /dev/null << SVC_EOF
[Unit]
Description=Yuanlo Core OS — AI Employee OS
Documentation=https://github.com/zhianyunai-hub/yuanlo-core
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
Environment="YUANLO_CONFIG_DIR=$CONFIG_DIR"
Environment="YUANLO_INSTALL_DIR=$INSTALL_DIR"
EnvironmentFile=$CONFIG_DIR/.env
ExecStart=$PYTHON $INSTALL_DIR/backend/gateway.py
WorkingDirectory=$INSTALL_DIR/backend
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=yuanlo-core-os

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$CONFIG_DIR
MemoryMax=2G

[Install]
WantedBy=multi-user.target
SVC_EOF

    sudo systemctl daemon-reload
    sudo systemctl enable yuanlo-core-os 2>/dev/null || true
    info "Service installed (start: sudo systemctl start yuanlo-core-os)"
    echo ""
    echo -e "  Manage with:"
    echo -e "    sudo systemctl start yuanlo-core-os"
    echo -e "    sudo systemctl status yuanlo-core-os"
    echo -e "    sudo journalctl -u yuanlo-core-os -f"
fi

# ── Next steps ──
echo ""
echo -e "${GREEN}  ══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Yuanlo Core OS installed!${NC}"
echo -e "${GREEN}  ══════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. Run setup wizard:  ${CYAN}$BIN_NAME setup${NC}"
echo -e "  2. Edit config:        ${CYAN}$CONFIG_DIR/.env${NC}"
echo -e "  3. Start server:       ${CYAN}$BIN_NAME serve${NC}"
echo -e "  4. Web dashboard:      ${CYAN}http://localhost:8000${NC}"
echo -e "  5. API docs:           ${CYAN}http://localhost:8000/api/v1/docs${NC}"
echo ""
echo -e "  More commands:         ${CYAN}$BIN_NAME --help${NC}"
echo ""
