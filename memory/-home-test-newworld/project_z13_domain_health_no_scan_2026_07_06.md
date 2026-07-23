---
name: project_z13_domain_health_no_scan_2026_07_06
description: "domain-health 去SCAN(桶化索引集替代全库SCAN)——生产849/hr对12.45M键全库SCAN根治, flag灰度, 实现+审查完成 web1054/admin2160绿, 分支 fix/z13-domain-health-no-scan @97ba91b0 待错峰部署(勿峰窗)"
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
  modified: 2026-07-22T11:49:19.705Z
---

domain-health 端点去全库 SCAN 修复，**实现+lead审查完成，未合master、未部署（Owner 定「实现现做部署等错峰」）**。subagent-driven（dev-senior 实现 + lead 亲审）。

**问题**（本次 pickp 拆分部署后验证时暴露→详见 [[feedback_domain_health_scan_hammering]]）：admin `/api/v1/internal/ops/domain-health`（生产 **849 次/小时** edge 拉取）对每 active 域 `SCAN MATCH domain:err:{d}:*:5min`。SCAN 成本 O(总键空间=12.45M 键)，非 O(匹配)——设计注释误设 ~12,400 键。故每次遍历全 12.45M 键 × 每域，慢+占 Lettuce 连接，是**独立高优生产 Redis 负载**（config-tuning 11078abc 只治 ChannelSaturationTask 定时任务，未覆盖此端点）。我连发 smoke 触发连接池耗尽事故（22:31，restart 恢复）。

**修法**（同 config-tuning 11078abc 去SCAN 范式：写端维护索引集，读端 SMEMBERS 替代 SCAN）：
- **写端 web DomainErrorController**：err 上报同处**追加** `coalescingBuffer.addMember("domain:err:idx:"+epochSec/300, "{d}:{isp}:{prov}", MemberType.SET, 660)`——既有 blue-team 硬化的幂等并集 SADD 路径，零额外跨洋，不改 err/pv 写。**无条件写**（先部署生成端铁律）。
- **读端 admin OpsController.domainHealth**：flag `OPS_Z13_INDEX_ENABLED`（system_config 默认 false）。false→**SCAN 路径逐字节不变**；true→appendPenaltiesFromIndex 读 cur∪cur-1 桶 SMEMBERS→parseIndexMember→z13PenaltyService.readHashCount/computeZ13Entry→Layer A/B，**无 SCAN**。
- 桶算法两端 epochSec/300 严格一致；索引前缀 `domain:err:idx:` 字面一致。

**审查（lead 亲验）**：flag=false 的 appendPenaltiesForDomain 逐字节一致；桶/前缀两端一致；索引路径无 scan+cur/cur-1 覆盖 10min 窗+Layer B 分组(domain,isp)等价 SCAN；parseIndexMember 正确；2 个 dev-senior 标记开放项(成员上限全局/陈旧成员)均非问题(computeZ13Entry err_count<=0 过滤等价)；测试真断言(flag两态 verify scan/never-scan + web addMember)；fresh mvn web 1054/admin 2160 绿。全文 `docs/sprint/2026-07-06-z13-domain-health-no-scan/REVIEW.md`。

**分支**：`fix/z13-domain-health-no-scan` @ `97ba91b0`（基于 afc7710a）。

**部署（错峰，安全切换序）**：1) web×6+admin 一起部署(flag 默认 false 零行为改变) 2) 等~10min 索引填充 3) system_config 翻 OPS_Z13_INDEX_ENABLED=true(admin 无需重部署) 4) 验证 domain-health<200ms+penalties 抽样一致+SCAN 负载消失 5) 回滚=flag 翻 false。web peak 20:00-03:00 需 --force-peak，或搭 07-07 06:00 config-tuning 批 D 窗。

**★翻 flag 后必手动 pub-sub 失效，否则最长 30min 不生效**：system_config 走 30min Caffeine 缓存，SQL 直改（INSERT ... ON DUPLICATE KEY UPDATE）**不会**自动失效——须跟一条 `nw-redis ca-admin PUBLISH shared:ch:sysconfig-refresh OPS_Z13_INDEX_ENABLED` 即时生效（替代「bump SYSTEM_VERSION 或重启 admin」的粗办法）。另：system_config 无 encrypted 列，值明文写；SQL 里的反引号会被 bash 命令替换吃掉，直改一律用 stdin 管道喂 mysql 而非 `-e "..."`。

**★峰窗强制参数四个脚本两种写法（不通用，抄错=被 guard 拒）**（2026-07-22 grep 实核仍成立）：`deploy-web.sh` / `deploy-backend.sh` 自己解析 **`--force-peak` flag**（deploy-web.sh:77、deploy-backend.sh:62，命中 20:00–03:00 HKT 无 flag 则 die）；`deploy-openresty.sh` / `deploy-frontend.sh` 走 `source scripts/lib/peak-guard.sh`（:53 / :28），只认 **`FORCE_PEAK=1` env 前缀**，给它们传 `--force-peak` 会当未知参数或直接被 guard 拦。
