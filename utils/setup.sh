#!/usr/bin/env bash
set -e
GO_INSTALL_DIR="/usr/local"
GO_PROFILE_SNIPPET='
# >>> Go setup >>>
export GOPATH="$HOME/go"
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"
# <<< Go setup <
'
VIMRC_SNIPPET='
" >>> Vim setup >>>
syntax on
set number
set cursorline
highlight CursorLine cterm=NONE ctermbg=0 ctermfg=NONE guibg=#000000 guifg=NONE
" <<< Vim setup <
'
detect_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *) echo "unsupported"; exit 1 ;;
    esac
}
setup_vimrc() {
    VIMRC="$HOME/.vimrc"
    [ -f "$VIMRC" ] || touch "$VIMRC"
    if ! grep -q "Vim setup" "$VIMRC"; then
        echo "$VIMRC_SNIPPET" >> "$VIMRC"
        echo "[+] Updated $VIMRC"
    else
        echo "[=] Vim config already exists in $VIMRC"
    fi
}
install_go() {
    if command -v go >/dev/null 2>&1; then
        echo "[=] Go already installed: $(go version)"
        return
    fi
    echo "[+] Installing latest Go..."
    ARCH=$(detect_arch)
    GO_TARBALL=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
    DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}.linux-${ARCH}.tar.gz"
    echo "[+] Downloading $DOWNLOAD_URL"
    curl -LO "$DOWNLOAD_URL"
    echo "[+] Removing old Go (if any)"
    sudo rm -rf ${GO_INSTALL_DIR}/go
    echo "[+] Extracting Go..."
    sudo tar -C ${GO_INSTALL_DIR} -xzf "${GO_TARBALL}.linux-${ARCH}.tar.gz"
    rm -f "${GO_TARBALL}.linux-${ARCH}.tar.gz"
    echo "[+] Configuring environment..."
    for shellrc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$shellrc" ] || touch "$shellrc"
        if ! grep -q "Go setup" "$shellrc"; then
            echo "$GO_PROFILE_SNIPPET" >> "$shellrc"
            echo "[+] Updated $shellrc"
        else
            echo "[=] Go config already exists in $shellrc"
        fi
    done
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    echo "[+] Go installed successfully: $(go version)"
}
install_pdtm() {
    if command -v pdtm >/dev/null 2>&1; then
        echo "[=] PDTM already installed"
        return
    fi
    echo "[+] Installing PDTM..."
    go install github.com/projectdiscovery/pdtm/cmd/pdtm@latest
    export PATH=$PATH:$HOME/go/bin
    echo "[+] Verifying PDTM..."
    if command -v pdtm >/dev/null 2>&1; then
        echo "[+] PDTM installed successfully"
    else
        echo "[-] PDTM installation failed"
        exit 1
    fi
}
post_install() {
    echo "[+] Installing core ProjectDiscovery tools (optional but recommended)..."
    pdtm -install-all || true
}
main() {
    setup_vimrc
    install_go
    install_pdtm
    post_install
    echo ""
    echo "[✓] Setup complete"
    echo "Reload your shell:"
    echo "  source ~/.bashrc  OR  source ~/.zshrc"
}
main