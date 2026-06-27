---
name: project_rum_cardinality_fix_2026_06_14
description: 2026-06-14 eu-web-01 监控gap真因=actuator高基数RUM-by-POP撑爆categraf;SLO bucket降基数~800×根治
metadata: 
  node_type: memory
  type: project
  originSessionId: df06f417-fb3f-4c81-8486-085852426538
---

**2026-06-14 RUM by-POP 指标降基数 sprint**（owner 问"eu-web-01 dashboards/5 部分指标没数据"起）。

**真因链**（多层，逐层戳穿）：
1. owner 报"eu-web-01 部分指标没数据" → instant query 假象显示新鲜（VM 默认回看5min，4min前停的指标仍显示）。**判活必用 `count_over_time(m[3m])` 窗口计数，别信 instant query**。
2. count[3m]=0 而 instant 0.7s → categraf 间歇卡顿（停几分钟→恢复猛 flush）。冒烟枪 = eu-web-01 categraf RSS **3.3GB**（对照 eu-web-02 仅 402M）。
3. RSS 构成 RssAnon 2.9G（真累积非 mmap）；categraf `input.prometheus` scrape `http://127.0.0.1:18080/actuator/prometheus` = **9.3MB/79,594 行**，90% 是 `nw_vitals_*_by_pop/by_r2pop_bucket`（owner 直觉的"业务数据"=Web Vitals 按 CF POP 切片）。
4. **基数放大器不是 POP 本身，是 `publishPercentileHistogram()` 给每个 cfPop×cfCountry×rum_host 组合铺 276 bucket**（MonitorService.recordTaggedVital）。55组合×276≈15,180/指标/节点，VM `count(series)` 10s 超时。

**根治**（commit `378d16c6`，方案2 owner拍板）：
- `recordTaggedVital`: `publishPercentileHistogram()`(276) → `serviceLevelObjectives(Google官方阈值)`：LCP{2500,4000}/FCP{1800,3000}/TTFB{800,1800}。
- 砍 `cfCountry` 标签（POP 已含地理，非"走到哪个边缘节点"判断依据）；raw Redis HSET 仍存 cfCountry 供 admin 原始看板。清死码 sanitizeCountry+KNOWN_COUNTRIES。
- **聚合系列(无标签 nw_vitals_lcp_ms 等)保留满 276-bucket → 全局精度不变**（精度放全局、切片放 SLO）。
- 实测：actuator 79,594→~1,550 行(~50×)；by_pop 活跃基数 ~36k→27-48/节点(~800×)；categraf 3.3G→161M。

**配套**：5 web 节点 categraf drop-in `MemoryMax=1.5G`（健康~700M 之上、runaway 之下）+ Restart=on-failure 5s 自愈（有界 gap 替无界卡死）。即时止血,与代码修复解耦。

**部署关键坑**：
- `deploy-web.sh` 是**旧拓扑死脚本**（BUILD_HOST=aws-data退役/目标aws-web-01/02退役/仅2节点），不认终态B 5节点。手动滚动：build本地→scp→drain(停cloudflared断隧道=可靠排空,非健康检查)→换`/opt/newworld/newworld-web.jar`(新OS节点扁平路径,非deploys/symlink)→重启→:18080 health UP→恢复cloudflared。
- web boot ~37s,readiness loop 别太短;ctx_execute 会把长 ssh 命令提前终止→命令压短,drain/swap/restart 与 readiness/恢复分开两条命令。
- 换 jar 时旧 JVM shutdown 报 LettuceConnectionFactory$1 NoClassDefFoundError = 无害 shutdown 噪音(classloader 找不到换走的 jar 内部类)。
- board 22 改 N9E DB board_payload(JSON):8→6 panel(删cfCountry),P95-by-POP→good-rate `rate(_bucket{le="good阈值"})/rate(_bucket{le="+Inf"})`。**mysql -N 回读会把 `\"`转义成`\\"`致 JSON 假损坏,验存储用 `mysql --raw -N`**。N9E le 标签规范化(2500.0→2500)。

关联 [[feedback_cgroup_oom_diagnosis]]（同夜 data OOM,先dmesg实证）、[[feedback_verify_metric_source]]、[[newworld-multiregion-crossocean-hotpath]]（跨洋写放大）。
