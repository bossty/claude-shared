---
name: project-california-region-build-2026-06-09
description: 加州 us-west-1 region 搭建 sprint——池解耦/两个真坑(@Value relaxed binding、gate G3 测量假红)
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-09→10 加州 region (us-west-1) 搭建 sprint（scope 仅 A 域，零流量到 ready，放量/终态 owner 拍板）。终态拓扑见 [[project_arch_lock_california_2026_06_08]]。

**节点（线上实证，全 us-west-1a）**：web-01 172.34.1.37 / web-02 **172.34.1.173**(i-0b5056c5755eae7bb，两次重建后终值) / web-03 172.34.1.246（m5.xlarge×3）；db-replica 172.34.1.239（r6i.xlarge）；redis-replica 172.34.1.128（r6i.large）。读写分离经 **systemd Environment** 注入（非 /etc/newworld/*.conf）：写→DB_HOST=HK master，读→SPRING_DATASOURCE_SLAVE_URL=本地 replica。

**G5 选项B = master 写池/slave 读池解耦**（commit ecdb78dd）：region 写 4% 走跨洋 master、读 96% 走本地 replica → master 写池可缩(20)降 master 连接占用、slave 读池须保持(80)。加州×3 写池 20 → gate 连接池求和 3×20+us/eu2×80=220<240。

**★真坑1：@Value 不支持 relaxed binding（差点上生产雪崩）**。第一版用 `@Value("${spring.datasource.slave.maximum-pool-size:-1}")` 读 slave 池，但 @Value 不做 relaxed binding——systemd env `SPRING_DATASOURCE_SLAVE_HIKARI_MAXIMUM_POOL_SIZE`(下划线) 匹配不上 dash 形 placeholder（`SystemEnvironmentPropertySource` 把 `.`→`_` 但 **`-` 不转**）→静默返默认→slave 读池回退 master 小池=20→96% 读打满 503 雪崩。**修=改 @ConfigurationProperties(支持 relaxed binding)**。蓝军 Round 10 拦下。**教训：外部化配置注入用 @ConfigurationProperties，别用 @Value 读 dash 形 kebab 属性；且写 Binder+SystemEnvironmentPropertySource 实证测试(非 ReflectionTestUtils 旁路)。**

**★真坑2：gate G3 既会假绿也会假红**。①假绿：探针 `?q=` 但 controller 要 `keyword=`→400 快失败(5ms)不走读路径→跨洋节点也假绿(漏测571ms类)。修=seed 用 `keyword=`。②假红：`remote_uht_ms` 按**路径** grep(`${url%%?*}` 砍 query)，seed 灌流并发打同路径→`tail -1` 抓到别人的行→gate p50=263ms 但直测 6ms。修=grep 全 `$url`(含随机 query token)只匹配自己。**教训：合成探针必须用真参数名打真路径；从共享日志按"自己的唯一标识"匹配，别按路径(会被并发污染)。验证以直接运行时压测为准(60连发 p95=8ms 推翻 gate 假红)。**

**gate 第三缺陷（未修，backlog）**：per-sample 每样本一次 SSH(×50/端点)→全 gate ~78min 龟速。改批量(1 SSH 跑完50采样)需 review，暂留 backlog。

**部署铁律复用**：dist 缺失致 G4 白屏(加州当初漏 scp 前端，已补 328 files/283 js+css 字节对齐基线)；jar 用固定路径无版本化 symlink(违 newworld-deploy-jar-symlink，backlog)；前端/dist 手敲必 sudo+set -e+validate-before-switch。

**owner 边界**：放量/切 CF steering/动 prod master(抬 max_conn 500→700 等)=owner-gated。本 sprint 全程零流量、不碰 us/eu。配套 [[feedback_long_task_no_stall_sop]]、[[feedback_verify_not_recall]]。
