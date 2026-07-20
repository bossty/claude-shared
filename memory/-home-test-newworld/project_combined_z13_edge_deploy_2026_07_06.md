---
name: project-combined-z13-edge-deploy-2026-07-06
description: z13去SCAN + edge协议V6对齐 两批合并master(61ac7edb)待03:00错峰部署——合并部署runbook+flag灰度序
metadata: 
  node_type: memory
  type: project
  originSessionId: 0950865b-98af-4347-b7c3-2de7c081f6ac
---

2026-07-06 夜，Owner 令「接手 z13 分支 + 我的 edge-V6 一起处理」，我做 lead 统筹（合并测试派 sonnet subagent，生产 ops 我代跑=多agent auth-backstop 铁律）。

**已完成**：两批合 master `61ac7edb`（ff，ci-local 全绿）：
- edge-v6（渠道协议对齐 V6）：host_channel.lua/host-channel.js 降 V6 + 黄金测试真等价 + retry_token.lua 退役 + InternalSRedirectController.extractChannel 走 HostChannelParser。
- z13（domain-health 去 SCAN）：DomainErrorController 写 domain:err:idx:{epochSec/300} 索引集 + OpsController flag OPS_Z13_INDEX_ENABLED 灰度（默认 false=SCAN 逐字节不变）。
- 合并态全量：web 1052/0 + admin 2160/0 + 前端 1036 + Lua 30+38 + luac 全过（sonnet 跑，lead 二查 surefire 坐实非虚报）。分支 fix/edge-protocol-v6-alignment / fix/z13-domain-health-no-scan / fix/combined-z13-edge 均已删。

**✅ 三批已全部部署+验证（07-07 01:15-01:38 CST，Owner force-peak 授权）——master `8359c33f`（= z13+edge V6 + bot/§6 合并）**。六阶段全绿：①SQL z20 建表（app 用户无 CREATE→`ssh ca-mysql-master "sudo mysql newworld"` socket auth，binlog 同步 EU）②edge×3 V6（deploy-openresty.sh <node> edge，FORCE_PEAK=1；relay 归因 live 实证 usca-1/aws-s 302→relay.{P域}）③前端×6 deployed/frontend-web=8359c33f（★worktree 缺 node_modules 必先在 worktree/frontend-web `npm ci` 再 deploy-frontend.sh）④web×6 deployed/web=8359c33f（jar 真身 domain:err:idx+HostChannelParser 双 True）⑤admin swap（回滚基线 20260706-222130-afc7710a.jar；jar 真身 z13flag+BotTagTask+resolveQualityBaseline 三 True，pick-p 200@27ms 首call 000=冷启虚惊）⑥z13 flag 翻转 OPS_Z13_INDEX_ENABLED=true（★system_config 无 encrypted 列；30min Caffeine 缓存靠 pub-sub 失效——SQL 直改后须 `nw-redis ca-admin PUBLISH shared:ch:sysconfig-refresh OPS_Z13_INDEX_ENABLED` 即时生效）→ domain-health **10-30s→116ms（~100×）**+439 penalties 非空。★踩坑：SQL 反引号被 bash 命令替换→stdin 管道喂 mysql；deploy-web 用 `--force-peak` flag、edge/前端脚本用 `FORCE_PEAK=1` env。
**dark 待观察**：bot BotTagTask 每晚 03:30 首跑（03:40 查金标准域 spectrumdigest bot_ratio≈0.96/17.rip 干净）；§6+bot 全 dark 默认关，质量分/告警逐字节不变，攒几天验准再 Owner flip QUALITY_BASELINE_CLEAN_ENABLED。回滚：z13 flag 翻 false 秒回 SCAN。
（下方 7 步原始 runbook 保留作参考/回滚。）
1. **edge OpenResty ×3**（usca-1/usca-2/aws-s）：deploy-openresty.sh；lua 改必 restart 生效；先灰度一台跑 S 302 冒烟 OK 再其余。**edge 是 GFW 抗封逃生层，高敏，逐台验**。
2. **前端 web×6**：deploy-frontend.sh（host-channel.js V6）。
3. **web 后端×6**：deploy-web.sh 滚动（extractChannel V6 + DomainError 索引写）——**此步起 web 开始写索引**。
4. **ca-admin**：手动 jar swap（OpsController flag 代码，flag 默认 false=仍 SCAN 零行为改变）。**先记回滚基线 readlink current.jar**。
5. **等 ~10min** 索引跨 2 个 5min 桶填充。
6. **翻 flag**：nw-mysql INSERT ... OPS_Z13_INDEX_ENABLED=true ON DUP UPDATE（admin 无需重部署，请求读 config；缓存 ~30min TTL 可 bump SYSTEM_VERSION 或重启即时生效）。
7. **验证**：①domain-health 单次 <200ms（切前 10-30s）②penalties 抽样与切前一致 ③Redis SCAN 负载消失（Dragonfly slowlog + CA web /settings :00/:30 延迟不再尖峰）④pick-p 200 + Tomcat<50 busy ⑤relay 端到端：造 relay 测试渠道验落地带子域+归 relay 桶后删。
   ⚠️ **验 domain-health 禁连发**（[[feedback_domain_health_scan_hammering]]：切前仍 12.45M 键 SCAN，连发耗尽 Lettuce 致 pick-p 饥饿；单次带 -m 超时）。

**行为变化面**：①relay.{S域} 从错归 organic 改按渠道归因 ②NLB-direct 无渠道落裸 P 域（dormant）③domain-health flag 翻后走索引读 ④其余 302/统计逐字节同前。**回滚**：flag 翻 false（秒级回 SCAN）；edge=git 恢复两 lua+restart；前端/web/admin 秒级 jar 回滚。

**源真相源**：docs/sprint/2026-07-06-z13-domain-health-no-scan/（DESIGN/REVIEW/HANDOFF）+ docs/sprint/_archive/2026-07-05-edge-protocol-v6-alignment/PLAN.md。
