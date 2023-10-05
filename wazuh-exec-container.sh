#!/bin/sh

exec /var/ossec/bin/socat - unix-connect:/var/ossec/container-exec.sock