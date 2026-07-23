#!/usr/bin/env node
/* skill-drift-check — 真相源 skills/*.md ↔ repo plugin newworld-<X>/SKILL.md 陈旧即红
 * 来源思想: DietrichGebert/ponytail (单一规范源↔生成副本 byte-compare) + addyosmani skill-lint
 * 用法: node skill-drift-check.js   退出码 0=对齐, 1=漂移(CI 红灯)
 * 替代 CLAUDE.md 人肉约定「home 改必须同步 plugin」。 */
/* ★ 2026-07-22 BL-133 补第三跳：本闸门原本只守「真相源 ↔ plugin」（第二跳）。
 * 完整链路是三跳：
 *   真相源 skills/<name>.md  --sync-skills-to-plugin-->  plugin/<name>/SKILL.md
 *                            --install-user-skills.sh-->  skills/<name>/SKILL.md（加载副本，harness 真正读的）
 * 第三跳此前**零守卫**，于是「gate 全绿」与「实际加载的是旧铁律」可长期并存：
 * 2026-07-22 实测 7 份加载副本陈旧，其中 newworld-cf-cache-ops 缺整条铁律③
 * （4xx/5xx 禁被 CF 边缘缓存，2026-05-01 plyr.js 404 sticky 24h 事故），而
 * docs/CF_CACHE_RULES_2026_05.md 正是以「知识点已转入该 skill」为由删除的——
 * 知识转进了 plugin 副本，却从没装进加载副本。修法只是漏跑了四步流程的第 3 步。
 * 教训见 memory `feedback_gate_redgreen_and_failsafe_direction`（守卫失效是静默的）。 */
const fs = require('fs'), path = require('path');
const SRC = path.join(__dirname, '..', 'skills');                 // 真相源 (flat .md)

// 加载副本的排除清单从 install-user-skills.sh 单一来源解析，避免两处各写一份而漂移。
function loadedExcludes(repoRoot) {
  try {
    const sh = fs.readFileSync(path.join(repoRoot, 'scripts', 'install-user-skills.sh'), 'utf8');
    const m = sh.match(/^EXCLUDE="([^"]*)"/m);
    return new Set(m ? m[1].split(/\s+/).filter(Boolean) : []);
  } catch { return null; }   // 读不到 → 返回 null，第三跳整体跳过（fail-open，不误报）
}
// 分发副本 (dir/SKILL.md)：优先当前仓库(precommit 从 repo/worktree 根调用,写死主 checkout 会对
// worktree 提交产生假阳性——worktree 副本已同步但主 checkout 还是旧的,2026-07-05 实踩);兜底主 checkout。
const cwdPlugin = path.join(process.cwd(), 'claude-plugin', 'newworld', 'skills');
const PLUGIN = fs.existsSync(cwdPlugin) ? cwdPlugin : '/home/test/newworld/claude-plugin/newworld/skills';
const norm = s => s.replace(/\r\n/g, '\n').replace(/\s+$/g, '');   // 容忍行尾差异
let drift = [];
const srcSkills = fs.readdirSync(SRC).filter(f => f.endsWith('.md'));
for (const f of srcSkills) {
  const name = f.replace(/\.md$/, '');
  const p = path.join(PLUGIN, name, 'SKILL.md');
  if (!fs.existsSync(p)) { drift.push(`[plugin 缺] ${name}`); continue; }
  if (norm(fs.readFileSync(path.join(SRC, f), 'utf8')) !== norm(fs.readFileSync(p, 'utf8')))
    drift.push(`[内容不一致] ${name}`);
}
for (const d of fs.readdirSync(PLUGIN, { withFileTypes: true }).filter(e => e.isDirectory())) {
  if (!fs.existsSync(path.join(SRC, d.name + '.md'))) drift.push(`[真相源缺] ${d.name}`);
}

// ---- 第三跳：plugin 副本 → 加载副本 <name>/SKILL.md（harness 真正读的那份） ----
const repoRoot = fs.existsSync(cwdPlugin) ? process.cwd() : '/home/test/newworld';
const EXCLUDE = loadedExcludes(repoRoot);
let staleLoaded = [];
if (EXCLUDE) {
  for (const d of fs.readdirSync(PLUGIN, { withFileTypes: true }).filter(e => e.isDirectory())) {
    if (EXCLUDE.has(d.name)) continue;                       // 刻意不进加载集（BL-41）
    const loaded = path.join(SRC, d.name, 'SKILL.md');
    const dist = path.join(PLUGIN, d.name, 'SKILL.md');
    if (!fs.existsSync(dist)) continue;
    if (!fs.existsSync(loaded)) { staleLoaded.push(`[加载副本未装] ${d.name}`); continue; }
    if (norm(fs.readFileSync(dist, 'utf8')) !== norm(fs.readFileSync(loaded, 'utf8')))
      staleLoaded.push(`[加载副本陈旧] ${d.name}`);
  }
}

if (drift.length) { console.error('SKILL 漂移 (' + drift.length + '):\n' + drift.map(x => '  ' + x).join('\n')); process.exit(1); }
if (staleLoaded.length) {
  console.error('SKILL 加载副本未更新 (' + staleLoaded.length + '):\n' + staleLoaded.map(x => '  ' + x).join('\n'));
  console.error('→ 真相源与 plugin 已对齐，但 harness 实际加载的副本还是旧的（四步流程漏了第 3 步）。');
  console.error('→ 修法：bash scripts/install-user-skills.sh  然后 scripts/nw-memory-commit 落库（加载副本入仓库镜像）。');
  process.exit(1);
}
console.log('✓ skills 三跳对齐：真相源 == plugin 副本 == 加载副本 (' + srcSkills.length + ' 个真相源，'
  + (EXCLUDE ? srcSkills.length - EXCLUDE.size + ' 个进加载集' : '加载集未校验') + ')');
process.exit(0);
