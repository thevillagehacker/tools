#!/usr/bin/env bash
# ===============================================
#  Automated Setup Script for Recon & Bounty Tools
# ===============================================
#  Author: Naveen Jagadeesan(thevillagehacker)
#  Description: Sets up Zsh, Go, PDTM, GRC, and 
#               installs key recon tools.
# ===============================================

set -euo pipefail
IFS=$'\n\t'

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

# --- Privilege check & disclaimer ---
if [[ "$EUID" -ne 0 ]]; then
  echo -e "\n${YELLOW}[NOTE]${RESET} Some operations require administrative privileges."
  echo -e "${YELLOW}[ACTION REQUIRED]${RESET} Please run this script with sudo:"
  echo -e "  ${BLUE}sudo ./setup.sh${RESET}\n"
  exit 1
fi


# ---[ Helper Functions ]---

print_info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
print_error() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h, --help       Show this help message and exit.

Description:
  This script installs and configures:
    - Zsh, Go, GRC
    - PDTM & related tools
    - haktrails, anew, gospider, massdns (puredns), Nmap
    - Bug bounty directory setup

Example:
  chmod +x setup.sh
  ./setup.sh
EOF
  exit 0
}

# ---[ Core Steps ]---

update_system() {
  print_info "Updating system packages..."
  sudo apt-get update -y
  print_success "System update completed."
}

install_packages() {
  print_info "Installing Zsh, Go, and GRC..."
  sudo apt-get install -y zsh golang grc make git curl
  print_success "Packages installed."
}

configure_zshrc() {
  local zshrc="$HOME/.zshrc"
  print_info "Configuring .zshrc..."

  # Add GOPATH and PATH if not already added
  grep -q "export GOPATH=" "$zshrc" || {
    echo 'export GOPATH=$HOME/go' >> "$zshrc"
    echo 'export PATH=$PATH:$GOPATH/bin' >> "$zshrc"
  }

  # Add aliases
  grep -q "alias ll=" "$zshrc" || cat <<'ALIASES' >> "$zshrc"
alias ll='ls -lshaF --color=auto'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
alias h='fc -lt "%F %T"'s
ALIASES

  # Add GRC integration
  grep -q "grc.zsh" "$zshrc" || echo '[[ -s "/etc/grc.zsh" ]] && source /etc/grc.zsh' >> "$zshrc"

  print_success ".zshrc configuration updated."
}

install_pdtm() {
  print_info "Installing PDTM..."
  go install github.com/projectdiscovery/pdtm/cmd/pdtm@latest

  local zshrc="$HOME/.zshrc"
  grep -q "pdtm" "$zshrc" || echo 'export PATH=$PATH:$HOME/go/bin' >> "$zshrc"

  print_success "PDTM installed and path added."
  print_info "Installing PDTM tools..."
  pdtm -ia || print_warn "Some PDTM tools may have failed to install."
}

install_recon_tools() {
  print_info "Installing haktrails, anew, and gospider..."
  go install -v github.com/hakluke/haktrails@latest
  go install -v github.com/tomnomnom/anew@latest
  go install -v github.com/jaeles-project/gospider@latest
  print_success "Go-based recon tools installed."
}

install_puredns() {
  print_info "Installing Puredns (massdns)..."
  local tempdir
  tempdir=$(mktemp -d)
  pushd "$tempdir" >/dev/null

  git clone https://github.com/blechschmidt/massdns.git
  cd massdns
  make
  sudo make install
  sudo cp /bin/massdns /usr/local/bin || true

  popd >/dev/null
  rm -rf "$tempdir"

  print_success "Puredns (massdns) installed."
}

install_nmap() {
  print_info "Installing Nmap..."
  sudo apt-get install -y nmap
  print_success "Nmap installed."
}

setup_bug_bounty_dir() {
  print_info "Creating bug_bounty directory and downloading scan.sh..."

  # Determine the target user/home:
  # If script was run with sudo, SUDO_USER is set to the original user.
  if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  else
    TARGET_USER="$(whoami)"
    TARGET_HOME="$HOME"
  fi

  # Fallback if getent failed
  if [[ -z "$TARGET_HOME" ]]; then
    TARGET_HOME="$HOME"
  fi

  print_info "Using target home: $TARGET_HOME (user: $TARGET_USER)"

  mkdir -p "$TARGET_HOME/bug_bounty/scope" "$TARGET_HOME/bug_bounty/lists"

  pushd "$TARGET_HOME/bug_bounty" >/dev/null || {
    print_warn "Could not change to $TARGET_HOME/bug_bounty"
    return 1
  }

  local scan_url="https://raw.githubusercontent.com/thevillagehacker/tools/refs/heads/main/bug_bounty/scan.sh"
  local target="scan.sh"

  # Download robustly (-f: fail on HTTP error, -S: show error, -L: follow redirects, -O: write filename)
  if [[ -f "$target" ]]; then
    print_ok "scan.sh already present at $TARGET_HOME/bug_bounty/$target"
  else
    if curl -fSL -o "$target" "$scan_url"; then
      chmod +x "$target"
      print_ok "Downloaded and made executable: $target"
    else
      print_warn "Failed to download scan.sh from $scan_url"
    fi
  fi

  # Ensure ownership is the real user (useful if script executed with sudo)
  if command -v chown >/dev/null 2>&1; then
    sudo chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME/bug_bounty" 2>/dev/null || true
  fi

  popd >/dev/null
  print_success "Bug bounty directory and scan.sh ready at: $TARGET_HOME/bug_bounty"
}

print_final_message() {
  cat <<'USAGE'

==============================================================
Setup complete! 🚀
You can now use the bug bounty scan utility as shown below:

Usage: ./scan.sh <id>
This script performs a scan for a given <id>. Ensure the following structure:
├── scan.sh
├── scans
└── scope
    └── <id>
        └── roots.txt

Example:
chmod +x scan.sh
mkdir -p scope/example/
touch scope/example/roots.txt
./scan.sh example
==============================================================
USAGE
}

# ---[ Main Flow ]---

main() {
  [[ "${1:-}" =~ ^(-h|--help)$ ]] && show_help

  update_system
  install_packages
  configure_zshrc
  install_pdtm
  install_recon_tools
  install_puredns
  install_nmap
  setup_bug_bounty_dir
  print_final_message
}

main "$@"
