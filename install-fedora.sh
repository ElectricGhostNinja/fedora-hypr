#!/usr/bin/env bash

## Stop the script immediately if any command fails
set -e

# Treat unset variables as errors and exit
set -u

# Prevent errors in piped commands from being hidden
set -o pipefail

# Colors for clear terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directory paths
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Helper functions for clean logging
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if a command exists
check_requirement() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required tool '$1' is not installed. Please install it first."
        exit 1
    fi
}

# ==============================================================================
# 1. PREREQUISITE CHECKS
# ==============================================================================
log_info "Checking prerequisites..."
check_requirement "git"

if ! command -v rpm &> /dev/null; then
    log_error "This installer targets Fedora Linux only."
    exit 1
fi

FEDORA_RELEASE="$(rpm -E %fedora)"
log_info "Detected Fedora release: $FEDORA_RELEASE"

# Ensure dnf-plugins-core is present early so copr and repo commands work
log_info "Ensuring DNF core plugins are available..."
sudo dnf install -y dnf-plugins-core

# ==============================================================================
# 1a. SNAPSHOT MANAGEMENT (SNAPPER)
# ==============================================================================
setup_snapper() {
    if [ "$(findmnt -no FSTYPE /)" != "btrfs" ]; then
        log_warn "Root filesystem is not Btrfs; skipping Snapper setup."
        return 0
    fi

    local snapper_repo_dir="$HOME/sysguides-snapper-fedora"

    if [ -d "$snapper_repo_dir" ]; then
        log_info "Snapper setup repo already present at $snapper_repo_dir; skipping re-clone."
    else
        log_info "Cloning SysGuides Snapper setup scripts..."
        git clone https://github.com/SysGuides/sysguides-snapper-fedora "$snapper_repo_dir"
    fi

    log_warn "Running Snapper setup script..."
    (
        cd "$snapper_repo_dir"
        chmod +x install.sh
        ./install.sh
    ) || log_warn "Snapper installation encountered non-fatal issues; proceeding..."
}

setup_snapper

# ==============================================================================
# 1b. RPM FUSION AND MULTIMEDIA CODECS
# ==============================================================================
setup_rpmfusion() {
    log_info "Enabling RPM Fusion Free and Nonfree repositories..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_RELEASE}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_RELEASE}.noarch.rpm" || true

    log_info "Enabling Cisco OpenH264 repo..."
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 || true

    log_info "Installing multimedia codec support..."
    if rpm -q ffmpeg-free &> /dev/null; then
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || sudo dnf install -y ffmpeg --allowerasing
    else
        sudo dnf install -y ffmpeg --allowerasing
    fi

    log_info "Installing hardware-accelerated drivers..."
    sudo dnf install -y mesa-va-drivers-freeworld mesa-vulkan-drivers-freeworld intel-media-driver || true
}

setup_rpmfusion

# ==============================================================================
# 2. CLONE DOTFILES REPOSITORY
# ==============================================================================
DOTFILES_REPO="https://github.com/ElectricGhostNinja/fedora-hypr.git"

log_info "Setting up dotfiles repository..."

if [ ! -d "$DOTFILES_DIR" ]; then
   log_info "Cloning dotfiles repository from $DOTFILES_REPO..."
   git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
   log_info "Dotfiles directory already exists at $DOTFILES_DIR. Pulling latest changes..."
   git -C "$DOTFILES_DIR" pull
fi

# ==============================================================================
# 3. INSTALL PACKAGES & TOOLING
# ==============================================================================
install_hyprland_environment() {
    log_info "Enabling Copr repositories..."
    sudo dnf copr enable -y lionheartp/Hyprland || log_warn "Failed to enable lionheartp/Hyprland COPR"
    sudo dnf copr enable -y wezfurlong/wezterm-nightly || log_warn "Failed to enable wezterm COPR"
    sudo dnf copr enable -y lihaohong/yazi || log_warn "Failed to enable yazi COPR"

    log_info "Installing Hyprland and core desktop utilities..."
    local hypr_pkgs=(
       # Compositor & Shell
       hyprland
       hyprland-guiutils
       xdg-desktop-portal-hyprland
       noctalia

       # System Tooling
       flatpak
       gcc
       gcc-c++
       make
       clang
       ninja-build
       meson
       nodejs

       # Core Apps & Terminal Utilities
       wezterm
       fzf
       fd-find
       ripgrep
       yazi
       fish
       emacs
       qbittorrent
       fastfetch
       firefox
       gedit
       gnome-disk-utility
       thunar

       # Yazi Preview Helpers
       ffmpegthumbnailer
       7zip
       jq
       poppler-utils
       ImageMagick
       chafa
       zoxide
    )

    sudo dnf install -y "${hypr_pkgs[@]}"

    log_info "Setting up Flathub remote for Flatpak..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_hyprland_environment

install_vscode() {
    if command -v code &> /dev/null; then
        log_info "VS Code is already installed."
        return 0
    fi

    log_info "Adding Microsoft VS Code repository..."
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/vscode.repo > /dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

    sudo dnf check-update || true
    log_info "Installing VS Code..."
    sudo dnf install -y code
}

install_vscode || log_warn "VS Code installation encountered an error."

# ==============================================================================
# 4. SYMLINK CONFIGURATIONS
# ==============================================================================
link_file() {
    local src="$1"
    local dest="$2"
    
    mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]; then
           log_info "Link already correct: $dest"
           return 0
        fi

        log_warn "Existing file found at $dest. Moving to backup..."
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/"
    fi

    log_info "Linking $src -> $dest"
    ln -s "$src" "$dest"
}

log_info "Creating symlinks..."

declare -A CONFIG_MAP=(
    [".config/hypr"]="$HOME/.config/hypr"
    [".config/noctalia"]="$HOME/.config/noctalia"
    [".config/fish"]="$HOME/.config/fish"
    [".config/wezterm"]="$HOME/.config/wezterm"
    [".config/yazi"]="$HOME/.config/yazi"
    [".config/doom"]="$HOME/.config/doom"
)

for folder in "${!CONFIG_MAP[@]:-}"; do
    if [ -n "${folder:-}" ] && [ -d "$DOTFILES_DIR/$folder" ]; then
        link_file "$DOTFILES_DIR/$folder" "${CONFIG_MAP[$folder]}"
    else
        [ -n "${folder:-}" ] && log_warn "Config source '$DOTFILES_DIR/$folder' not present in repo; skipping."
    fi
done

# Link individual root dotfiles
root_dotfiles=(.bashrc .gitconfig .profile .zshrc)
for file in "${root_dotfiles[@]}"; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        link_file "$DOTFILES_DIR/$file" "$HOME/$file"
    fi
done

# Install Doom Emacs *after* linking ~/.config/doom so Doom detects configuration
install_doom_emacs() {
    local doom_dir="$HOME/.config/emacs"

    if [ -d "$doom_dir" ]; then
        log_info "Doom Emacs framework already present at $doom_dir."
    else
        log_info "Cloning Doom Emacs framework..."
        git clone --depth 1 https://github.com/doomemacs/doomemacs "$doom_dir"

        log_info "Running Doom's installer..."
        yes | "$doom_dir/bin/doom" install
    fi

    export PATH="$doom_dir/bin:$PATH"
}

install_doom_emacs || log_warn "Doom Emacs installation encountered an issue."

log_info "Setup completed successfully! Backups (if any) are located in $BACKUP_DIR"

# ==============================================================================
# 5. OPTIONAL INTERACTIVE SETUP
# ==============================================================================
setup_cloudflare_dns() {
    echo
    read -r -p "Configure Cloudflare DNS (1.1.1.1) via systemd-resolved? [y/N] " dns_confirm
    case "$dns_confirm" in
        [yY][eE][sS]|[yY]) ;;
        *)
            log_info "Skipping Cloudflare DNS setup."
            return 0
            ;;
    esac

    log_info "Configuring Cloudflare DNS via systemd-resolved..."

    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo tee /etc/systemd/resolved.conf.d/cloudflare.conf > /dev/null <<'EOF'
[Resolve]
DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
FallbackDNS=
DNSOverTLS=yes
DNSSEC=yes
Domains=~.
Cache=yes
EOF

    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

    sudo systemctl restart systemd-resolved
    log_info "Cloudflare DNS configured successfully."
}

setup_cloudflare_dns