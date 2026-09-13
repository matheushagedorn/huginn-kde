#!/usr/bin/env bash
# ==============================================================================
# Huginn — installer
# QuickShell desktop shell for KDE Plasma (Wayland)
# ==============================================================================

set -eo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[info]${NC} $1"; }
success() { echo -e "${GREEN}${BOLD}[ok]${NC} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[warn]${NC} $1"; }
error()   { echo -e "${RED}${BOLD}[error]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
LOCAL_BIN="$HOME/.local/bin"

MISSING_DEPS=()

echo -e "${BOLD}${CYAN}"
echo "=================================================="
echo "   Huginn — QuickShell desktop shell for KDE      "
echo "=================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. Environment check
# ------------------------------------------------------------------------------
check_environment() {
    [ -n "$WAYLAND_DISPLAY" ] || warn "This doesn't look like a Wayland session. Huginn relies on wlr-layer-shell."

    if ! command -v kwriteconfig6 &>/dev/null; then
        warn "kwriteconfig6 not found — this was built for KDE Plasma 6."
    fi

    command -v quickshell &>/dev/null || error "quickshell not found. Install it first (AUR: quickshell / quickshell-git)."
    success "QuickShell found at $(command -v quickshell)"
}

# ------------------------------------------------------------------------------
# 2. Dependencies
# ------------------------------------------------------------------------------
install_dependencies() {
    info "Installing dependencies..."

    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm \
            python python-dbus python-pillow \
            pipewire wireplumber playerctl brightnessctl ddcutil \
            networkmanager bluez bluez-utils \
            wl-clipboard cliphist libnotify lm_sensors jq curl \
            papirus-icon-theme fastfetch \
            || warn "pacman finished with warnings — check the dependency report below."
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y \
            python3 python3-dbus python3-pillow \
            pipewire wireplumber playerctl brightnessctl ddcutil \
            NetworkManager bluez \
            wl-clipboard cliphist libnotify lm_sensors jq curl \
            papirus-icon-theme fastfetch \
            || warn "dnf finished with warnings — check the dependency report below."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y \
            python3 python3-dbus python3-pil \
            pipewire wireplumber playerctl brightnessctl ddcutil \
            network-manager bluez \
            wl-clipboard cliphist libnotify-bin lm-sensors jq curl \
            papirus-icon-theme fastfetch \
            || warn "apt finished with warnings — check the dependency report below."
    else
        warn "Unrecognized package manager. Install the dependencies manually (see the README)."
    fi
}

# The original installer swallowed package failures, so entire features would
# silently do nothing. Here every critical dependency is actually verified.
verify_dependencies() {
    info "Verifying critical dependencies..."

    python3 -c "import dbus" 2>/dev/null || MISSING_DEPS+=("python-dbus (without it the dock can't see open windows)")
    command -v playerctl     &>/dev/null || MISSING_DEPS+=("playerctl (media controls in the bar)")
    command -v wpctl         &>/dev/null || MISSING_DEPS+=("wireplumber/wpctl (volume)")
    command -v brightnessctl &>/dev/null || MISSING_DEPS+=("brightnessctl (brightness)")
    command -v nmcli         &>/dev/null || MISSING_DEPS+=("NetworkManager/nmcli (network)")

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        success "All critical dependencies present."
    else
        warn "Missing:"
        for dep in "${MISSING_DEPS[@]}"; do echo "    - $dep"; done
    fi
}

# ------------------------------------------------------------------------------
# 3. Icon theme in the user's directory
#
# IMPORTANT: papirus-folders escalates itself with sudo when the icon theme
# lives in /usr/share/icons. Called from a service (no TTY) that fails in a
# loop, and pam_faillock will eventually lock the account. Copying the theme to
# ~/.local/share/icons fixes it at the root: no icon operation needs root.
# ------------------------------------------------------------------------------
setup_icon_theme() {
    info "Copying Papirus into the user's directory (avoids sudo escalation)..."
    mkdir -p "$DATA_DIR/icons"

    local copied=0
    for theme in Papirus Papirus-Dark Papirus-Light; do
        if [ -d "/usr/share/icons/$theme" ] && [ ! -d "$DATA_DIR/icons/$theme" ]; then
            cp -r "/usr/share/icons/$theme" "$DATA_DIR/icons/$theme"
            copied=$((copied + 1))
        fi
    done

    if [ "$copied" -gt 0 ]; then
        success "$copied icon theme(s) copied to $DATA_DIR/icons"
    else
        info "Icon themes already present in the user's directory."
    fi
}

# ------------------------------------------------------------------------------
# 4. Configuration
# ------------------------------------------------------------------------------
safe_link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        unlink "$dst"
    elif [ -e "$dst" ]; then
        local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        warn "$(basename "$dst") already existed — moved to $(basename "$backup")"
        mv "$dst" "$backup"
    fi
    ln -s "$src" "$dst"
}

deploy_configs() {
    info "Linking configuration into $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"

    # Symlinked to the repository, so git pull updates the config directly.
    safe_link "$SCRIPT_DIR/quickshell" "$CONFIG_DIR/quickshell"

    for dir in alacritty fastfetch wallust; do
        if [ -d "$SCRIPT_DIR/$dir" ] && [ -n "$(ls -A "$SCRIPT_DIR/$dir" 2>/dev/null)" ]; then
            safe_link "$SCRIPT_DIR/$dir" "$CONFIG_DIR/$dir"
        fi
    done

    chmod +x "$SCRIPT_DIR/quickshell/toggle_launcher.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/quickshell/services/python/"*.py 2>/dev/null || true

    success "Configuration linked."
}

deploy_kde_colorschemes() {
    info "Installing KDE color schemes..."
    mkdir -p "$DATA_DIR/color-schemes" "$DATA_DIR/konsole"

    if [ -d "$SCRIPT_DIR/kde/color-schemes" ]; then
        cp "$SCRIPT_DIR/kde/color-schemes/"*.colors "$DATA_DIR/color-schemes/" 2>/dev/null || true
    fi
    if [ -d "$SCRIPT_DIR/kde/konsole" ]; then
        cp "$SCRIPT_DIR/kde/konsole/"*.colorscheme "$DATA_DIR/konsole/" 2>/dev/null || true
    fi

    success "Color schemes installed."
}

deploy_wallpapers() {
    local wp_base="$HOME/Pictures/Wallpapers"
    if [ -d "$SCRIPT_DIR/quickshell/wallpapers" ]; then
        info "Copying wallpapers to $wp_base..."
        mkdir -p "$wp_base"
        cp -rn "$SCRIPT_DIR/quickshell/wallpapers/"* "$wp_base/" 2>/dev/null || true
        success "Wallpapers copied."
    fi
}

# ------------------------------------------------------------------------------
# 5. Helper scripts (used by the keyboard shortcuts)
# ------------------------------------------------------------------------------
setup_helper_scripts() {
    info "Installing helper scripts into $LOCAL_BIN..."
    mkdir -p "$LOCAL_BIN"

    cat > "$LOCAL_BIN/huginn-volume-up" <<'EOF'
#!/usr/bin/env bash
quickshell ipc call volume increase
EOF

    cat > "$LOCAL_BIN/huginn-volume-down" <<'EOF'
#!/usr/bin/env bash
quickshell ipc call volume decrease
EOF

    cat > "$LOCAL_BIN/huginn-volume-mute" <<'EOF'
#!/usr/bin/env bash
quickshell ipc call volume mute
EOF

    cat > "$LOCAL_BIN/huginn-launcher" <<'EOF'
#!/usr/bin/env bash
quickshell ipc call launcher toggle
EOF

    chmod +x "$LOCAL_BIN"/huginn-*
    success "Helper scripts installed."
}

# ------------------------------------------------------------------------------
# 6. systemd service
# ------------------------------------------------------------------------------
setup_systemd_service() {
    info "Setting up the user service..."
    local service_dir="$CONFIG_DIR/systemd/user"
    mkdir -p "$service_dir"

    local qs_bin
    qs_bin="$(command -v quickshell)"

    cat > "$service_dir/huginn.service" <<EOF
[Unit]
Description=Huginn QuickShell Desktop Shell
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=${qs_bin} -p %h/.config/quickshell
Restart=always
RestartSec=3
Environment=QT_QPA_PLATFORM=wayland
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:%h/.local/bin

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable huginn.service >/dev/null 2>&1 || warn "Could not enable the service automatically."
    systemctl --user restart huginn.service || warn "Could not start the service automatically."

    success "Service configured (huginn.service)."
}

# ------------------------------------------------------------------------------
# 7. Disable Plasma's native volume OSD (optional, asks first)
#
# The native OSD is triggered by the kded module audioshortcutsservice, which
# also handles the volume keys. Disabling it avoids the duplicate OSD, but
# requires rebinding the keys to Huginn's scripts (manual step, listed at the end).
# ------------------------------------------------------------------------------
disable_native_volume_osd() {
    echo
    read -r -p "$(echo -e "${BOLD}Disable Plasma's native volume OSD? [y/N]${NC} ")" answer
    case "$answer" in
        [yY]|[yY][eE][sS])
            if command -v qdbus6 &>/dev/null; then
                qdbus6 org.kde.kded6 /kded org.kde.kded6.setModuleAutoloading audioshortcutsservice false >/dev/null 2>&1 || true
                qdbus6 org.kde.kded6 /kded org.kde.kded6.unloadModule audioshortcutsservice >/dev/null 2>&1 || true
                success "Native OSD disabled (persisted in ~/.config/kded6rc)."
                warn "Rebind the volume keys — instructions at the end."
            else
                warn "qdbus6 not found, skipping."
            fi
            ;;
        *)
            info "Keeping the native OSD. You'll see two OSDs when changing volume."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Run
# ------------------------------------------------------------------------------
check_environment
install_dependencies
verify_dependencies
setup_icon_theme
deploy_configs
deploy_kde_colorschemes
deploy_wallpapers
setup_helper_scripts
setup_systemd_service
disable_native_volume_osd

echo
echo -e "${GREEN}${BOLD}=================================================="
echo "   Huginn installed                               "
echo -e "==================================================${NC}"
echo
echo -e "${BOLD}Keyboard shortcuts (System Settings → Keyboard → Shortcuts → Add New → Command or Script):${NC}"
echo "  Launcher      →  $LOCAL_BIN/huginn-launcher        (suggested: Meta)"
echo "  Volume up     →  $LOCAL_BIN/huginn-volume-up       (physical volume key)"
echo "  Volume down   →  $LOCAL_BIN/huginn-volume-down     (physical volume key)"
echo "  Mute          →  $LOCAL_BIN/huginn-volume-mute     (physical mute key)"
echo
echo -e "${BOLD}Useful commands:${NC}"
echo "  systemctl --user restart huginn.service"
echo "  journalctl --user -u huginn.service -f"
echo
echo -e "${BOLD}To get the Plasma panel out of the way:${NC}"
echo "  right-click the KDE panel → Remove Panel"
echo

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    warn "Pending dependencies (install before using):"
    for dep in "${MISSING_DEPS[@]}"; do echo "    - $dep"; done
fi
