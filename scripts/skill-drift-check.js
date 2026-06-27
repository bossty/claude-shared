#!/usr/bin/env node
/* skill-drift-check — 真相源 skills/*.md ↔ repo plugin newworld-<X>/SKILL.md 陈旧即红
 * 来源思想: DietrichGebert/ponytail (单一规范源↔生成副本 byte-compare) + addyosmani skill-lint
 * 用法: node skill-drift-check.js   退出码 0=对齐, 1=漂移(CI 红灯)
 * 替代 CLAUDE.md 人肉约定「home 改必须同步 plugin」。 */
const fs = require('fs'), path = require('path');
const SRC = path.join(__dirname, '..', 'skills');                 // 真相源 (flat .md)
const PLUGIN = '/home/test/newworld/claude-plugin/newworld/skills'; // 分发副本 (dir/SKILL.md)
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
if (drift.length) { console.error('SKILL 漂移 (' + drift.length + '):\n' + drift.map(x => '  ' + x).join('\n')); process.exit(1); }
console.log('✓ skills 真相源与 plugin 副本逐字对齐 (' + srcSkills.length + ' 个)'); process.exit(0);
