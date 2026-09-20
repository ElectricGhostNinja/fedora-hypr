#!/usr/bin/env bash

set -e
set -u
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_requirement() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required tool '$1' is not installed. Please install it first."
        exit 1
    fi
}

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
        log_warn "Fedora $FEDORA_RELEASE is untested."
        ;;
esac

setup_snapper() {
    if [ "$(findmnt -no FSTYPE /)" != "btrfs" ]; then
        log_warn "Root filesystem is not Btrfs; skipping Snapper setup."
        return
    fi
    local snapper_repo_dir="$HOME/sysguides-snapper-fedora"
    if [ -d "$snapper_repo_dir" ]; then
        log_info "Snapper setup repo already present; skipping."
    else
        git clone https://github.com/SysGuides/sysguides-snapper-fedora "$snapper_repo_dir"
    fi
    (cd "$snapper_repo_dir" && chmod +x install.sh && ./install.sh)
}

setup_snapper

setup_rpmfusion() {
    log_info "Enabling RPM Fusion repositories..."
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
}

setup_rpmfusion

log_info "Setting up dotfiles repository..."
if [ ! -d "$DOTFILES_DIR" ]; then
   git clone "https://github.com/ElectricGhostNinja/fedora-hypr.git" "$DOTFILES_DIR"
else
   git -C "$DOTFILES_DIR" pull
fi

install_hyprland_environment() {
    log_info "Installing desktop environment..."
    sudo dnf install -y dnf-plugins-core
    sudo dnf copr enable -y lionheartp/Hyprland wezfurlong/wezterm-nightly lihaohong/yazi
    sudo dnf install -y hyprland hyprland-guiutils xdg-desktop-portal-hyprland noctalia flatpak
}

install_hyprland_environment

log_info "Setup completed successfully!"