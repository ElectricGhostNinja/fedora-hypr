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
