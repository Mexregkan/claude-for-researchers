#!/usr/bin/env python3
"""Dump a notebook (Wolfbook .wb, or an .ipynb / .nb-derived JSON) to readable
text so its pipeline can be documented. Also handles plain source files
(.m/.wls/.py/…): it just prints them.

Usage:
    python3 dump_code.py <outdir> <file> [<file> ...]

For each notebook it writes  <base>.outline.txt  (one line per cell:
index / kind / first line)  and  <base>.full.txt  (every cell in full). For a
plain source file it writes <base>.full.txt.
Cell 'kind': 1 = markdown, 2 = code.  In a .wb cell the source is under 'value'
and the language under 'languageId'.
"""
import json, sys, os
bar = "=" * 90

def dump_nb(path, outdir):
    cells = json.load(open(path))["cells"]
    base = os.path.splitext(os.path.basename(path))[0]
    base = base.replace(" ", "_").replace("(", "").replace(")", "")
    with open(os.path.join(outdir, base + ".full.txt"), "w") as full, \
         open(os.path.join(outdir, base + ".outline.txt"), "w") as outl:
        for i, x in enumerate(cells):
            kind = "MD" if x.get("kind") == 1 else "CODE"
            # .wb uses 'value'; .ipynb uses 'source' (str or list of lines)
            v = x.get("value")
            if v is None:
                src = x.get("source", "")
                v = "".join(src) if isinstance(src, list) else src
            first = v.strip().split("\n")[0][:110] if v.strip() else "(empty)"
            outl.write("[%03d] %-4s | %s\n" % (i, kind, first))
            full.write("\n%s\n[CELL %03d] %s\n%s\n%s\n" % (bar, i, kind, bar, v))
    print("%s: %d cells -> %s.outline.txt / .full.txt" % (path, len(cells), base))

def dump_plain(path, outdir):
    base = os.path.splitext(os.path.basename(path))[0].replace(" ", "_")
    txt = open(path, errors="replace").read()
    with open(os.path.join(outdir, base + ".full.txt"), "w") as f:
        f.write(txt)
    print("%s: %d bytes -> %s.full.txt" % (path, len(txt), base))

if __name__ == "__main__":
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    for p in sys.argv[2:]:
        try:
            if p.endswith(".wb") or p.endswith(".ipynb"):
                dump_nb(p, outdir)
            else:
                dump_plain(p, outdir)
        except Exception as e:
            print("FAILED %s: %s" % (p, e))
