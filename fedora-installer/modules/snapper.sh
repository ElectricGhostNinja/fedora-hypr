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
        sudo ./install.sh
    ) || log_warn "Snapper installation encountered non-fatal issues; proceeding..."
}
