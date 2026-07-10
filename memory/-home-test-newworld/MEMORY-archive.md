# MEMORY 归档（已收口条目，不进每会话索引；需要时文件搜索 recall）

> 2026-07-09 从 MEMORY.md「近期工作」归档。条目原文保留，细节看各 topic 文件。

- [★全量文档整理 合`f3cb6042` (07-07)](project_docs_consolidation_2026_07_07.md) — docs 58M→17M
- [★★统一域名失败转移 P0 SW-primary逃生 已上线(合`cf56c01b`,基线`fd80377e`) (07-06/07)](../../../../newworld/docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE.md) — P0已部署生产
- [★nw-cap hook排查+三类deny硬拦+日志 合`f0a01c43` (07-07)](project_nwcap_hook_deny_upgrade_2026_07_07.md) — subagent里hook本就生效(实证)
- [★★审计deferred拆分批2(B6/B9 Z13Penalty/PickPService)+swiper 合`afc7710a`+部署验证 (07-06)](project_b9_pickp_full_split_2026_07_06.md) — 已上线
- [★★前端可维护性审计:23Task 合`5e28106c`+四象限验证 (07-06)](project_frontend_maintainability_audit_2026_07_06.md) — 结论有序分层非面条
- [★广告上传GIF格式报错根治+退役槽隐藏+11槽复核 合`39f551fc` (07-06)](project_snack_gif_upload_and_slot_fixes_2026_07_06.md) — 根因=盲信文件名ext送gif2webp
- [★★审计deferred拆分(B7 ConfigController/B5 CfHttpClient/B9 PPoolService)+swiper12 合`e78214ea` (07-06)](project_b9_ppool_service_split_2026_07_06.md) — 已上线
- [★★广告位收敛19→13+单尺寸+纯图卡+命名v45 合`3467e0c5` (07-06)](project_snack_slot_consolidation_2026_07_06.md) — 全部署
- [★★广告尺寸提示三套矛盾→YAML单真相源+/slot-specs+软校验 (07-06)](project_snack_slot_size_hints_2026_07_06.md) — 两批全部署
- [★★CRAWL-STALL误报→真P1:P2-35 SSRF传参错致HLS全断18h 已修 (07-05)](project_crawl_stall_alert_ssrf_hls_outage_2026_07_05.md) — getRequestUri须getUri
- [★★07-05并发部署互相覆盖事故:三防线机制化(Gate M/Gate A/sha) (07-05)](project_concurrent_deploy_incident_2026_07_05.md) — web×6=9ba95945+deployed/web tag
- [★★全组件参数调优审计+P1落地+快照尖峰根治(df_snapshot_format=false,6s→0.13s) (07-05)](project_config_tuning_audit_2026_07_05.md) — ★RCA逐层现;去SCAN`11078abc`非尖峰真因
- [★★Redis废弃键清理+view-count HDEL+观看数秒级展示 合`a31f2fda` (07-05)](project_redis_stale_keys_cleanup_2026_07_05.md)
- [★context-mode A/B证伪停用+headroom否决+nw-cap hook上线 (07-05)](project_context_mode_retire_headroom_eval_2026_07_05.md) — ★评估上下文工具必真A/B+哨兵存活测试
- [★★前端错误TOP分析+Z13修复(合`27cc9a15`) (07-05)](project_frontend_error_top_analysis_z13_fix_2026_07_05.md) — ★guard.lua是PCRE非Lua pattern
- [★★07-05首屏占位LCP优化A/B/C 部署验证](project_firstscreen_placeholder_lcp_2026_07_05.md) — ★VO加字段×共享缓存×rolling=旧节点500
- [★★全代码审计(~113条)收口 07-04/05](project_full_code_audit_closure_2026_07_04.md) — 误报19条归档suppressions(`5ab28b6e`)
- [★★OOM监控改造+心跳误报+告警口径 合`1550cff3` (07-04)](project_oom_monitor_categraf_2026_07_04.md) — ★接采集先查categraf已启用插件
- [★MovieService上帝类拆分(B5)合`172bd4d0` (07-04)](project_movieservice_god_class_split_2026_07_04.md) — ★fact-check否决HeaderPageVO
