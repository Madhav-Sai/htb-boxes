#!/usr/bin/env python3

import ipaddress

ip = ipaddress.IPv4Address(input("IPv4 Address: ").strip())

print(".".join(f"{octet:04o}" for octet in ip.packed))
