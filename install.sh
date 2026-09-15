#!/usr/bin/env bash
# ==============================================================================
# Huginn — installer
# Huginn desktop shell for KDE Plasma (Wayland)
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
echo "   Huginn — desktop shell for KDE Plasma            "
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
    safe_link "$SCRIPT_DIR/shell" "$CONFIG_DIR/huginn"

    for dir in fastfetch wallust; do
        if [ -d "$SCRIPT_DIR/$dir" ] && [ -n "$(ls -A "$SCRIPT_DIR/$dir" 2>/dev/null)" ]; then
            safe_link "$SCRIPT_DIR/$dir" "$CONFIG_DIR/$dir"
        fi
    done

    chmod +x "$SCRIPT_DIR/shell/services/python/"*.py 2>/dev/null || true

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

# Wallpapers are not shipped with Huginn. Each theme variant looks for a folder
# named after it under ~/Pictures/Wallpapers, and falls back to whatever the
# scanner finds there. This only creates the folder and says what to put in it.
deploy_wallpapers() {
    local wp_base="$HOME/Pictures/Wallpapers"
    mkdir -p "$wp_base"
    if [ -z "$(ls -A "$wp_base" 2>/dev/null)" ]; then
        info "No wallpapers found in $wp_base."
        info "Add one folder per theme, for example: $wp_base/Tokyo Night/"
    fi
}

# ------------------------------------------------------------------------------
# 5. Helper scripts and their keyboard shortcuts
#
# Everything Huginn installs outside the repository is named huginn-*. The
# shortcuts are registered here rather than left as a manual step, because a
# name typed by hand in the System Settings dialog is a name that drifts.
# ------------------------------------------------------------------------------
HELPERS=(
    "huginn-volume-up:quickshell -p \"$HOME/.config/huginn\" ipc call volume increase"
    "huginn-volume-down:quickshell -p \"$HOME/.config/huginn\" ipc call volume decrease"
    "huginn-volume-mute:quickshell -p \"$HOME/.config/huginn\" ipc call volume mute"
    "huginn-launcher:quickshell -p \"$HOME/.config/huginn\" ipc call launcher toggle"
    "huginn-lock:touch /tmp/huginn_lock_trigger 2>/dev/null || true; loginctl lock-session"
)

setup_helper_scripts() {
    info "Installing helper scripts into $LOCAL_BIN..."
    mkdir -p "$LOCAL_BIN"

    local entry name body
    for entry in "${HELPERS[@]}"; do
        name="${entry%%:*}"
        body="${entry#*:}"
        printf '#!/usr/bin/env bash\n%s\n' "$body" > "$LOCAL_BIN/$name"
        chmod +x "$LOCAL_BIN/$name"
    done

    success "Helper scripts installed (${#HELPERS[@]})."
}

# helper : key : label
#
# These take effect on the next login, not now. kglobalaccel lives inside
# kwin_wayland and builds its shortcut table once, when the session starts, so a
# .desktop written afterwards is simply not there. Registering over D-Bus from a
# short-lived process creates the entry but never takes the key, so the installer
# does not pretend otherwise: it writes the file and says to log out.
SHORTCUTS=(
    "huginn-volume-up:Volume Up:Volume Up"
    "huginn-volume-down:Volume Down:Volume Down"
    "huginn-volume-mute:Volume Mute:Mute"
    "huginn-launcher:Meta:App Launcher"
    "huginn-lock::"
)

# Plasma claims these keys through its own kmix component. Two components on one
# key and neither answers reliably, so kmix gives them up. The second field of
# the value is the default binding, kept so System Settings can still restore it.
CONFLICTS=(
    "kmix:increase_volume:Volume Up:Increase Volume"
    "kmix:decrease_volume:Volume Down:Decrease Volume"
    "kmix:mute:Volume Mute:Mute"
)

release_conflicting_shortcuts() {
    command -v kwriteconfig6 >/dev/null 2>&1 || return 0
    local entry comp action default_key label
    for entry in "${CONFLICTS[@]}"; do
        IFS=: read -r comp action default_key label <<< "$entry"
        kwriteconfig6 --file kglobalshortcutsrc --group "$comp" --key "$action" \
            "none,${default_key},${label}" 2>/dev/null || true
    done
}

setup_shortcuts() {
    if ! command -v kwriteconfig6 >/dev/null 2>&1; then
        warn "kwriteconfig6 not found; skipping shortcut registration."
        return
    fi

    info "Registering keyboard shortcuts..."
    local apps_dir="$HOME/.local/share/applications"
    mkdir -p "$apps_dir"

    release_conflicting_shortcuts

    local entry name key label desktop_id
    for entry in "${SHORTCUTS[@]}"; do
        IFS=: read -r name key label <<< "$entry"
        desktop_id="net.local.${name}.desktop"

        cat > "$apps_dir/$desktop_id" <<EOF
[Desktop Entry]
Exec=${LOCAL_BIN}/${name}
Name=${label}
NoDisplay=true
StartupNotify=false
Type=Application
X-KDE-GlobalAccel-CommandShortcut=true
EOF

        [ -z "$key" ] && continue
        kwriteconfig6 --file kglobalshortcutsrc \
            --group "services" --group "$desktop_id" \
            --key "_launch" "$key" 2>/dev/null || true
    done

    update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    kbuildsycoca6 >/dev/null 2>&1 || true
    success "Shortcuts written (they start working after the next login)."
}

# Removes the names this project used before it was called Huginn, so a machine
# upgraded from the old layout does not keep two scripts doing the same thing.
clean_legacy_names() {
    local apps_dir="$HOME/.local/share/applications"
    local legacy removed=0
    for legacy in quickshell-volume-up quickshell-volume-down quickshell-volume-mute \
                  quickshell-lock refresh-quickshell; do
        [ -e "$LOCAL_BIN/$legacy" ] && { rm -f "$LOCAL_BIN/$legacy"; removed=1; }
        [ -e "$apps_dir/net.local.${legacy}.desktop" ] && {
            rm -f "$apps_dir/net.local.${legacy}.desktop"
            # Deleting the key is what actually removes the binding; an empty
            # group header is dropped the next time KConfig rewrites the file.
            kwriteconfig6 --file kglobalshortcutsrc --group "services" \
                --group "net.local.${legacy}.desktop" --key "_launch" --delete >/dev/null 2>&1 || true
            removed=1
        }
    done
    # The old launcher entry pointed straight at a script inside the repository.
    if [ -e "$apps_dir/net.local.toggle_launcher.sh.desktop" ]; then
        rm -f "$apps_dir/net.local.toggle_launcher.sh.desktop"
        kwriteconfig6 --file kglobalshortcutsrc --group "services" \
            --group "net.local.toggle_launcher.sh.desktop" --key "_launch" --delete >/dev/null 2>&1 || true
        removed=1
    fi
    # Units carried the old name before the rename.
    local unit
    # The config directory used to be named after the framework. A machine
    # coming from that layout has a stale symlink pointing at it.
    if [ -L "$CONFIG_DIR/quickshell" ]; then
        rm -f "$CONFIG_DIR/quickshell"
        info "Removed the old ~/.config/quickshell link; the shell now lives in ~/.config/huginn."
    fi

    for unit in quickshell.service quickshell-recolor-watcher.service; do
        if [ -f "$CONFIG_DIR/systemd/user/$unit" ]; then
            systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
            rm -f "$CONFIG_DIR/systemd/user/$unit"
            removed=1
        fi
    done

    # State files named after the framework rather than the project.
    local state
    for state in current_theme.txt user_wallpaper.json user_pinned.json; do
        if [ -f "$CONFIG_DIR/quickshell_$state" ] && [ ! -f "$CONFIG_DIR/huginn_$state" ]; then
            mv "$CONFIG_DIR/quickshell_$state" "$CONFIG_DIR/huginn_$state"
            removed=1
        fi
    done

    # KDE colour schemes were prefixed "QS " before the project had a name.
    local scheme
    for scheme in "$DATA_DIR"/color-schemes/*.colors; do
        [ -f "$scheme" ] || continue
        sed -i 's/^Name=QS /Name=Huginn /' "$scheme" 2>/dev/null || true
    done
    [ "$removed" = 1 ] && info "Removed leftovers from the pre-Huginn layout."
    return 0
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
Description=Huginn desktop shell
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=${qs_bin} -p %h/.config/huginn
Restart=always
RestartSec=3
Environment=QT_QPA_PLATFORM=wayland
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:%h/.local/bin
# Holds the unit in "activating" until the shell actually answers, so anything
# ordered after it starts against a screen the bar has already claimed.
ExecStartPost=/usr/bin/bash -c 'n=0; while [ \$n -lt 60 ]; do ${qs_bin} -p %h/.config/huginn ipc show >/dev/null 2>&1 && exit 0; sleep 0.1; n=\$((n+1)); done; exit 0'

[Install]
WantedBy=graphical-session.target
EOF

    # Recolors the wallpaper with lutgen whenever the theme changes, and
    # repaints the Papirus folder icons. Safe to run unattended only because
    # setup_icon_theme put Papirus under the user's own directory: from
    # /usr/share, papirus-folders re-invokes itself with sudo, and with no TTY
    # to answer it that turns into a loop that locks the account via faillock.
    cat > "$service_dir/huginn-recolor-watcher.service" <<EOF
[Unit]
Description=Huginn wallpaper recolor watcher
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 %h/.config/huginn/services/python/recolor_watcher.py
Restart=always
RestartSec=3
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:%h/.local/bin:%h/.cargo/bin

[Install]
WantedBy=graphical-session.target
EOF

    # Session restore has to wait for the bar to exist.
    #
    # KWin restores last session's windows about 350ms before the shell finishes
    # loading, so the windows are placed against the full screen and end up
    # under the top bar. A non-maximized window is never re-placed afterwards,
    # so they stay there until you resize them by hand.
    #
    # ExecStartPost above holds the unit in "activating" until the shell answers
    # on IPC, and these drop-ins order the restore after it. The probe gives up
    # after six seconds so a broken shell can never hold the session hostage.
    local restore_units=(
        "plasma-restoresession.service"
        'app-org.kde.plasma\x2dfallback\x2dsession\x2drestore@autostart.service'
    )
    local restore_unit
    for restore_unit in "${restore_units[@]}"; do
        mkdir -p "$service_dir/${restore_unit}.d"
        cat > "$service_dir/${restore_unit}.d/wait-for-huginn.conf" <<EOF
[Unit]
After=huginn.service
Wants=huginn.service
EOF
    done

    systemctl --user daemon-reload
    for unit in huginn.service huginn-recolor-watcher.service; do
        systemctl --user enable "$unit" >/dev/null 2>&1 || warn "Could not enable $unit automatically."
        systemctl --user restart "$unit" || warn "Could not start $unit automatically."
    done

    success "Services configured (huginn.service, huginn-recolor-watcher.service)."
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
clean_legacy_names
setup_helper_scripts
setup_shortcuts
setup_systemd_service
disable_native_volume_osd

echo
echo -e "${GREEN}${BOLD}=================================================="
echo "   Huginn installed                               "
echo -e "==================================================${NC}"
echo
echo -e "${BOLD}${YELLOW}Log out and back in to finish.${NC}"
echo "  KDE builds its keyboard shortcut table when the session starts, so the"
echo "  keys below do nothing until then. Nothing else is pending."
echo
echo -e "${BOLD}Keyboard shortcuts:${NC}"
echo "  Meta          →  huginn-launcher"
echo "  Volume Up     →  huginn-volume-up"
echo "  Volume Down   →  huginn-volume-down"
echo "  Volume Mute   →  huginn-volume-mute"
echo "  (no key)      →  huginn-lock"
echo
echo "  The scripts are in $LOCAL_BIN and the bindings are listed under"
echo "  System Settings → Keyboard → Shortcuts."
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
