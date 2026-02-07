#!/usr/bin/env bash
# ===============================================
#  Automated Setup Script for Recon & Bounty Tools
#  - idempotent (verifies before installing)
#  - compartmentalized functions
#  - safe edits to ~/.zshrc
# ===============================================
#  Author: Naveen Jagadeesan(thevillagehacker)
#  Description: Sets up Zsh, Go, PDTM, GRC, and 
#               installs key recon tools.
# ===============================================
# =========[ Print Helpers ]=========
# --- Print helpers (must appear BEFORE any function that calls them) ---
print_info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
print_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
print_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Small guard: if the script is partially sourced or run in a weird shell
# make sure these functions exist (idempotent).
for fn in print_info print_warn print_success print_error; do
  declare -f "$fn" >/dev/null 2>&1 || eval "$fn() { echo \"[${fn^^}] \$*\"; }"
done

# --- Exit handling ---
_on_exit() {
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    # Only print final message on successful completion
    # If final_message() exists, call it; otherwise, show a brief success line.
    if declare -f final_message >/dev/null 2>&1; then
      final_message
    else
      print_success "Setup completed successfully!"
    fi
  else
    print_error "Setup failed (exit code $rc). Check earlier messages above for details."
  fi
}
trap _on_exit EXIT

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


# Globals
TMPDIR="$(mktemp -d)"
ORIG_PWD="$(pwd)"

# Detect original user when running with sudo
ORIGINAL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo ~$ORIGINAL_USER)"
ZSHRC="$USER_HOME/.zshrc"

# Determine GOPATH: query existing Go installation or use default in user's home
if command -v go >/dev/null 2>&1; then
  # Run as original user to get their GOPATH
  GOPATH_DEFAULT="$(sudo -u "$ORIGINAL_USER" go env GOPATH 2>/dev/null || echo "")"
  [[ -z "$GOPATH_DEFAULT" ]] && GOPATH_DEFAULT="$USER_HOME/go"
else
  GOPATH_DEFAULT="$USER_HOME/go"
fi

cleanup() {
  [[ -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
}
trap cleanup EXIT

# --- Helper functions ---
print_info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
print_ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
print_err()   { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }

show_help() {
  cat <<'EOF'
Usage: setup.sh [ -h | --help ]

This script installs/configures:
 - zsh, golang, grc, nmap, massdns (puredns build)
 - pdtm + pdtm tools
 - haktrails, anew, gospider
 - bug_bounty directory + scan.sh

It performs verification before installing to avoid conflicts.
EOF
  exit 0
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

apt_pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

ensure_apt_package() {
  local pkg="$1"
  if apt_pkg_installed "$pkg"; then
    print_ok "apt package '$pkg' already installed."
  else
    print_info "Installing apt package: $pkg"
    sudo apt-get install -y "$pkg"
    print_ok "Installed $pkg"
  fi
}

append_if_missing() {
  # args: file, unique-marker-or-pattern, content (heredoc-friendly with \n)
  local file="$1"; local pattern="$2"; local content="$3"
  if ! grep -q -F "$pattern" "$file" 2>/dev/null; then
    printf "%s\n" "$content" >> "$file"
    print_ok "Appended to $file: $pattern"
  else
    print_ok "Entry already present in $file: $pattern"
  fi
}

# --- Steps ---

update_system() {
  print_info "Running apt-get update..."
  sudo apt-get update -y
  print_ok "apt updated."
}

install_core_packages() {
  print_info "Ensuring core packages are installed (zsh, golang, grc, make, git, curl)..."
  ensure_apt_package zsh
  ensure_apt_package golang
  ensure_apt_package grc
  ensure_apt_package make
  ensure_apt_package git
  ensure_apt_package curl
  print_ok "Core packages ensured."
}

configure_gopath_and_zshrc() {
  local gopath_line="export GOPATH=${GOPATH_DEFAULT}"
  local path_line='export PATH=$PATH:$GOPATH/bin'
  local aliases_marker="# === added by setup.sh aliases ==="
  local aliases_content=$'alias ll=\'ls -lshaF --color=auto\'\nalias la=\'ls -A\'\nalias l=\'ls -CF\'\nalias cls=\'clear\'\n# Show full timestamped history\nalias h=\'fc -lt "%F %T"\''
  local grc_marker='[[ -s "/etc/grc.zsh" ]] && source /etc/grc.zsh'

  # Ensure ~/.zshrc exists
  touch "$ZSHRC"

  append_if_missing "$ZSHRC" "$gopath_line" "$gopath_line"
  append_if_missing "$ZSHRC" "$path_line" "$path_line"

  # Add aliases block with a marker to avoid duplication
  if ! grep -qF "$aliases_marker" "$ZSHRC"; then
    {
      printf "\n%s\n" "$aliases_marker"
      printf "%s\n" "$aliases_content"
      printf "%s\n" "# === end setup.sh aliases ==="
    } >> "$ZSHRC"
    print_ok "Aliases (including 'h') added to $ZSHRC"
  else
    print_ok "Aliases block already present in $ZSHRC"
  fi

  append_if_missing "$ZSHRC" "$grc_marker" "$grc_marker"

  print_ok ".zshrc configured (GOPATH, PATH, aliases, grc)."
}

install_go_bin() {
  # args: import_path[,binary_name]
  local import_path="$1"
  local binary_name="${2:-$(basename "$import_path")}"
  local bin_path="$GOPATH_DEFAULT/bin/$binary_name"

  # Verify binary exists in GOPATH/bin and is actually executable
  if [[ -x "$bin_path" ]]; then
    print_ok "Go binary '$binary_name' already available."
    return 0
  fi

  print_info "Installing Go binary: $import_path"
  # Ensure GOPATH dir exists
  mkdir -p "$GOPATH_DEFAULT/bin"
  # Use `go install` (requires go >=1.16). If go not installed, apt package provided earlier
  if cmd_exists go; then
    # try install
    if go install "${import_path}" >/dev/null 2>&1; then
      print_ok "Installed: $import_path"
      return 0
    else
      print_warn "go install failed for $import_path — trying with GOPATH env..."
      GOPATH="$GOPATH_DEFAULT" GO111MODULE=on go install "${import_path}" || {
        print_err "Failed to install $import_path"
      }
    fi
  else
    print_err "Go is not available; cannot go install $import_path"
  fi
}

install_pdtm_and_tools() {
  # pdtm binary is 'pdtm'
  if cmd_exists pdtm || [[ -x "$GOPATH_DEFAULT/bin/pdtm" ]]; then
    print_ok "pdtm already installed."
  else
    install_go_bin github.com/projectdiscovery/pdtm/cmd/pdtm@latest pdtm
  fi

  # ensure pdtm in PATH inside .zshrc (we already added GOPATH and PATH)
  append_if_missing "$ZSHRC" "export PATH=\$PATH:\$GOPATH/bin" 'export PATH=$PATH:$GOPATH/bin'

  # Run pdtm -ia to install pdtm tools (only if pdtm exists)
  if cmd_exists pdtm || [[ -x "$GOPATH_DEFAULT/bin/pdtm" ]]; then
    print_info "Running 'pdtm -ia' to install PDTM tools (may take some time)..."
    # Use a subshell to prevent script aborting on non-zero (pdtm may exit non-zero while still partially installed)
    if "$GOPATH_DEFAULT/bin/pdtm" -ia; then
      print_ok "PDTM tools installed."
    else
      print_warn "pdtm -ia returned non-zero exit. Some tools may not have been installed."
    fi
  else
    print_warn "pdtm not found; skipping 'pdtm -ia'."
  fi
}

install_recon_tools() {
  # haktrails (binary: haktrails), anew (binary: anew), gospider (binary: gospider)
  install_go_bin github.com/hakluke/haktrails@latest haktrails
  install_go_bin github.com/tomnomnom/anew@latest anew
  install_go_bin github.com/jaeles-project/gospider@latest gospider
}

install_massdns() {
  # massdns binary path: /usr/local/bin/massdns or in PATH as 'massdns'
  if cmd_exists massdns || [[ -x "/usr/local/bin/massdns" ]] || [[ -x "/bin/massdns" ]]; then
    print_ok "massdns already installed."
    return 0
  fi

  print_info "Building massdns (puredns) from source..."
  pushd "$TMPDIR" >/dev/null
  git clone --depth 1 https://github.com/blechschmidt/massdns.git || {
    print_err "Failed to clone massdns repository."
  }
  cd massdns
  make || print_err "make failed for massdns."
  sudo make install || print_warn "sudo make install failed; trying manual copy."
  # try copying produced binary if exists
  if [[ -f "bin/massdns" ]]; then
    sudo cp -f bin/massdns /usr/local/bin/
    print_ok "massdns installed to /usr/local/bin"
  elif [[ -f "/bin/massdns" || -f "/usr/local/bin/massdns" ]]; then
    print_ok "massdns appears installed system-wide"
  else
    print_warn "massdns binary not found after build"
  fi
  popd >/dev/null
}

install_nmap() {
  ensure_apt_package nmap
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


final_message() {
  cat <<'USAGE'

==============================================================
Setup complete! 🚀

Usage: ./scan.sh <id>
This script performs a scan for a given <id>. Ensure the following structure is in place:

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

# --- Main ---
main() {
  [[ "${1:-}" =~ ^(-h|--help)$ ]] && show_help

  print_info "Starting setup (working dir: $ORIG_PWD). Temporary work in: $TMPDIR"

  update_system
  install_core_packages
  configure_gopath_and_zshrc
  install_pdtm_and_tools
  install_recon_tools
  install_massdns
  install_nmap
  setup_bug_bounty_dir

  # Return to original pwd to avoid surprising the user
  cd "$ORIG_PWD" || true

  final_message
}

main "$@"
