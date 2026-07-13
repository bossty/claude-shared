---
name: project_supjav_prod_enable_2026_07_12
description: supjav 从临时隧道测试态转正式生产常驻——永久边车/autossh/段限流分档/每小时定时全上线(BL-51,merge 10839b4cf)
metadata:
  type: project
---

# supjav 正式生产启用（BL-51，2026-07-12 完工，merge `10839b4cf`）

封面/预览修复 sprint（`573a3c43f`）之后的独立任务：把 supjav 从临时隧道测试态转生产常驻。**已上线，生产金标 PASS。**

## 生产实装位置（排错必查）
- **边车**：buyvm-data（干净 IP 过 CF Turnstile，ca-admin IP 被 CF managed 识破）`/opt/supjav-fetcher/`（app.py + venv），两个 systemd 单元 `supjav-fetcher-xvfb.service`(Xvfb :99) + `supjav-fetcher.service`(Requires xvfb)，均 enabled+Restart=on-failure，绑 127.0.0.1:8770。SSH 用户 `test`（NOPASSWD sudo）。旧 POC `/tmp/supjav-poc` 已停留作 fallback。
- **连通**：ca-admin `autossh-supjav-fetcher.service`（systemd，User=ubuntu）正向 `-L 127.0.0.1:8770→buyvm-data:8770`，专用 key `~/.ssh/supjav_tunnel_ed25519`，buyvm-data authorized_keys 限 `permitopen="127.0.0.1:8770"`。断线 autossh 15s 自动重连。
- **flag**：`/etc/newworld/data.env` 的 `APP_CRAWLER_SUPJAV_ENABLED=true` + `SUPJAV_FETCHER_URL=http://127.0.0.1:8770`（正式分层，非临时 drop-in）。关 supjav = 改此 flag=false + restart data。
- **定时**：`SupjavScheduledCrawlTask` 每小时整点（HKT）FreshnessTrickle 增量，双门控 `@ConditionalOnExpression(scheduling.enabled + crawler.supjav.enabled)`，hardCap=5 + 熔断。

## 关键设计
- **段限流按段 host 分档**（非按业务源）：supjav 段真实 CDN=Google Drive（`lh3.googleusercontent.com`）单 IP 累积配额、靠后段 429。`HlsDownloadService.isThrottledHost` 命中 `hls-throttle-hosts=googleusercontent` → 用 `hls-throttle-concurrent=4`+`hls-throttle-delay-ms=300`，其他源各走自家 CDN 不受影响。金标 688 段 0×429 证有效。见 [[reference_source_ip_ban_dual_whitelist_flaresolverr]] 家族。
- **番号前缀 `supjav-` OK**（Owner 拍板）；118233 保留（Owner 要留的旧金标片）；新片 118238 是本次验证真出片（留作生产内容）。

## 坑（本会话踩）
- **仓库 requirements.txt 不完整**：`scrapling==0.4.10` 不把 playwright/patchright 当依赖拉取，fresh venv 缺驱动、`playwright install` 报 "No module named playwright"。修法=全量 pin POC 验证过的 32 包冻结集（浏览器缓存 `~/.cache/ms-playwright` 2.7G 跨 venv 共享、勿删）。
- **ContactSheet 无慢 seek**：4 核 ca-admin 上 118238 封面 16/16 6s 完成（remux keyframe seek 修复 `573a3c43f` 已合，本次未再碰）。
- R2 孤儿清理未做（118220/226/227 段 hash 随删行丢失、按 id 找不到）→ [[reference_autossh_sidecar_tunnel_pkill_gotcha]] 无关，转 BL-54 完整 reconciliation。

## 后续独立项
BL-52（vcsi/ffmpegthumbnailer 替换手搓 ContactSheet，需引入 Python/原生依赖，倾向保持现状）、BL-53（定时采集配置驱动化，须保留双门控语义）、BL-54（R2 孤儿 reconciliation）。
