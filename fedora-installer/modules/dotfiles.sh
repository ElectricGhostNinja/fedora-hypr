clone_dotfiles() {
    local repo="https://github.com/ElectricGhostNinja/fedora-hypr.git"

    log_info "Setting up dotfiles repository..."

    if [ ! -d "$DOTFILES_DIR" ]; then
        log_info "Cloning dotfiles repository from $repo..."
        git clone "$repo" "$DOTFILES_DIR"
    else
        log_info "Dotfiles directory already exists at $DOTFILES_DIR. Pulling latest changes..."
        git -C "$DOTFILES_DIR" pull
    fi
}
