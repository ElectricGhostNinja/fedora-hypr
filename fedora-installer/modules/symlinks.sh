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

link_dotfiles() {
    log_info "Creating symlinks..."

    declare -A CONFIG_MAP=(
        [".config/hypr"]="$HOME/.config/hypr"
        [".config/noctalia"]="$HOME/.config/noctalia"
        [".config/fish"]="$HOME/.config/fish"
        [".config/wezterm"]="$HOME/.config/wezterm"
        [".config/yazi"]="$HOME/.config/yazi"
        [".config/doom"]="$HOME/.config/doom"
    )

    local folder
    for folder in "${!CONFIG_MAP[@]}"; do
        if [ -d "$DOTFILES_DIR/$folder" ]; then
            link_file "$DOTFILES_DIR/$folder" "${CONFIG_MAP[$folder]}"
        else
            log_warn "Config source '$DOTFILES_DIR/$folder' not present in repo; skipping."
        fi
    done

    # Link individual root dotfiles
    local root_dotfiles=(.bashrc .gitconfig .profile .zshrc)
    local file
    for file in "${root_dotfiles[@]}"; do
        if [ -f "$DOTFILES_DIR/$file" ]; then
            link_file "$DOTFILES_DIR/$file" "$HOME/$file"
        fi
    done
}
