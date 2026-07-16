#!/usr/bin/env bash

set -e

echo "[+] Installing useful packages..."

sudo apt update

sudo apt install -y \
btop \
ncdu \
tmux \
jq \
yq \
httpie \
direnv \
pipx \
fzf \
ripgrep \
fd-find \
tree \
whois \
dnsutils \
nmap \
wl-clipboard

echo "[+] Installing TheFuck..."
pipx install thefuck || true

echo "[+] Installing Atuin..."
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

echo "[+] Installing fzf-tab..."

git clone https://github.com/Aloxaf/fzf-tab \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab || true

echo "[+] Installing you-should-use..."

git clone https://github.com/MichaelAquilina/zsh-you-should-use \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/you-should-use || true

echo "[+] Installing tmux plugin manager..."

git clone https://github.com/tmux-plugins/tpm \
~/.tmux/plugins/tpm || true

echo "[+] Creating tmux config..."

cat > ~/.tmux.conf << 'EOF'
set -g mouse on
set -g history-limit 100000

bind r source-file ~/.tmux.conf

set -g status-position top

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

run '~/.tmux/plugins/tpm/tpm'
EOF

echo "[+] Updating .zshrc..."

cat >> ~/.zshrc << 'EOF'

# ---- Pentester Addons ----

plugins+=(
  fzf-tab
  you-should-use
)

eval "$(atuin init zsh)"
eval $(thefuck --alias)

alias ports='ss -tulpen'
alias myip='curl ifconfig.me'
alias ips='ip -br a'

alias grep='grep --color=auto'

alias c='clear'

alias htb='cd ~/htb-boxes'

alias update='sudo apt update && sudo apt full-upgrade -y'

alias extract='a() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz) tar xzf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.rar) unrar x "$1" ;;
      *.gz) gunzip "$1" ;;
      *.tar) tar xf "$1" ;;
      *.tbz2) tar xjf "$1" ;;
      *.tgz) tar xzf "$1" ;;
      *.zip) unzip "$1" ;;
      *.7z) 7z x "$1" ;;
      *) echo "Cannot extract" ;;
    esac
  fi
}; a'

EOF

echo
echo "==================================="
echo "DONE"
echo "==================================="
echo
echo "Run:"
echo "  source ~/.zshrc"
echo "  atuin import auto"
echo
