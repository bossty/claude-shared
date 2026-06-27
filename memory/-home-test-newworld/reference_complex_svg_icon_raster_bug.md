---
name: reference_complex_svg_icon_raster_bug
description: "图标在DOM却不绘制(开DevTools才显)=复杂SVG path的Chrome/GPU栅格化bug,诊断比svgInner字节,修=换简单图标"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 187c446e-e104-4aa0-a529-a524a6ebe78b
---

**症状**：某个 SVG 图标"看不到"，但 outerHTML 显示它在 DOM 里、结构和正常图标完全一致（`<i class="el-icon"><svg fill="currentColor">`）；**打开 DevTools 就显出来、关掉又没了**；展开其它菜单/任何 reflow 也能逼出来。常见于侧栏菜单一个图标失效而其它正常。

**真根因**：该图标 SVG 的 path `d` 属性**过于复杂**（命中部分 Chrome 版本/GPU 驱动的复杂路径栅格化 bug）→ 元素在 DOM、计算样式全正常（尺寸/opacity/visibility/color/fill 都对），但**首帧不绘制**；DevTools 打开会强制重绘从而"修好"（误导性强）。

**诊断金标（用 chrome-devtools 连真实线上页对比，别在隔离 repro 里猜——隔离/CDP 环境往往画得出来掩盖问题）**：
- 取所有同类图标的 `svg.innerHTML.length` 或 `path.d.length` 逐项对比。出 bug 的那个是**断层离群值**。本案 admin 侧栏 Element Plus `Setting` 齿轮 path=1407 字符，其它图标全 ≤389 → 1407 是唯一变量。
- 凡 ≤ 已知能正常显示的最大值（本案 389）的图标都"证明安全"。

**无效修法**：`transform: translateZ(0)` 提 GPU 层**无效**——首帧栅格仍走同一个出 bug 的栅格器，提层不改栅格路径。

**有效修法**：**换一个简单图标**，从根上消除复杂 SVG 变量。本案 `Setting`(1407)→`Key`(169，钥匙=最高权限，语义贴 super-admin)，commit `29347199`。EP 图标真实复杂度速查（path d 长度）：Platform60/Management69/Key173/Operation275/DataLine389…Cpu854/**Setting1407**。

**交付验证铁律**：admin 经 CF tunnel，必确认 `curl -sD- https://adm.17.rip/` 的 index 是 `cache-control:no-cache`+`cf-cache-status:DYNAMIC`（边缘不缓存 HTML）→ 换 bundle hash 后用户刷新即拿新版；再 chrome-devtools 重新登录实测 svgInner 降下来才算闭环。adm.17.rip 走 /newworld/frontend-admin/dist，手动 build→tar→scp→sudo 原子 swap（无 version.js）。
