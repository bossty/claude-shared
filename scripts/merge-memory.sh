#!/usr/bin/env bash
# P1 双账户 git 真相源统一 — S0..S4（非破坏:只复制不删,先全备份）
# 产物: ~/claude-shared (git) + MERGE-REPORT.md + skill-drift 报告
set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
A_ROOT=/home/test/.claude
B_ROOT=/home/test/.claude-work
A_SK=$A_ROOT/skills
A_MEM=$A_ROOT/projects/-home-test-newworld/memory
B_MEM=$B_ROOT/projects/-home-test-newworld/memory
PLUGIN_SK=/home/test/newworld/claude-plugin/newworld/skills

SHARED=/home/test/claude-shared
SH_SK=$SHARED/skills
SH_MEM=$SHARED/memory/-home-test-newworld
BK=/home/test/.claude-backups/toolchain-$TS

echo "########## S0 备份(账户外) ##########"
mkdir -p "$BK"
cp -a "$A_SK"  "$BK/A-skills"
cp -a "$A_MEM" "$BK/A-memory"
cp -a "$B_MEM" "$BK/B-memory"
echo "备份完成 -> $BK"
echo "  A-skills: $(ls "$BK/A-skills"/*.md 2>/dev/null|wc -l) | A-memory: $(ls "$BK/A-memory"|wc -l) | B-memory: $(ls "$BK/B-memory"|wc -l)"

echo "########## S1 git init claude-shared ##########"
mkdir -p "$SH_SK" "$SH_MEM" "$SHARED/scripts" "$SHARED/settings"
cd "$SHARED"
[ -d .git ] || git init -q
printf '%s\n' '*.pre-symlink/' '.backup/' 'node_modules/' > .gitignore
echo "claude-shared 骨架就绪: $SHARED"

echo "########## S2 skills 基线 = A 的 34 个 flat .md ##########"
cp -a "$A_SK"/*.md "$SH_SK"/ 2>/dev/null || true
# learned/ 等非 newworld 子目录不进真相源(账户私有学习缓存)
echo "shared/skills .md 数: $(ls "$SH_SK"/*.md 2>/dev/null|wc -l)"

echo "########## S2b skill 漂移报告(A flat .md ↔ plugin dir/SKILL.md) ##########"
DRIFT="$SHARED/SKILL-DRIFT-REPORT.md"
{
  echo "# SKILL 漂移报告 — A 账户 ~/.claude/skills (flat .md) ↔ repo plugin (dir/SKILL.md)"
  echo "> 生成: $TS  | P2 byte-compare 红线的首轮基线"
  echo
  echo "## 仅在 A(裸目录)、plugin 缺"
  for f in "$SH_SK"/*.md; do n=$(basename "$f" .md); [ -f "$PLUGIN_SK/$n/SKILL.md" ] || echo "- $n"; done
  echo
  echo "## 仅在 plugin、A 缺"
  for d in "$PLUGIN_SK"/*/; do n=$(basename "$d"); [ -f "$SH_SK/$n.md" ] || echo "- $n"; done
  echo
  echo "## 两边都有但内容不一致(byte-diff)"
  for f in "$SH_SK"/*.md; do n=$(basename "$f" .md); p="$PLUGIN_SK/$n/SKILL.md"; [ -f "$p" ] || continue; diff -q "$f" "$p" >/dev/null 2>&1 || echo "- $n  (A:$(wc -c <"$f")B vs plugin:$(wc -c <"$p")B)"; done
} > "$DRIFT"
echo "漂移报告 -> $DRIFT"; echo "--- 摘要 ---"; cat "$DRIFT"

echo "########## S3 memory 并集合并(非破坏) ##########"
# 3.1 全量复制 A(91) 与 B(143);B 不覆盖 A 已有的 2 个共有冲突文件
cp -a "$A_MEM"/. "$SH_MEM"/
for f in "$B_MEM"/*; do
  bn=$(basename "$f")
  [ -e "$SH_MEM/$bn" ] || cp -a "$f" "$SH_MEM/$bn"
done

REPORT="$SH_MEM/MERGE-REPORT.md"
A_ONLY=$(comm -23 <(ls "$A_MEM"|sort) <(ls "$B_MEM"|sort))
B_ONLY=$(comm -13 <(ls "$A_MEM"|sort) <(ls "$B_MEM"|sort))
COMMON=$(comm -12 <(ls "$A_MEM"|sort) <(ls "$B_MEM"|sort))

# 3.2 共有冲突消解
CONFLICTS=""
for bn in $COMMON; do
  if ! diff -q "$A_MEM/$bn" "$B_MEM/$bn" >/dev/null 2>&1; then
    CONFLICTS="$CONFLICTS $bn"
  fi
done

# 3.3 MEMORY.md 特殊 union(按 (filename) 去重, A 全量 + B 独有条目)
if [ -f "$A_MEM/MEMORY.md" ] && [ -f "$B_MEM/MEMORY.md" ]; then
  TMPM=$(mktemp)
  cp "$A_MEM/MEMORY.md" "$TMPM"
  # A 已引用的文件名集合
  grep -oP '\(([^)]+\.md)\)' "$A_MEM/MEMORY.md" 2>/dev/null | tr -d '()' | sort -u > /tmp/_a_refs.txt || true
  echo "" >> "$TMPM"
  echo "<!-- ↓↓↓ 以下条目从 .claude-work(B) MEMORY.md 并入(B 独有) ↓↓↓ -->" >> "$TMPM"
  # B 的 bullet 行里, 引用文件不在 A_refs 的, 追加
  while IFS= read -r line; do
    fn=$(echo "$line" | grep -oP '\(([^)]+\.md)\)' | tr -d '()' | head -1)
    [ -z "$fn" ] && continue
    grep -qxF "$fn" /tmp/_a_refs.txt || echo "$line" >> "$TMPM"
  done < <(grep '^- ' "$B_MEM/MEMORY.md" 2>/dev/null || true)
  cp "$TMPM" "$SH_MEM/MEMORY.md"
  rm -f "$TMPM"
fi

# 3.4 project_fullcut 类冲突: 取字节更大者, 另一份留 .OTHER 供 Owner
for bn in $CONFLICTS; do
  [ "$bn" = "MEMORY.md" ] && continue
  aS=$(wc -c <"$A_MEM/$bn"); bS=$(wc -c <"$B_MEM/$bn")
  if [ "$bS" -gt "$aS" ]; then cp -a "$B_MEM/$bn" "$SH_MEM/$bn"; cp -a "$A_MEM/$bn" "$SH_MEM/${bn%.md}.A-OTHER.md"; pick="B($bS B)"; else pick="A($aS B)"; cp -a "$B_MEM/$bn" "$SH_MEM/${bn%.md}.B-OTHER.md"; fi
  echo "冲突取舍 $bn: 选 $pick, 另一份存 .OTHER"
done

# 3.5 orphan 检测: shared 里的 .md 未被 MEMORY.md 引用
grep -oP '\(([^)]+\.md)\)' "$SH_MEM/MEMORY.md" 2>/dev/null | tr -d '()' | sort -u > /tmp/_m_refs.txt || true
ORPHANS=""
for f in "$SH_MEM"/*.md; do
  bn=$(basename "$f")
  [ "$bn" = "MEMORY.md" ] && continue
  echo "$bn" | grep -qE '\.(A|B)-OTHER\.md$' && continue
  grep -qxF "$bn" /tmp/_m_refs.txt || ORPHANS="$ORPHANS $bn"
done

# 3.6 写 MERGE-REPORT
{
  echo "# MEMORY 并集合并报告 (toolchain-realignment, $TS)"
  echo "> 非破坏合并: A($(ls "$A_MEM"|wc -l)) ∪ B($(ls "$B_MEM"|wc -l)) -> shared($(ls "$SH_MEM"/*.md 2>/dev/null|wc -l) .md)"
  echo "> 全备份: $BK"
  echo
  echo "## 计数核对"
  echo "- A 独有: $(echo "$A_ONLY"|grep -c . ) | B 独有: $(echo "$B_ONLY"|grep -c .) | 共有: $(echo "$COMMON"|grep -c .)"
  echo "- 合并后 shared memory 目录 .md 总数(含 MEMORY.md/.OTHER): $(ls "$SH_MEM"/*.md 2>/dev/null|wc -l)"
  echo
  echo "## 共有文件冲突消解(需 Owner 复核)"
  if [ -z "${CONFLICTS// }" ]; then echo "- (无)"; else
    for bn in $CONFLICTS; do
      if [ "$bn" = "MEMORY.md" ]; then echo "- **MEMORY.md**: 按 (filename) 去重 union(A 全量 + B 独有条目);索引顺序可能需人工微调";
      else echo "- **$bn**: 取字节更大者为主, 另一账户版本留为 \`${bn%.md}.{A,B}-OTHER.md\` 供你 diff 取舍"; fi
    done
  fi
  echo
  echo "## Orphan(在目录但 MEMORY.md 未索引, 需补索引或确认)"
  if [ -z "${ORPHANS// }" ]; then echo "- (无)"; else for o in $ORPHANS; do echo "- $o"; done; fi
  echo
  echo "## .OTHER 备份文件(冲突另一方, 复核后可删)"
  ls "$SH_MEM"/*OTHER.md 2>/dev/null | sed 's#.*/#- #' || echo "- (无)"
} > "$REPORT"

echo "MERGE-REPORT -> $REPORT"
echo "=================== MERGE-REPORT 摘要 ==================="
cat "$REPORT"
echo "======================================================="
echo
echo "########## 计数最终核对 ##########"
echo "shared/skills .md : $(ls "$SH_SK"/*.md 2>/dev/null|wc -l)  (期望 34)"
echo "shared/memory .md : $(ls "$SH_MEM"/*.md 2>/dev/null|wc -l)  (期望 ~232 含 MEMORY.md+.OTHER)"
echo "并集理论值(去重)  : $(( $(echo "$A_ONLY"|grep -c .) + $(echo "$B_ONLY"|grep -c .) + $(echo "$COMMON"|grep -c .) )) (不含 .OTHER)"
echo
echo ">>> 已完成 S0-S3。S5 symlink 未执行(等 Owner 复核 MERGE-REPORT 后再切)。"
