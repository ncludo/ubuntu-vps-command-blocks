#!/usr/bin/env python3
"""Display filter with optional bounded, undecorated clipboard capture."""

import os
import sys

PREFIX = b"\x1b[95m\xe2\x94\x82\x1b[0m "


def write_all(data):
    view = memoryview(data)
    while view:
        view = view[os.write(1, view):]


def main():
    border = (len(sys.argv) < 2 or sys.argv[1] == "1")
    path = sys.argv[2] if len(sys.argv) > 2 else ""
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 1048576
    captured = 0
    capture = None
    if path:
        capture = open(path, "wb", buffering=0)
    at_start = True
    after_cr = False
    try:
        while True:
            block = os.read(0, 65536)
            if not block:
                break
            if capture is not None:
                if captured + len(block) > limit:
                    capture.close()
                    capture = None
                    os.unlink(path)
                else:
                    try:
                        capture.write(block)
                        captured += len(block)
                    except OSError:
                        capture.close()
                        capture = None
                        os.unlink(path)
            if not border:
                write_all(block)
                continue
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
        if border and (not at_start or after_cr):
            write_all(b"\n")
    finally:
        if capture is not None:
            capture.close()


if __name__ == "__main__":
    main()
