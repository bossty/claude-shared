---
name: reference_buyvm_worker_scheduling_gate_sharding
description: BuyVM 多机分片爬虫必须走 HTTP 触发非 @Scheduled——app.scheduling.enabled=false 关的是整个 @EnableScheduling 基础设施，worker 里所有 @Scheduled 全哑
metadata:
  type: reference
---

**BuyVM 离线 worker 跑某爬虫做多机分片时，别用 `@Scheduled` 做定时/分片。**

死结（2026-07-13 madou BL-59 部署时撞上）：
- `SchedulingConfig` 挂 `@ConditionalOnProperty("app.scheduling.enabled")`，`=false` 关的是**整个 `@EnableScheduling` 基础设施**，非单个 bean → worker 里**所有** `@Scheduled` 方法全部不触发。
- BuyVM worker **必须** `--app.scheduling.enabled=false`：data 模块有 ~12 个「无自己 flag、只受全局 scheduling」的定时任务（ActorStatistics/CategoryStatistics/CoViewCompute/Recommendation/RecomputeQueue/StockPublish/Jable/Avjiali/MovieDetail…），开全局 scheduling 会让它们在每台 BuyVM 上跟着醒，与 ca-admin 单实例形成 N 重跑（重复采集+统计污染+囤后放重复发布）。
- 于是「关 scheduling 保护 + @Scheduled 分片」互斥，`@Scheduled` 分片方案根本跑不起来。

正解（照 Kanav / cableav-port 既有范式）：
- 增量逻辑抽成**普通 bean（不带 @Scheduled）**，两个调用方共用：ca-admin 走 `@Scheduled`（scheduling 开），BuyVM worker 走 `POST /crawler/<src>/run-incremental` 由**本机 crontab** curl 驱动。
- worker 启动全 flag（照 launch-cableav.sh）：`--spring.profiles.active=prod --app.scheduling.enabled=false --app.crawler.<src>.enabled=true --crawler.<src>.brands=<本机子集> --server.port=999X --management.server.port=1999X`。**主端口和管理端口都要错开**（cableav 占 :9999+:19999；只改 server.port 不改 management.server.port → childManagementContext 撞 :19999 启动失败 "Port 19999 already in use"）。
- 触发端点异步受理（单轮几十分钟，cron 的 curl 不能挂着）+ **CAS 闸门**（先 compareAndSet 再提交，防 cron 周期短于单轮时叠跑=同厂牌书签并发推进+请求量翻倍=被封）。
- 分片配置（`crawler.<src>.brands`）未知输入 **fail-safe**：配错厂牌名一个都不匹配时**采空**而非回退全量（回退全量=该机重采所有厂牌、与其他分片机撞书签；漏采有零产出告警可观测，重复采静默）。

BuyVM 连线上 DB/Redis：走 CA **公网 EIP**（`DB_HOST=13.57.1.70`/`REDIS_HOST=184.72.0.67`），**非**私网 172.34.x（跨机房不可达）。secrets.env 里的 DB_HOST 可能是陈旧退役值，worker 靠 cableav.env（EIP 真值）覆盖。madou env 只需 cableav.env 11 键 + `APP_CRAWLER_MADOU_ENABLED=true`（R2/LLM 密钥从 DB system_config 读、走已有 DB 连接；段裸拉不需 proxy）。

相关：[[reference_crawler_parsedetail_null_contract]] [[feedback_gate_redgreen_and_failsafe_direction]] [[feedback_goldset_must_play_real_video]]
