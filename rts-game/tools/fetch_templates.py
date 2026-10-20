#!/usr/bin/env python3
"""Downloads only the requested Godot export templates out of the official ~1 GB .tpz archive
using HTTP range requests (the archive is a zip, so we read its directory and fetch single entries).
Usage: python3 tools/fetch_templates.py <dest dir> windows_release_x86_64.exe linux_release.x86_64 ..."""
import os, struct, sys, urllib.request, zlib

VERSION = "4.3-stable"
URL = "https://github.com/godotengine/godot/releases/download/%s/Godot_v%s_export_templates.tpz" % (VERSION, VERSION)

def rng(a, b):
    req = urllib.request.Request(URL, headers={"Range": "bytes=%d-%d" % (a, b)})
    return urllib.request.urlopen(req).read()

def main():
    dest = sys.argv[1]
    os.makedirs(dest, exist_ok=True)
    head = urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"))
    size = int(head.headers["Content-Length"])
    tail = rng(size - 70000, size - 1)
    i = tail.rfind(b"PK\x05\x06")
    cd_size, cd_off = struct.unpack("<II", tail[i + 12:i + 20])
    cd = rng(cd_off, cd_off + cd_size - 1)
    p, ents = 0, {}
    while p < len(cd):
        f = struct.unpack("<IHHHHHHIIIHHHHHII", cd[p:p + 46])
        meth, csz, nl, el, cl, off = f[4], f[8], f[10], f[11], f[12], f[16]
        ents[cd[p + 46:p + 46 + nl].decode().split("/")[-1]] = (meth, csz, off)
        p += 46 + nl + el + cl
    for name in sys.argv[2:] + ["version.txt"]:
        meth, csz, off = ents[name]
        h = rng(off, off + 29)
        nl, el = struct.unpack("<HH", h[26:30])
        data = rng(off + 30 + nl + el, off + 30 + nl + el + csz - 1)
        if meth == 8:
            data = zlib.decompress(data, -15)
        open(os.path.join(dest, name), "wb").write(data)
        print("template", name, len(data))

if __name__ == "__main__":
    main()
