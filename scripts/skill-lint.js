#!/usr/bin/env node
/* skill-lint — newworld-* skill 的 frontmatter description 体检
 * 来源思想: obra/superpowers writing-skills (description 只写「何时触发」, 禁夹带 workflow/正文)
 *           + mattpocock writing-great-skills (leading-word / sprawl 诊断)
 * 用法: node skill-lint.js   退出码 0=全合规, 1=有告警
 * 规则: R1 必须有 frontmatter name+description; R2 description 单句触发(≤200字, 禁标题/列表/代码块=夹带正文);
 *       R3 name 与文件名(kebab)一致 */
const fs = require('fs'), path = require('path');
const SRC = path.join(__dirname, '..', 'skills');
const warns = [];
for (const f of fs.readdirSync(SRC).filter(x => x.endsWith('.md'))) {
  const fn = f.replace(/\.md$/, '');
  const txt = fs.readFileSync(path.join(SRC, f), 'utf8');
  const m = txt.match(/^---\n([\s\S]*?)\n---/);
  if (!m) { warns.push(`${fn}: R1 无 frontmatter`); continue; }
  const fm = m[1];
  const name = (fm.match(/^name:\s*(.+)$/m) || [])[1]?.trim();
  const desc = (fm.match(/^description:\s*(.+)$/m) || [])[1]?.trim();
  if (!name) warns.push(`${fn}: R1 缺 name`);
  else if (name !== fn) warns.push(`${fn}: R3 name(${name}) ≠ 文件名`);
  if (!desc) { warns.push(`${fn}: R1 缺 description`); continue; }
  // R2 newworld 模式: 「一句话能力 + Triggers on 关键词」, 长度本就长(关键词列表)→ 不按长度罚;
  //    只罚真正的「夹带正文」信号: markdown 标题/代码块。软提示 >600 字疑 sprawl。
  if (/(^|\s)#{1,6}\s/.test(desc) || /```/.test(desc)) warns.push(`${fn}: R2 description 含 markdown 标题/代码块(夹带正文)`);
  if (desc.length > 600) warns.push(`${fn}: R4(软) description ${desc.length} 字疑 sprawl, 考虑精简关键词`);
}
if (warns.length) { console.error(`skill-lint 告警 (${warns.length}):\n` + warns.map(x => '  ' + x).join('\n')); process.exit(1); }
console.log('✓ 所有 skill description 合规'); process.exit(0);
