---
name: owl-carousel 不可轻易替换
description: owl-carousel + jQuery 是首页轮播核心依赖，替换为 CSS scroll-snap 导致滑动失效被回滚
type: feedback
---

owl-carousel + jQuery 替换为 CSS scroll-snap + vanilla JS 导致首页轮播触摸/鼠标滑动功能丧失，被用户要求回滚。

**Why:** owl-carousel 提供的功能不只是水平滚动——还有 loop、center、responsive item count、drag momentum、touch velocity 等复杂交互，CSS scroll-snap 无法完全替代。

**How to apply:** 
- 不要尝试移除 jQuery + owl-carousel，除非有充分的本地端到端测试（触摸滑动、鼠标拖拽、响应式断点切换）
- 如果要优化这部分，考虑用 Swiper（无 jQuery 依赖，功能等价）逐步替换，而不是用 CSS scroll-snap
- 任何涉及轮播交互的改动必须在真实设备/浏览器上验证
