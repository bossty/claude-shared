#!/usr/bin/env bash
# 把 shared.json 拉平进两账户 settings.json(各自 .bak)。红线:不碰 .credentials.json,只改 settings.json。
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
for acc in /home/test/.claude /home/test/.claude-work; do
  [ -f "$acc/settings.json" ] && python3 "$D/sync-settings.py" "$acc/settings.json"
done
