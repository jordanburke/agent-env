#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# agent-env installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jordanburke/agent-env/main/install.sh | bash
#   # or from a local clone:
#   ./install.sh
# ============================================================================

REPO_URL="https://github.com/jordanburke/agent-env.git"
INSTALL_DIR="${AGENT_ENV_HOME:-$HOME/.local/share/agent-env}"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/agent-env"

# Colors
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

info()    { printf "${BLUE}info${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}ok${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}warn${RESET}  %s\n" "$*"; }

# Detect if running from a local clone or piped from curl
is_local_install() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [[ -f "$script_dir/bin/agent-env" ]]
}

install_from_local() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  info "Installing from local clone: $script_dir"

  mkdir -p "$BIN_DIR"

  if [[ -L "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
  fi

  ln -s "$script_dir/bin/agent-env" "$BIN_LINK"
  success "Linked $BIN_LINK -> $script_dir/bin/agent-env"
}

install_from_remote() {
  info "Cloning agent-env..."

  if [[ -d "$INSTALL_DIR" ]]; then
    info "Existing install found, updating..."
    git -C "$INSTALL_DIR" pull --ff-only
  else
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi

  success "Cloned to $INSTALL_DIR"

  mkdir -p "$BIN_DIR"

  if [[ -L "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
  fi

  ln -s "$INSTALL_DIR/bin/agent-env" "$BIN_LINK"
  success "Linked $BIN_LINK -> $INSTALL_DIR/bin/agent-env"
}

check_path() {
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH"
    printf "\n  Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):\n"
    printf "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}\n\n"
  fi
}

main() {
  printf "\n${BOLD}agent-env${RESET} — Universal secret injection for AI coding agents\n\n"

  if is_local_install; then
    install_from_local
  else
    install_from_remote
  fi

  check_path

  # Verify
  if command -v agent-env &>/dev/null; then
    success "Installation complete! Run 'agent-env help' to get started."
  else
    success "Installation complete!"
    info "Restart your shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
    info "Then run: agent-env help"
  fi

  # Offer init
  printf "\n${BOLD}Quick start:${RESET}\n"
  printf "  agent-env init           # Create .env in your project\n"
  printf "  agent-env init --sops    # Create encrypted .sops.env\n"
  printf "  agent-env run claude     # Launch Claude with secrets\n\n"
}

main "$@"
