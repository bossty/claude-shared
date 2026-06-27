---
name: feedback-vue-scoped-vs-global-css
description: "Vue scoped CSS 不自动覆盖同选择器的 global CSS（如 frontend-admin/src/assets/styles/variables.css 的 `.search-bar`/`.pool-overview` 等通用类）；scoped 改 flex-direction 但漏改 align-items 会让 global 默认值漏穿，子元素水平居中等 bug 是 5/24 域名管理页\"区域居中\"真凶"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 19490b43-0f03-44c7-8f23-e2928c8b5c06
---

frontend-admin 项目存在 GLOBAL 非 scoped 的常用类 CSS（`assets/styles/variables.css`）：`.search-bar`、`.pool-overview` 等定义了 `display: flex; align-items: center; gap: ...`。

**Why**：5/24 域名管理页改 `.search-bar` 加 `flex-direction: column` 后 owner 报"筛选/批量同步/域名数量 区域居中状态、与 NameSilo 余额没左对齐"——前两轮 grep CSS 自查未发现真凶，chrome-devtools `getBoundingClientRect` 实测 row1=163 / row2=127 / row3=154（balance-label x=20）才看清水平居中。根因 `variables.css:87` global `.search-bar { align-items: center }`，scoped `.search-bar` 没显式覆盖 align-items；列方向下 center 是水平居中 → 三个 row 都被推到行的中点。

**How to apply**：
1. 任何 scoped 改 `.search-bar / .pool-overview / .toolbar-row` 等通用类的 `flex-direction`，**必须同步显式设 `align-items`**（即便和 global 默认相同也写），靠 cascade 默认会踩坑。
2. CSS 布局类排查必先 `grep -rn "\.<类名>" src/ --include="*.vue" --include="*.css"` 全仓库扫同名规则（包括 `assets/styles/`），不仅看当前 .vue 文件的 scoped CSS。
3. 视觉对齐疑问走 chrome-devtools-mcp `evaluate_script` 注入 mock DOM + 测 `getBoundingClientRect()` 实证 x/w，禁凭脑算 padding/margin 推断（5/24 三次"应该对齐"被实测打脸）。
4. 蓝军/qa 验收前端视觉 fix 走 `newworld-frontend-visual-fix` skill 4 象限 + 这条规则补强。

相关：[[newworld-frontend-visual-fix]]、[[feedback-qa-safari-chrome-dual-engine]]。
