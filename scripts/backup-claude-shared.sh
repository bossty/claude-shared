#!/usr/bin/env bash
# 为 ~/claude-shared（skill + memory 的唯一真相源，本地 git 无远端）建立多层备份。
# 堵住的单点：一次误 rm / 坏改 / 工作树损坏 / 磁盘丢失，就会带走全部 256+ memory + 35 skill。
#
# 三层防护（成本近零，claude-shared 仅 ~5M）：
#   1. 本地裸镜像  — 抗误 rm / 工作副本损坏（保留已提交历史）
#   2. 滚动 tar 快照 — 抗坏改（含未提交状态，人类可读可还原，留最近 14 份）
#   3. 可选 S3 异地 — 抗磁盘丢失（设 CLAUDE_SHARED_BACKUP_S3 即启用；aws cli 已装）
#
# 装 cron：见文件尾注释。手动跑：bash backup-claude-shared.sh
set -euo pipefail

SRC="$HOME/claude-shared"
MIRROR="$HOME/.claude-backups/claude-shared.git"
SNAPDIR="$HOME/.claude-backups/snapshots"
STAMP="$(date +%Y%m%d-%H%M%S)"
KEEP=14

[ -d "$SRC/.git" ] || { echo "[backup] $SRC 不是 git 仓库，中止" >&2; exit 1; }
mkdir -p "$SNAPDIR"

# 1. 本地裸镜像（committed 历史）
if [ ! -d "$MIRROR" ]; then
  git clone --mirror "$SRC" "$MIRROR" >/dev/null
  echo "[backup] 初始化裸镜像 $MIRROR"
else
  git -C "$MIRROR" fetch --prune >/dev/null 2>&1
fi

# 2. 滚动 tar 快照（含未提交工作树），保留最近 $KEEP 份
tar czf "$SNAPDIR/claude-shared-$STAMP.tar.gz" -C "$HOME" claude-shared
ls -1t "$SNAPDIR"/claude-shared-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f

# 3. 可选异地（真磁盘丢失防护）：export CLAUDE_SHARED_BACKUP_S3=s3://your-bucket/claude-shared
if [ -n "${CLAUDE_SHARED_BACKUP_S3:-}" ]; then
  aws s3 cp "$SNAPDIR/claude-shared-$STAMP.tar.gz" "${CLAUDE_SHARED_BACKUP_S3%/}/" \
    ${AWS_PROFILE:+--profile "$AWS_PROFILE"} >/dev/null
  echo "[backup] 已推 S3 ${CLAUDE_SHARED_BACKUP_S3}"
fi

echo "[backup] $STAMP ✓ 镜像+快照完成（$(ls -1 "$SNAPDIR"/claude-shared-*.tar.gz | wc -l) 份快照在 $SNAPDIR）"

# ── 装 cron（每天 03:30）──────────────────────────────────────────────
#   (crontab -l 2>/dev/null; echo '30 3 * * * /home/test/claude-shared/scripts/backup-claude-shared.sh >> /home/test/.claude-backups/backup.log 2>&1') | crontab -
# ── 真异地（二选一，均一次性）──────────────────────────────────────────
#   A) GitHub 私有仓库：在 ~/claude-shared 里
#        git remote add origin git@github.com:<you>/claude-shared-private.git && git push -u origin --all
#      然后本脚本的镜像 fetch 会自然随工作仓；或直接 cron `git -C ~/claude-shared push origin --all`
#   B) S3/R2：export CLAUDE_SHARED_BACKUP_S3=s3://<bucket>/claude-shared （aws cli 已装）
