---
name: project_sw_force_update_rca_2026_06_03
description: "老用户不清缓存看不到新广告的根因=前端更新机制\"应用\"步骤被动;治本=SW client.navigate强制更新;+6条方法论教训"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5af436db-ae9f-44c6-bf7a-db0bc88f7f41
---

# 老用户看不到新广告 RCA + 前端更新机制治本 (2026-06-03)

## 症状
snack(广告)脱敏 cutover + 05:00 改广告部署后：**无痕/新用户正常出广告，老用户不清缓存永久零广告**。owner 从头反复质疑同一点：**前端代码更新机制为什么没保证老用户立即拿新代码？若机制 100% 正确则不需要任何兼容。**——这个质疑是对的，是真根因，我前期一直在打补丁（grace/empty-bypass/qStore自愈/adVersion）治标。

## 真根因（前端更新机制"应用"步骤被动）
版本"检测"健全（sw.js/version.txt no-cache + SW 每次导航比对 BUILD_HASH + `_m8` postMessage），但**"应用"（真 reload 跑新代码）被设计成被动**：
- `controllerchange`(sw-bridge) 明确**不 reload**（"避免破坏当前操作"）
- `_m8`→`__newVersionAvailable` flag **只被 router.beforeEach(SPA跳转)消费**，整页刷新/挂机不触发
→ 即使新 SW 接管，页面继续跑**旧 JS**。老用户永不自动换新代码。
**鸡生蛋**：controllerchange-reload(commit f48c88db, 页面侧)在新 JS 里，旧用户旧 JS 没有它 → 救不了存量。

## 治本（commit 90e6dca1）= SW 驱动强制更新
**关键洞察**：浏览器**自己**更新 sw.js（no-cache + `updateViaCache:'none'`），**与页面 JS 多旧无关**。所以让 **SW 本体** activate 时 `client.navigate(c.url)` 强制所有客户端 reload → 拿新 index→新 JS→新接口→广告。SW 驱动、独立旧页面 JS、对任何老客户端生效，零兼容。
- 守卫：install 记 `self.registration.active` 判升级（**首访不强刷=无闪**）；持久化标志到 CACHE_NAME 防 SW 中途被杀；`client.navigate` 不支持静默降级。
- 双引擎(WebKit+Chromium)严测：升级强刷换新✓ **空闲20s零自发导航不循环✓**(灾难闸) 首访不闪✓。
- 唯一边界：SW 更新需用户**至少一次导航**触发（物理无解，完全关闭设备推不动）。grace/adVersion 兼容降级为过渡安全网，待此 SW 铺到~全量(SW版本面板监控)退役。

## 6 条方法论教训（贯穿这次反复失败）
1. **部署产物≠源码**：源码对/commit在master/HEAD对 ≠ 部署的 minified bundle 是最新。empty-bypass 部署的是半成品旧版（缺 `i.empty||` 支）。必 grep **实际 artifact 独有签名**（混淆后字符串/属性名被编码,功能测试才是金标）。
2. **SW 类前端 bug 必 `serviceWorkers:'allow'` 持久 context 复现**：默认 playwright context 无 SW=假阳性温床。我多次"修好了又没好"全因无 SW 测试。
3. **清数据=ads 是金标二分**：复现不了 owner 设备状态时，让 owner 清站点数据→有广告 ⟹ 最新代码没 bug、问题是交付/旧状态；→ 没广告 ⟹ 最新代码 bug。一刀定位。
4. **owner 反复质疑同一点 → 先正面回答"为什么"，别继续打补丁**：owner 逻辑("有新代码为何读旧配置")直接戳破我的症状治标。
5. **主会话仲裁砍死代码红鲱鱼**：团队 crossfire 整轮盯 `getPinnedSnacks`（全 src 零调用方=死代码）；真路径 qStore.fetchZ02→getSnacksBySlot('z02')。sub-agent 报"根因"必查真实调用方。
6. **字段重命名断老客户端版本机制**：snack-rename 把 checkVersion 读的 `data.adVersion`→`snackVersion`(前后端同步)，老 JS 读 `adVersion`=undefined→av=0→refresh 永不触发。后端 ConfigController 补回 `adVersion`=snack-version 值向后兼容(commit 4d333dac)。

## ⚠️ 副带发现（待修）
SW 版本分布面板 `stats:sw-versions:{date}` 实测**空**——X-SW-Version 上报可能坏了；要监控老用户收敛需先修它。详见 [[reference_sw_version_tracking]]。

## 部署链路坑
deploy-web.sh(web 后端 orchestrator)**从本地机跑**(本地 ssh aws-data build+scp 双web)，在 aws-data 上跑会 `ssh aws-data` 自连 127.0.0.1 Permission denied；**不接 MODULE 参数**(硬编码 web,传 `web` 报未知参数 exit2)；`--restart-only` 需配 `--jar=<path>`；中途失败会留 aws-web-01 cloudflared drain 没恢复→必查恢复 tunnel。
