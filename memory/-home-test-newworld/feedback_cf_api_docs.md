---
name: CF API 必须先查文档
description: Cloudflare API 调用前必须查阅官方文档，不得凭记忆判断功能是否支持
type: feedback
---

凭记忆说"Free 计划不支持 Prefix Purge"，实际 2025-04 起已对所有计划开放。

**Why:** CLAUDE.md 第 9 行明确规定，浪费了时间走弯路还给了错误方案。

**How to apply:** 任何 CF API 调用前，先 WebSearch 查 developers.cloudflare.com 最新文档确认端点和参数，再写代码。绝不凭记忆。
