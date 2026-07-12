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

## 2026-07-11 归档（并行工作流加固会话瘦身:已完结且待办已进 BACKLOG）
- [★★广告图500KB cap根治=甜点位+Snack01浅色主题cover事故修复 **已合master`714e2f55`全收口** (07-09)](project_snack_sweetspot_transcode_2026_07_09.md) — 教训=target/被jdtls污染致ci-local假红,见`Unresolved compilation problem`先clean
- [★★H3逃生腿验证sprint三Part全实测完成 **已合master`0cc709cf`全收口,CN ECS已销毁,无遗留待办** (07-09)](../../../../newworld/docs/sprint/gfw-h3-escape-validation/SESSION-STATE.md) — 结论:本次未坐实真实TCP死QUIC活→不常态化QUIC源;ECH不押注;注入器方法论(本机sudo+nft+静态h3curl模拟传输层封锁)与场景A/B/C全绿细节见SESSION-STATE;backlog另立项=真机iOS SW逃生/跨域escapeRoots消费/UDF后端reach回归
- [★UDF B4 blockType gauge 已部署+告警规则建但**未启用**(id=134 disabled=1)+**已合master`c30719b8`收口** (07-09,订正07-10)](../../../../newworld/docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE.md) — 核心实证=CF整封表现为tcp_reset非ip_block;UDF全线代码基线与在产一致。**订正07-10**:旧写"告警启用"过期,生产DB实查 rule 134 `disabled=1`(设计内先建后启,阈值0.5占位),该订正memory非DB=BL-16;ConfigController latent rootHost follow-up 经fa6891f1核实已消除(normalizeExcludeRoot两路共用归一)
- [★★domain-health去SCAN(桶化索引替代12.45M键全库SCAN) **已合master并部署,flag已开** (07-06,订正07-10)](project_z13_domain_health_no_scan_2026_07_06.md) — 订正:97ba91b0已在deployed/web血缘(merge-base实测),分支已删;OPS_Z13_INDEX_ENABLED生产DB=true(update_time 2026-07-07 01:35:21,nw-mysql实查)
- [★★审计deferred批1:B1 domain_health_log(z7权威)合`b7a8c244`+swiper11→12.2.0清CVE合`a1e7f464` (07-06,订正07-10)](project_audit_deferred_batch1_swiper12_2026_07_06.md) — 订正:a1e7f464已在deployed/frontend-web血缘,仅剩线上四象限视觉补验=BL-19(docs/BACKLOG.md)
- [★部署git pre-flight五道门+deployed/*基线tag 合`38aef9d6` (07-05)](project_deploy_git_preflight_2026_07_05.md) — 订正07-10:CI按diff分级已完成(`a7b5ce7d`已合master,血缘实测),无遗留
- [★Kanav健康核查+封面bug修复 (07-04,订正07-10)](project_kanav_health_cover_fix_2026_07_04.md) — 订正:db45133a与5c9c31d9均已合master(血缘实测);Kanav生产仍0部(无cron只手动端点),待自然验证=BL-18
- [★★爬虫批量收敛(B4):9家迁基类+4家排除 (07-04,订正07-10)](project_crawler_convergence_batch_2026_07_04.md) — 订正:fe958322已合master(B4本体`3152a5fa`,血缘实测);遗留两点surface=BL-13;AUTO_INC=90000000
- [全代码审计修复 SESSION-STATE (07-03,订正07-10)](docs/sprint/2026-07-02-full-code-audit/SESSION-STATE.md) — 订正:FINDINGS.md已在master(git ls-tree实测);feat/recently-watched功能已否决删除,分支已清;剩openresty P1-19/20 defer=BL-26
- [★★GFW A池RUM接入reach:grid火测PASS (07-02,订正07-10)](project_gfw_apool_rum_phase3_firetest_2026_07_02.md) — 订正:已合master(`19bcc7f4`,血缘实测);07-09已决策不翻A_POOL_PENALTY_ENABLED;触发式再评估/07-23到期YAGNI结案=BL-17
- [★封面贴脸根治=BlurHash占位全链路 (06-29,订正07-10)](project_cover_blurhash_placeholder_2026_06_29.md) — 订正:已合master(首屏占位LCP合并`10260a0e`,blurhash-decode.js在master树,实测);分支已清
- [无异议backlog推进(排除BL-31~36):文档类BL-6/22/23合master`59186845`;代码类BL-3/4/5改完本地绿(**07-11已部署合master,见上条**) (07-11)](docs/sprint/2026-07-11-backlog-bl3-bl45-deploy/SESSION-STATE.md) — BL-6/23判定描述过期早已完成;CLAUDE.md测试数订正1310/200/1510+skill28→29;新增BL-41(skill文件32vs自动触发29缺口);bl45备份推送遇并行maven撞车假红隔离重跑绿SKIP_CI_LOCAL推
- [★★单人实践backlog BL-31~36全收口：Actions云门红绿双验+金丝雀SOP+错误上报治理+Flyway否决(ledger闸门替代)+集成环境 **两次合master`0d6cabb6`/`f2c43885`,云门均绿,零部署,分支已清** (07-10)](project_solo_practices_closeout_2026_07_10.md) — 评审逮3真bug(rename逃逸/base-ref fail-open/--rest基线tag说谎);新增BL-40=web本地dev被L0塌缩误判拒启动(次日已修合`459f6319`);GitHub PAT在buyvm-data可查Actions;**订正07-11:ops项已闭环**——ca-web-04实测未接任何CF LB pool(金丝雀永久走退化方案),BL-34已上生产,详见[[project_bl34_canary_deploy_2026_07_11]];评审曾担心的"--rest基线tag说谎"实测证伪(比的是md5非sha)
- [★★BL-30 生产备份修复+DR演练收口：核心档体系建成红绿双验+5轮RTO演练收4真坑 **已合master`ed48119f`,分支已清** (07-10)](project_bl30_backup_dr_2026_07_10.md) — 99天无备份P0闭环;fact-check推翻2表名推断(vid_alias_log/visitor_fingerprint必备份);RTO保守2h/采样验证206s;坑=GTID残留/还原默认参数13倍慢/binlog爆盘/ugrep截长行
- [★★UDF审计Batch3=M3 pick-p迁web后监控失明 **已修+红绿双验+合master`a6cf8028`** (07-10)](project_udf_m3_monitoring_2026_07_10.md) — 规则108盯已死指标`ops_pick_p_total{admin}`(VM零series)+分母clamp_min致恒0永不触发;edge`nw_s_*`从未采集;修=108改盯web非2xx+新增4规则(含2条fail-safe静默检测)+edge×3增采`:81/__pick_stats`;红验401注入→事件6551+TG3508,绿验自动恢复;**新发现aws-s跨洋RPC常态失败2.92%(snapshot兜底掩盖,reach-aware已降级)**;backlog=aws-s跨洋治理/error比率告警待1周基线/B4告警(134)DB里disabled=1与memory声明不符;判据泛化见[[reference_n9e_dashboard_alert_internals]]
- [★★UDF审计Batch2=M1 SW逃生final-host二次排除 **已修+真Chromium红绿双证(沙箱+buyvm)+部署6节点live+合master`7cf09882`(存证`a8a82d86`)** (07-10)](project_udf_m1_batch2_final_host_2026_07_10.md) — 裸apex被channel前缀重构回当前死host无二次排除→偷探测预算;修法applied===currentHostname二次排除两处同步;e2e复用m1-probe-target-e2e.mjs加currentTraceHits===0断言+SW_PATH红绿;WebKit ENV-LIMITED靠parity+iOS灰度;**合master时pre-push全量门跨run漂移无关Java假红(多会话并行maven撞车),SKIP_CI_LOCAL推+存证**;订正07-10:M3已由Batch3合`a6cf8028`收口
- [★闸门审计:修backend-pl空转(叶子后端push曾零测试)+合master慢门+分支生命周期SOP **已合master`8ba9731b`**;续:memory悬空根治(nw-memory-commit+软守卫)**已合master`d928f098`** (07-09)](project_branch_lifecycle_gates_2026_07_09.md) — pre-commit/pre-push无真重复;全量7min<10min口径不上细粒度选测;SOP全文docs/BRANCH_LIFECYCLE.md;memory纪律见[[feedback_memory_commit_discipline]]
- [★★UDF全系统对抗式审计(8维fable+high subagent)+Batch1后端修复 **Batch1已部署+合master`2dd9e726`(merge`870a0eb5`,deployed/web=f481f6fd);worktree/分支已清** (07-09)](../../../../newworld/docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE-audit-batch1.md) — 台账`AUDIT-2026-07-10.md`14条finding无一证伪;真缺陷=M2 deadRoots无min-n门(已修已部署,ReachHintService MIN_SAMPLES在产)/M3 pick-p迁web后告警失明(N9E 108盯死admin路径,**订正07-10:已由Batch3合`a6cf8028`收口**)/M1 SW逃生channel后置注入击穿current-host排除(escapeRoots ON已挡,kill-switch回滚广域复活,**订正07-10:已由Batch2合`7cf09882`收口**);Batch1三面部署(web×6+admin+edge×3)验证全绿:reach:grid wildcard_ok在产/pick-p RPC error=0/ReachFusionServiceTest26-26;**合master夹带别会话memory教训见[[feedback_git_commit_pathspec_shared_checkout]]**;剩C-2 ccTLD护栏/G-2 staggeredRace降量=BL-8/BL-9(项目级backlog真相源已建docs/BACKLOG.md `b452e7d0`)
- [★★会话token成本审计:真成本cache_read~70%(旧减噪瞄错tool_result 10%靶)→修nw-token-report+复活28skill自动触发+委派skill/大Read hook 合`3882495c`/`787b52f1` (07-08)](project_token_cost_audit_2026_07_08.md) — 机制vs纪律地图,真吊纪律只剩/clear分段;skill真相源=平铺claude-shared/skills非plugin;>5min空窗缓存重建;方法论[[feedback_measure_real_cost_before_optimizing]]
- [★统一域名失败转移 P0逃生复核缺陷修复 已上线(合`df6c8fa5`,fe-web`3dfea327`,web×6) (07-08)](../../../../newworld/docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE.md) — 四路复核后修M1(探即跳候选构造)/ccTLD护栏/kill-switch/clobber竞态;E2E PASS+部署后四象限4/4;backlog=iOS真机门/ccTLD后端断言;版本核验坑见[[reference_postdeploy_version_verify_cf_swr_stale]]
- [★统一域名失败转移 escapeRoots前端消费+三flag已激活 (07-08)](project_udf_backend_half_2026_07_08.md) — SW逃生用escapeRoots.roots有序取代池原序;ESCAPE_ROOTS/A_POOL_SOFT_SORT已翻true,软排序reach有序live(top_changed 9→629,四象限8/8);融合早已live非dark;follow-up=ConfigController:210-211 anchor/migrateTo未归一rootHost(不活跃)/ca-web-04 journald 0B
- [★★统一域名失败转移 后端半5Task 已上线波1(web×6+admin,合`3a632119`) (07-08)](project_udf_backend_half_2026_07_08.md) — ReachFusion保真+rum_n+A软排序两阶段+pick-p迁web+P→P渠道池+escapeRoots契约;波2待ops CF hostname;follow-up=A侧rootHost未归一
- [★★渠道归因/统计审计闭环:2P1+8P2+留存A修复 (07-05)](project_channel_attribution_audit_2026_07_05.md) — ★待拍板=基线换源=BL-10(docs/BACKLOG.md)
