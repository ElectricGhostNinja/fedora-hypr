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
case "$FEDORA_RELEASE" in
    rawhide|4[4-9]|5[0-9]) ;;
    *)
        log_warn "Fedora $FEDORA_RELEASE is untested. noctalia and 7zip come from official repos on Fedora 44+ only; yazi always comes from a COPR. The install may fail."
        ;;
esac

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
    if ! sudo dnf copr list --installed &> /dev/null; then
        log_info "Installing dnf-plugin-core for 'dnf copr' support..."
        sudo dnf install -y dnf-plugins-core
    fi
    sudo dnf copr enable -y lionheartp/Hyprland
    sudo dnf copr enable -y wezfurlong/wezterm-nightly
    sudo dnf copr enable -y lihaohong/yazi

    log_info "Installing Hyprland and core desktop utilities..."
    local hypr_pkgs=(
       # Compositor & Shell
       hyprland
       xdg-desktop-portal-hyprland
       noctalia

       # System Tooling
       flatpak
       gcc
       gcc-c++
       make
       clang
       ninja
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

       # Yazi Preview Helper Dependencies
       ffmpegthumbnailer
       7zip
       jq
       poppler-utils
       imageMagick
       chafa
       zoxide
    )

    sudo dnf install -y "${hypr_pkgs[@]}"

    # Setup Flathub Repository for Flatpak
    log_info "Setting up Flathub remote for Flatpak..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

# Execute package installation
install_hyprland_environment

# ==============================================================================
# 4. SYMLINK CONFIGURATIONS
# ==============================================================================
# Function to safely create a symlink with backup
link_file() {
    local src="$1"
    local dest="$2"
    # Create destination parent directory if it doesn't exist
    mkdir -p "$(dirname "$dest")"

    # If the destination already exists and isn't already pointing to the source file
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]; then
           log_info "Link already correct: $dest"
           return
        fi

        log_warn "Existing file found at $dest. Moving to backup..."
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/"
    fi

    log_info "Linking $src -> $dest"
    ln -s "$src" "$dest"
}

log_info "Creating symlinks..."

# Map repo directories to ~/.config target locations
declare -A CONFIG_MAP=(
    [".config/hypr"]="$HOME/.config/hypr"
    [".config/noctalia"]="$HOME/.config/noctalia"
    [".config/fish"]="$HOME/.config/fish"
    [".config/wezterm"]="$HOME/.config/wezterm"
    [".config/yazi"]="$HOME/.config/yazi"
    [".config/emacs"]="$HOME/.config/emacs"
)

for folder in "${!CONFIG_MAP[@]}"; do
    if [ -d "$DOTFILES_DIR/$folder" ]; then
        link_file "$DOTFILES_DIR/$folder" "${CONFIG_MAP[$folder]}"
    else
        log_warn "Config source '$DOTFILES_DIR/$folder' not present in repo; skipping."
    fi
done

# Link individual dotfiles from the root of the repo, if present
root_dotfiles=(.bashrc .gitconfig .profile .zshrc)
for file in "${root_dotfiles[@]}"; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        link_file "$DOTFILES_DIR/$file" "$HOME/$file"
    fi
done

log_info "Setup completed successfully! If any backups were created, they are located in $BACKUP_DIR"
