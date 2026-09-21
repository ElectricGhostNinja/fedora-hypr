#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$ROOT/lib/common.sh"
for mod in "$ROOT"/modules/*.sh; do
    source "$mod"
done

# Order matters here
check_prereqs
setup_snapper
setup_rpmfusion
clone_dotfiles
install_hyprland_environment
install_vscode || log_warn "VS Code installation encountered an error."
link_dotfiles
install_doom_emacs || log_warn "Doom Emacs installation encountered an issue."
log_info "Setup completed successfully! Backups (if any) are located in $BACKUP_DIR"
setup_cloudflare_dns
