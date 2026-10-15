#!/usr/bin/env python3
"""Experimental CB display formatter. No clipboard capture."""

import os

PREFIX = b"\x1b[95m\xe2\x94\x82\x1b[0m "


def write_all(data):
    view = memoryview(data)
    while view:
        view = view[os.write(1, view):]


def main():
    at_start = True
    after_cr = False
    while True:
        block = os.read(0, 65536)
        if not block:
            break
        out = bytearray()
        for b in block:
            if b == 10:
                if at_start and not after_cr:
                    out.extend(PREFIX)
                out.append(10)
                at_start = True
                after_cr = False
            elif b == 13:
                out.append(13)
                at_start = True
                after_cr = True
            else:
                if at_start:
                    out.extend(PREFIX)
                out.append(b)
                at_start = False
                after_cr = False
        write_all(out)
    if not at_start or after_cr:
        write_all(b"\n")


if __name__ == "__main__":
    main()
