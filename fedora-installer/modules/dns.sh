setup_cloudflare_dns() {
    echo
    read -r -p "Configure Cloudflare DNS (1.1.1.1) via systemd-resolved? [y/N] " dns_confirm
    case "$dns_confirm" in
        [yY][eE][sS]|[yY]) ;;
        *)
            log_info "Skipping Cloudflare DNS setup."
            return 0
            ;;
    esac

    log_info "Configuring Cloudflare DNS via systemd-resolved..."

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

    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

    sudo systemctl restart systemd-resolved
    log_info "Cloudflare DNS configured successfully."
}
