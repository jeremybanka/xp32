#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
case "${1:-keytest}" in
    keytest) exec sh apps/keytest/build.sh ;;
    *) echo "Unknown app: $1 (available: keytest)" >&2; exit 1 ;;
esac
