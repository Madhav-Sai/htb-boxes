#!/usr/bin/env python3

import socket

HOST = "paperwork.htb"
PORT = 1515
QUEUE = "archive_intake"

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


with socket.create_connection((HOST, PORT)) as s:
    print("[+] Connected")

    # Receive Print Job (command 2)
    s.sendall(b"\x02" + QUEUE.encode() + b"\n")

    if not recv_ack(s):
        exit()

    print("[+] Queue accepted")
    print("[*] The server is now waiting for the next LPD protocol messages.")
