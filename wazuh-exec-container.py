#!/usr/bin/python3

import sys
import json
import subprocess


def main():
    first_line = sys.stdin.readline()

    try:
        active_response = json.loads(first_line)
    except:
        active_response = None

    args = ["bash"]
    if active_response:
        args = active_response.get("parameters", {}).get("extra_args", [])
        if len(args) == 0:
            print("no arguments provided", file=sys.stderr)
            exit(1)

    p = subprocess.Popen(
        args, stdin=subprocess.PIPE, stdout=sys.stdout, stderr=sys.stderr
    )
    if not p.stdin:
        exit(1)

    while first_line:
        p.stdin.write(first_line.encode())
        p.stdin.flush()

        code = p.poll()
        if code != None:
            exit(code)

        first_line = sys.stdin.readline()

    p.stdin.close()
    exit(p.wait())


if __name__ == "__main__":
    main()
