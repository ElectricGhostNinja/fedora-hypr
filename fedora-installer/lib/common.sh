# Shared settings and helpers. Sourced by install-fedora.sh; not run directly.

# Colors for clear terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directory paths (shared by several modules, so no `local`)
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
