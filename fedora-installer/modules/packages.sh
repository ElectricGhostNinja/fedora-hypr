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
