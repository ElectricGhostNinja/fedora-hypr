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
# 1a. SNAPSHOT MANAGEMENT (SNAPPER + GRUB-BTRFS + BTRFS ASSISTANT)
# ==============================================================================
# Placed before RPM Fusion / package installs so the DNF pre/post snapshot
# hooks are active for every transaction the rest of this script performs.
setup_snapper() {
    if [ "$(findmnt -no FSTYPE /)" != "btrfs" ]; then
        log_warn "Root filesystem is not Btrfs; skipping Snapper setup."
        return
    fi

    local snapper_repo_dir="$HOME/sysguides-snapper-fedora"

    if [ -d "$snapper_repo_dir" ]; then
        log_info "Snapper setup repo already present at $snapper_repo_dir; skipping re-clone."
    else
        log_info "Cloning SysGuides Snapper setup scripts..."
        git clone https://github.com/SysGuides/sysguides-snapper-fedora "$snapper_repo_dir"
    fi

    log_warn "About to run a third-party installer that modifies GRUB and installs DNF hooks."
    log_warn "Review it yourself at https://github.com/SysGuides/sysguides-snapper-fedora if you haven't already."

    (
        cd "$snapper_repo_dir"
        chmod +x install.sh
        ./install.sh
    )

    log_warn "A reboot is recommended after this step for the GRUB snapshot menu to take effect."
}

setup_snapper

# ==============================================================================
# 1b. RPM FUSION (FREE + NONFREE) AND MULTIMEDIA CODECS
# ==============================================================================
setup_rpmfusion() {
    log_info "Enabling RPM Fusion Free and Nonfree repositories..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

    log_info "Enabling the Cisco OpenH264 repo..."
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

    log_info "Installing full multimedia codec support..."
    if rpm -q ffmpeg-free &> /dev/null; then
        # Swap Fedora's codec-light ffmpeg-free for the full RPM Fusion build
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    else
        sudo dnf install -y ffmpeg --allowerasing
    fi

    sudo dnf group upgrade -y multimedia \
        --setopt="install_weak_deps=False" \
        --exclude=PackageKit-gstreamer-plugin
    sudo dnf group upgrade -y sound-and-video

    log_info "Installing AMD (mesa) hardware-accelerated codec drivers..."
    sudo dnf install -y mesa-va-drivers-freeworld

    if rpm -q mesa-vulkan-drivers &> /dev/null; then
        sudo dnf swap -y mesa-vulkan-drivers{,-freeworld}
    else
        log_info "mesa-vulkan-drivers already swapped (or not present); skipping swap."
    fi

    # i686 (32-bit) compat versions, needed for Steam and similar 32-bit apps
    sudo dnf install -y mesa-va-drivers-freeworld.i686
    if rpm -q mesa-vulkan-drivers.i686 &> /dev/null; then
        sudo dnf swap -y mesa-vulkan-drivers{,-freeworld}.i686
    else
        log_info "mesa-vulkan-drivers.i686 already swapped (or not present); skipping swap."
    fi

    log_info "Installing Intel hardware-accelerated codec drivers..."
    # intel-media-driver covers Broadwell (2014) and newer. If you're on older
    # Intel hardware, swap this for: sudo dnf install -y libva-intel-driver
    sudo dnf install -y intel-media-driver

    log_info "Enabling RPM Fusion Nonfree Tainted repo for closed-source firmware..."
    sudo dnf install -y rpmfusion-nonfree-release-tainted
    sudo dnf --repo=rpmfusion-nonfree-tainted install -y "*-firmware"
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
       hyprland-guiutils
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

install_vscode() {
    if command -v code &> /dev/null; then
        log_info "VS Code is already installed."
        return
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

    # dnf check-update exits 100 when updates are found, which set -e treats as failure
    sudo dnf check-update || true

    log_info "Installing VS Code..."
    sudo dnf install -y code
}

install_doom_emacs() {
    local doom_dir="$HOME/.config/emacs"

    if [ -d "$doom_dir" ]; then
        log_info "Doom Emacs framework already present at $doom_dir."
    else
        log_info "Cloning Doom Emacs framework..."
        git clone --depth 1 https://github.com/doomemacs/doomemacs "$doom_dir"

        log_info "Running Doom's installer (auto-confirming prompts)..."
        yes | "$doom_dir/bin/doom" install
    fi

    # Make the 'doom' CLI available for the rest of this script and future shells
    export PATH="$doom_dir/bin:$PATH"
}

install_vscode || log_warn "VS Code install failed; continuing with the rest of the script."
install_doom_emacs || log_warn "Doom Emacs install failed; continuing with the rest of the script."

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
    [".config/doom"]="$HOME/.config/doom"
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

# ==============================================================================
# 6. CLOUDFLARE DNS (OPTIONAL, INTERACTIVE — RUNS LAST)
# ==============================================================================
# Uses systemd-resolved (which NetworkManager already defers DNS to on Fedora)
# rather than systemd-networkd, so it doesn't fight NetworkManager for control
# of your Wi-Fi interface. No hardcoded interface name needed either way.
setup_cloudflare_dns() {
    echo
    read -r -p "Configure Cloudflare DNS (1.1.1.1) via systemd-resolved with DNS-over-TLS + DNSSEC? [y/N] " dns_confirm
    case "$dns_confirm" in
        [yY][eE][sS]|[yY]) ;;
        *)
            log_info "Skipping Cloudflare DNS setup."
            return
            ;;
    esac

    log_info "Configuring Cloudflare DNS via systemd-resolved..."

    # Drop-in file, so we're not overwriting the package-managed resolved.conf directly
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

    # Make sure NetworkManager hands DNS resolution off to systemd-resolved
    # instead of writing DHCP-provided nameservers straight into /etc/resolv.conf
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

    sudo systemctl restart systemd-resolved

    log_info "Cloudflare DNS configured. Verify with: resolvectl status"
}

setup_cloudflare_dns
