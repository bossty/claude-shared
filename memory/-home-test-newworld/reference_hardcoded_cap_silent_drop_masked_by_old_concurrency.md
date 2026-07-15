---
name: reference_hardcoded_cap_silent_drop_masked_by_old_concurrency
description: 硬编码单次上限(cap) < 每页条数 = 每页静默丢片且不计入任何 stats；旧并发模式可能意外互补掩盖它，改架构反而让它第一次真咬人
metadata:
  type: reference
---

BL-70（2026-07-15）蓝军逮出的 BLOCKER，纯读代码看不出，**改架构才暴露**。

## 事实

`AbstractXvideosChannelCrawler:137` `@Value("${xvasiam.hard-cap-per-run:20}")` = **单次运行最多 20 部**（全仓无覆盖）。
xvideos best 榜**每页 27 条**。`crawlItems` 里 `if (successCount >= cap) break;` —— **break 后剩余 7 条不计入
`movieCount` / `movieSkipped` / `movieFailed` 任何一个** → 丢了也看不出来，stats 全绿。

深页全是新片时：37 页 × 2 月 × 3 分片 ≈ **静默丢 1500 部**。

## 最诛心的一点：旧模式意外掩盖了它

旧的「三机跑同一页范围、靠 Redis 抢占锁自然分工」模式下，A 机抢到锁采 20 部（撞 cap），
**B 机抢不到锁、但它自己那一遍会把剩下的 7 部捡起来** —— 冗余重复扫描意外形成了互补，cap 从未咬人。

我把它改成**按页硬分片**（每页只有一台碰）以后，这个互补被拆掉 → **潜伏的 cap 第一次真咬人**。

> **铁律：改并发/分片架构时，必须枚举「旧的冗余/重复扫描掩盖了哪些潜伏 bug」**。
> "旧模式跑得好好的" ≠ 旧模式没 bug，可能只是它的浪费恰好补偿了 bug。

## 判据与修法

- **判据**：任何「每批/每页/每轮上限」常量，都要和**真实输入规模**对账（cap=20 vs 每页 27 条）。
  尤其看 break 之后**剩余项有没有被计入统计** —— 不计入 = 静默丢失 = 最坏的一类 bug。
- **修法**：加 `capOverride` 参数（controller 传 `cap=30`），旧签名委托 null 保既有行为零变。
  **批量任务的每台启动命令都必须显式带 cap，漏一台该台静默回落默认值。**

同族：[[reference_crawler_dryrun_id_collision_mock_llm]]（隔离库 AUTO_INCREMENT 撞键也是静默类）。
