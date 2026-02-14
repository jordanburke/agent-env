#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# agent-env uninstaller
#
# Removes agent-env binary link and optionally the cloned repository.
# Never touches secrets files or encryption keys.
# ============================================================================

INSTALL_DIR="${AGENT_ENV_HOME:-$HOME/.local/share/agent-env}"
BIN_LINK="$HOME/.local/bin/agent-env"

# Colors
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

info()    { printf "  %s\n" "$*"; }
success() { printf "${GREEN}ok${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}warn${RESET}  %s\n" "$*"; }

main() {
  printf "\n${BOLD}agent-env uninstaller${RESET}\n\n"

  # Remove symlink
  if [[ -L "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
    success "Removed $BIN_LINK"
  elif [[ -f "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
    success "Removed $BIN_LINK"
  else
    info "No binary link found at $BIN_LINK"
  fi

  # Remove cloned repo
  if [[ -d "$INSTALL_DIR" ]]; then
    printf "\n  Remove cloned repository at ${BOLD}%s${RESET}? [y/N] " "$INSTALL_DIR"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      rm -rf "$INSTALL_DIR"
      success "Removed $INSTALL_DIR"
    else
      info "Kept $INSTALL_DIR"
    fi
  fi

  # What we don't touch
  printf "\n${YELLOW}The following were NOT removed (your secrets are safe):${RESET}\n"
  info ".env and .sops.env files in your projects"
  info "~/.config/agent-env/ (global secrets)"
  info "~/.config/sops/age/keys.txt (age encryption keys)"
  info ".sops.yaml files in your projects"

  printf "\n${GREEN}agent-env has been uninstalled.${RESET}\n\n"
}

main "$@"
