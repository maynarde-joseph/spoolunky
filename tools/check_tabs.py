#!/usr/bin/env python3
"""Fails if any GDScript file indents with spaces.

Godot rejects a file that indents with spaces where it indented with tabs
before, and it rejects it as a *parse* error — which means a class that does it
cannot be resolved, and everything referring to that class reports the failure
at its own line instead. One mixed function took out a whole suite and pointed
at the test that named the class.

gdparse does not check this, so nothing local caught it. This does, it runs in
under a second, and it is the whole reason it exists.

Lines inside a triple-quoted string are left alone: text that lines up inside a
help message is not indentation.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIP = ("addons",)

def offenders(path):
    bad = []
    in_block = False
    for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
        quotes = line.count('"""')
        if in_block:
            if quotes:
                in_block = False
            continue
        if quotes % 2:
            in_block = True
            continue
        if re.match(r"^ ", line):
            bad.append((number, line))
    return bad

def main():
    found = 0
    for path in sorted(ROOT.rglob("*.gd")):
        if any(part in SKIP for part in path.parts):
            continue
        for number, line in offenders(path):
            found += 1
            print("%s:%d indents with spaces: %s"
                  % (path.relative_to(ROOT), number, line[:60].rstrip()))
    if found:
        print("\n%d line(s) indent with spaces. Godot wants tabs." % found)
        return 1
    print("indentation is tabs throughout")
    return 0

if __name__ == "__main__":
    sys.exit(main())
