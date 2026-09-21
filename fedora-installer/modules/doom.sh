# Run this AFTER link_dotfiles so Doom detects ~/.config/doom
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
