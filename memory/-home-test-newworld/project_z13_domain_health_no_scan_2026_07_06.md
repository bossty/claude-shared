---
name: project_z13_domain_health_no_scan_2026_07_06
description: "domain-health 去SCAN(桶化索引集替代全库SCAN)——生产849/hr对12.45M键全库SCAN根治, flag灰度, 实现+审查完成 web1054/admin2160绿, 分支 fix/z13-domain-health-no-scan @97ba91b0 待错峰部署(勿峰窗)"
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
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
