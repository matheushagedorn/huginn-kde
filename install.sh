#!/usr/bin/env bash
# ==============================================================================
# Huginn — instalador
# Shell de desktop em QuickShell para KDE Plasma (Wayland)
# ==============================================================================

set -eo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[info]${NC} $1"; }
success() { echo -e "${GREEN}${BOLD}[ok]${NC} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[aviso]${NC} $1"; }
error()   { echo -e "${RED}${BOLD}[erro]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
LOCAL_BIN="$HOME/.local/bin"

MISSING_DEPS=()

echo -e "${BOLD}${CYAN}"
echo "=================================================="
echo "   Huginn — QuickShell desktop shell para KDE     "
echo "=================================================="
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. Checagem de ambiente
# ------------------------------------------------------------------------------
check_environment() {
    [ -n "$WAYLAND_DISPLAY" ] || warn "Sessão não parece ser Wayland. O Huginn depende de wlr-layer-shell."

    if ! command -v kwriteconfig6 &>/dev/null; then
        warn "kwriteconfig6 não encontrado — isto foi feito para KDE Plasma 6."
    fi

    command -v quickshell &>/dev/null || error "quickshell não encontrado. Instale-o antes (AUR: quickshell / quickshell-git)."
    success "QuickShell encontrado em $(command -v quickshell)"
}

# ------------------------------------------------------------------------------
# 2. Dependências
# ------------------------------------------------------------------------------
install_dependencies() {
    info "Instalando dependências..."

    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm \
            python python-dbus python-pillow \
            pipewire wireplumber playerctl brightnessctl ddcutil \
            networkmanager bluez bluez-utils \
            wl-clipboard cliphist libnotify lm_sensors jq curl \
            papirus-icon-theme fastfetch \
            || warn "pacman terminou com avisos — confira as dependências abaixo."
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y \
            python3 python3-dbus python3-pillow \
            pipewire wireplumber playerctl brightnessctl ddcutil \
            NetworkManager bluez \
            wl-clipboard cliphist libnotify lm_sensors jq curl \
            papirus-icon-theme fastfetch \
            || warn "dnf terminou com avisos — confira as dependências abaixo."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y \
            python3 python3-dbus python3-pil \
            pipewire wireplumber playerctl brightnessctl ddcutil \
            network-manager bluez \
            wl-clipboard cliphist libnotify-bin lm-sensors jq curl \
            papirus-icon-theme fastfetch \
            || warn "apt terminou com avisos — confira as dependências abaixo."
    else
        warn "Gerenciador de pacotes não reconhecido. Instale as dependências à mão (veja o README)."
    fi
}

# O instalador original engolia falhas de pacote em silêncio e a funcionalidade
# sumia sem erro visível. Aqui cada dependência crítica é verificada de verdade.
verify_dependencies() {
    info "Verificando dependências críticas..."

    python3 -c "import dbus" 2>/dev/null || MISSING_DEPS+=("python-dbus (sem ele o dock não mostra janelas abertas)")
    command -v playerctl   &>/dev/null || MISSING_DEPS+=("playerctl (controle de mídia na barra)")
    command -v wpctl       &>/dev/null || MISSING_DEPS+=("wireplumber/wpctl (volume)")
    command -v brightnessctl &>/dev/null || MISSING_DEPS+=("brightnessctl (brilho)")
    command -v nmcli       &>/dev/null || MISSING_DEPS+=("NetworkManager/nmcli (rede)")

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        success "Todas as dependências críticas presentes."
    else
        warn "Faltando:"
        for dep in "${MISSING_DEPS[@]}"; do echo "    - $dep"; done
    fi
}

# ------------------------------------------------------------------------------
# 3. Tema de ícones na pasta do usuário
#
# IMPORTANTE: o papirus-folders se auto-eleva com sudo quando o tema está em
# /usr/share/icons. Rodando a partir de um serviço (sem TTY) isso falha em loop
# e o pam_faillock chega a travar a conta. Copiar para ~/.local/share/icons
# resolve na raiz: nenhuma operação de ícone precisa de root.
# ------------------------------------------------------------------------------
setup_icon_theme() {
    info "Copiando Papirus para a pasta do usuário (evita escalonamento por sudo)..."
    mkdir -p "$DATA_DIR/icons"

    local copied=0
    for theme in Papirus Papirus-Dark Papirus-Light; do
        if [ -d "/usr/share/icons/$theme" ] && [ ! -d "$DATA_DIR/icons/$theme" ]; then
            cp -r "/usr/share/icons/$theme" "$DATA_DIR/icons/$theme"
            copied=$((copied + 1))
        fi
    done

    if [ "$copied" -gt 0 ]; then
        success "$copied tema(s) de ícone copiado(s) para $DATA_DIR/icons"
    else
        info "Temas de ícone já presentes na pasta do usuário."
    fi
}

# ------------------------------------------------------------------------------
# 4. Configurações
# ------------------------------------------------------------------------------
safe_link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        unlink "$dst"
    elif [ -e "$dst" ]; then
        local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        warn "$(basename "$dst") já existia — movido para $(basename "$backup")"
        mv "$dst" "$backup"
    fi
    ln -s "$src" "$dst"
}

deploy_configs() {
    info "Ligando configurações em $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"

    # Symlink para o repositório: git pull atualiza a config direto.
    safe_link "$SCRIPT_DIR/quickshell" "$CONFIG_DIR/quickshell"

    for dir in alacritty fastfetch wallust; do
        if [ -d "$SCRIPT_DIR/$dir" ] && [ -n "$(ls -A "$SCRIPT_DIR/$dir" 2>/dev/null)" ]; then
            safe_link "$SCRIPT_DIR/$dir" "$CONFIG_DIR/$dir"
        fi
    done

    chmod +x "$SCRIPT_DIR/quickshell/toggle_launcher.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/quickshell/services/python/"*.py 2>/dev/null || true

    success "Configurações ligadas."
}

deploy_kde_colorschemes() {
    info "Instalando esquemas de cor do KDE..."
    mkdir -p "$DATA_DIR/color-schemes" "$DATA_DIR/konsole"

    if [ -d "$SCRIPT_DIR/kde/color-schemes" ]; then
        cp "$SCRIPT_DIR/kde/color-schemes/"*.colors "$DATA_DIR/color-schemes/" 2>/dev/null || true
    fi
    if [ -d "$SCRIPT_DIR/kde/konsole" ]; then
        cp "$SCRIPT_DIR/kde/konsole/"*.colorscheme "$DATA_DIR/konsole/" 2>/dev/null || true
    fi

    success "Esquemas de cor instalados."
}

deploy_wallpapers() {
    local wp_base="$HOME/Pictures/Wallpapers"
    if [ -d "$SCRIPT_DIR/quickshell/wallpapers" ]; then
        info "Copiando wallpapers para $wp_base..."
        mkdir -p "$wp_base"
        cp -rn "$SCRIPT_DIR/quickshell/wallpapers/"* "$wp_base/" 2>/dev/null || true
        success "Wallpapers copiados."
    fi
}

# ------------------------------------------------------------------------------
# 5. Scripts auxiliares (usados pelos atalhos de teclado)
# ------------------------------------------------------------------------------
setup_helper_scripts() {
    info "Instalando scripts auxiliares em $LOCAL_BIN..."
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
    success "Scripts instalados."
}

# ------------------------------------------------------------------------------
# 6. Serviço systemd
# ------------------------------------------------------------------------------
setup_systemd_service() {
    info "Configurando serviço do usuário..."
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
    systemctl --user enable huginn.service >/dev/null 2>&1 || warn "Não foi possível habilitar o serviço automaticamente."
    systemctl --user restart huginn.service || warn "Não foi possível iniciar o serviço automaticamente."

    success "Serviço configurado (huginn.service)."
}

# ------------------------------------------------------------------------------
# 7. Desativa o OSD nativo de volume do Plasma (opcional, pergunta antes)
#
# Quem dispara o OSD nativo é o módulo audioshortcutsservice do kded — ele
# também é quem processa as teclas de volume. Desligá-lo evita o OSD duplicado,
# mas exige reapontar as teclas para os scripts do Huginn (passo manual, no fim).
# ------------------------------------------------------------------------------
disable_native_volume_osd() {
    echo
    read -r -p "$(echo -e "${BOLD}Desativar o OSD de volume nativo do Plasma? [s/N]${NC} ")" answer
    case "$answer" in
        [sS]|[sS][iI][mM]|[yY]|[yY][eE][sS])
            if command -v qdbus6 &>/dev/null; then
                qdbus6 org.kde.kded6 /kded org.kde.kded6.setModuleAutoloading audioshortcutsservice false >/dev/null 2>&1 || true
                qdbus6 org.kde.kded6 /kded org.kde.kded6.unloadModule audioshortcutsservice >/dev/null 2>&1 || true
                success "OSD nativo desativado (persiste em ~/.config/kded6rc)."
                warn "Reaponte as teclas de volume — instruções no fim."
            else
                warn "qdbus6 não encontrado, pulando."
            fi
            ;;
        *)
            info "Mantendo o OSD nativo. Você verá dois OSDs ao mudar o volume."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Execução
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
echo "   Huginn instalado                               "
echo -e "==================================================${NC}"
echo
echo -e "${BOLD}Atalhos de teclado (System Settings → Keyboard → Shortcuts → Add New → Command or Script):${NC}"
echo "  Launcher      →  $LOCAL_BIN/huginn-launcher        (sugestão: Meta)"
echo "  Volume +      →  $LOCAL_BIN/huginn-volume-up       (tecla física de volume)"
echo "  Volume -      →  $LOCAL_BIN/huginn-volume-down     (tecla física de volume)"
echo "  Mudo          →  $LOCAL_BIN/huginn-volume-mute     (tecla física de mudo)"
echo
echo -e "${BOLD}Comandos úteis:${NC}"
echo "  systemctl --user restart huginn.service"
echo "  journalctl --user -u huginn.service -f"
echo
echo -e "${BOLD}Para deixar a barra do Plasma fora do caminho:${NC}"
echo "  clique direito no painel do KDE → Remove Panel"
echo

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    warn "Dependências pendentes (instale antes de usar):"
    for dep in "${MISSING_DEPS[@]}"; do echo "    - $dep"; done
fi
