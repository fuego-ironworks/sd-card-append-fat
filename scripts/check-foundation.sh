#!/bin/sh
set -eu

sh -n scripts/import-linux-fat.sh
sh -n scripts/verify-import-manifest.sh
sh scripts/verify-import-manifest.sh

test -f AGENTS.md
test -f fs/appendfat/README.md
test -f fs/appendfat/UPSTREAM.md

printf '%s\n' 'appendfat foundation checks passed'
