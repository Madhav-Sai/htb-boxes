#!/usr/bin/env bash
set -e

echo "[*] Removing apt package (if installed)..."
sudo apt purge -y certipy-ad || true
sudo apt autoremove -y

echo "[*] Removing user-installed Certipy packages..."
pip3 uninstall -y certipy-ad certipy || true

echo "[*] Removing Certipy from local user site-packages..."
rm -rf ~/.local/lib/python*/site-packages/certipy*
rm -rf ~/.local/lib/python*/site-packages/Certipy*
rm -f ~/.local/bin/certipy*
rm -f ~/.local/bin/certipy-ad

echo "[*] Removing Certipy virtual environments (if desired)..."
rm -rf ~/venvs/certipy*
rm -rf ~/.venvs/certipy*

echo "[*] Looking for remaining Certipy files..."
sudo find /usr/local -iname "*certipy*" 2>/dev/null || true
sudo find /usr/lib -iname "*certipy*" 2>/dev/null || true

echo
echo "[*] Checking what's left..."
which certipy-ad 2>/dev/null || echo "certipy-ad not found"
which certipy 2>/dev/null || echo "certipy not found"

python3 -m pip show certipy-ad 2>/dev/null || echo "pip package not found"

echo "[+] Cleanup complete"
