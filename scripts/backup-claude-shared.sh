#!/usr/bin/env bash
# 为 ~/claude-shared（skill + memory 的唯一真相源）建立备份。
# 堵住的单点：一次误 rm / 坏改 / 磁盘丢失，就会带走全部 memory + skill。
#
# 三层，异地优先：
#   1. git 异地远端  — 抗整机/磁盘丢失（默认 remote=buyvm，SSH 到 buyvm-db，绕开 GitHub）
#   2. 本地裸镜像    — 抗误 rm / 工作副本损坏
#   3. 滚动 tar 快照 — 抗坏改（含未提交状态，人类可读，留最近 14 份）
#
# cron 每天 03:30 跑（crontab 已装）。手动：bash backup-claude-shared.sh
set -euo pipefail

SRC="$HOME/claude-shared"
REMOTE="${CLAUDE_SHARED_REMOTE:-buyvm}"   # 异地 git 远端名
MIRROR="$HOME/.claude-backups/claude-shared.git"
SNAPDIR="$HOME/.claude-backups/snapshots"
STAMP="$(date +%Y%m%d-%H%M%S)"
KEEP=14

[ -d "$SRC/.git" ] || { echo "[backup] $SRC 不是 git 仓库，中止" >&2; exit 1; }
mkdir -p "$SNAPDIR"
cd "$SRC"

# 0. 自动提交未落盘改动（备份用途，确保异地/镜像不漏未提交状态）
git add -A
git diff --cached --quiet || git commit -q -m "auto-backup $STAMP"

# 1. 推异地 git 远端（真磁盘丢失防护）
if git remote get-url "$REMOTE" >/dev/null 2>&1; then
  if git push -q "$REMOTE" --all && git push -q "$REMOTE" --tags 2>/dev/null; then
    echo "[backup] 已推异地远端 $REMOTE"
  else
    echo "[backup] ⚠ 推 $REMOTE 失败（网络/SSH？），本地层仍继续" >&2
  fi
else
  echo "[backup] ⚠ 未配异地远端 '$REMOTE'（git remote add $REMOTE <host>:path），仅本地层" >&2
fi

# 2. 本地裸镜像
if [ ! -d "$MIRROR" ]; then git clone --mirror "$SRC" "$MIRROR" >/dev/null
else git -C "$MIRROR" fetch --prune >/dev/null 2>&1; fi

# 3. 滚动 tar 快照，保留最近 $KEEP 份
tar czf "$SNAPDIR/claude-shared-$STAMP.tar.gz" -C "$HOME" claude-shared
ls -1t "$SNAPDIR"/claude-shared-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f

echo "[backup] $STAMP ✓ 异地+镜像+快照完成"
