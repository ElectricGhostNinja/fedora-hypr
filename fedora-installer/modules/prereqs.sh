check_prereqs() {
    log_info "Checking prerequisites..."
    check_requirement "git"

    if ! command -v rpm &> /dev/null; then
        log_error "This installer targets Fedora Linux only."
        exit 1
    fi

    # Shared with other modules, so no `local`
    FEDORA_RELEASE="$(rpm -E %fedora)"
    log_info "Detected Fedora release: $FEDORA_RELEASE"

    # Ensure dnf-plugins-core is present early so copr and repo commands work
    log_info "Ensuring DNF core plugins are available..."
    sudo dnf install -y dnf-plugins-core
}
