#!/usr/bin/env python3

import sys
import json
import subprocess
import os

HOST_PREFIX = os.getenv("WAZUH_AGENT_HOST_DIR", "")
YARA_HOME = os.getenv("WAZUH_YARA_HOME", "/usr/local/yara")
YARA_RULES = os.getenv("WAZUH_YARA_RULES", "rules/index.yar")


def main():
    input_str = ""
    for line in sys.stdin:
        input_str += line

    data = json.loads(input_str)
    filepath = data["parameters"]["alert"]["syscheck"]["path"]
    realpath = os.path.normpath(os.path.join(HOST_PREFIX, "." + filepath))
    p = subprocess.Popen(
        ["./bin/yara -w -r {rules} {path}".format(rules=YARA_RULES, path=realpath)],
        shell=True,
        cwd=YARA_HOME,
        stdout=subprocess.PIPE,
        text=True,
    )
    if p.stdout == None:
        print("ERROR: unexpected inexistence of stdout", sys.stderr)
        exit(1)

    msg = {"type": "yara-scan" ,"results": []}
    for line in p.stdout.readlines():
        code = p.poll()
        if code != None and code > 0:
            exit(code)

        line = line.rstrip().replace(realpath, filepath)
        msg["results"].append(line)
    
    if len(msg.get("results",[])) > 0:
        print(json.dumps(msg),file=sys.stderr)
    exit(p.wait())


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(e)
