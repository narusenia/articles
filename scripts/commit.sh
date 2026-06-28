#!/usr/bin/env bash
set -euo pipefail

git add -A
git commit -m "update: $(date '+%Y%m%d %H:%M')"
