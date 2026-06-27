---
name: PSI 审计进度
description: 2026-04-02 首轮 PSI 审计完成，探针检测临时禁用需恢复，待完成项见 docs/PSI_AUDIT_STATUS.md
type: project
---

首轮 PSI 审计完成（2026-04-02），详见 `docs/PSI_AUDIT_STATUS.md`。

**Why:** 用户要求对标 pagespeed.web.dev 优化所有页面性能。

**How to apply:**
- 新会话续做时读取 `docs/PSI_AUDIT_STATUS.md` 获取进度
- ⚠️ 探针检测已临时禁用（`main.js` 搜索 `TODO_RESTORE_PROBE`），PSI 测试全部完成后必须恢复
- AVIF 图片转码是下一个高价值项（预计省 50-70% 图片体积）
- CLS 进一步优化需替换 owl-carousel
