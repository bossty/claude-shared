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
- 全代码审计修复 SESSION-STATE (07-03,订正07-10) — **档已于07-22收官删除(BL-135,墓碑TOMBSTONES.md P9,取回`git show 2d803d7cf:docs/sprint/2026-07-02-full-code-audit/SESSION-STATE.md`)**;同目录FINDINGS.md/P2-VERIFICATION批次仍在。订正:FINDINGS.md已在master(git ls-tree实测);feat/recently-watched功能已否决删除,分支已清;openresty P1-19/20=BL-26已关闭(cherry-pick`43e6487e6`经merge`f6f67b925`入master,patch-id逐位等价)
- [★★GFW A池RUM接入reach:grid火测PASS (07-02,订正07-10)](project_gfw_apool_rum_phase3_firetest_2026_07_02.md) — 订正:已合master(`19bcc7f4`,血缘实测);07-09已决策不翻A_POOL_PENALTY_ENABLED;触发式再评估/07-23到期YAGNI结案=BL-17
- [★封面贴脸根治=BlurHash占位全链路 (06-29,订正07-10)](project_cover_blurhash_placeholder_2026_06_29.md) — 订正:已合master(首屏占位LCP合并`10260a0e`,blurhash-decode.js在master树,实测);分支已清
- [无异议backlog推进(排除BL-31~36):文档类BL-6/22/23合master`59186845`;代码类BL-3/4/5改完本地绿(**07-11已部署合master,见上条**) (07-11)](docs/sprint/_archive/2026-07-11-backlog-bl3-bl45-deploy/SESSION-STATE.md) — BL-6/23判定描述过期早已完成;CLAUDE.md测试数订正1310/200/1510+skill28→29;新增BL-41(skill文件32vs自动触发29缺口);bl45备份推送遇并行maven撞车假红隔离重跑绿SKIP_CI_LOCAL推
- [★★单人实践backlog BL-31~36全收口：Actions云门红绿双验+金丝雀SOP+错误上报治理+Flyway否决(ledger闸门替代)+集成环境 **两次合master`0d6cabb6`/`f2c43885`,云门均绿,零部署,分支已清** (07-10)](project_solo_practices_closeout_2026_07_10.md) — 评审逮3真bug(rename逃逸/base-ref fail-open/--rest基线tag说谎);新增BL-40=web本地dev被L0塌缩误判拒启动(次日已修合`459f6319`);GitHub PAT在buyvm-data可查Actions;**订正07-11:ops项已闭环**——ca-web-04实测未接任何CF LB pool(金丝雀永久走退化方案),BL-34已上生产,详见[[project_bl34_canary_deploy_2026_07_11]];评审曾担心的"--rest基线tag说谎"实测证伪(比的是md5非sha)
- [★★BL-30 生产备份修复+DR演练收口：核心档体系建成红绿双验+5轮RTO演练收4真坑 **已合master`ed48119f`,分支已清** (07-10)](project_bl30_backup_dr_2026_07_10.md) — 99天无备份P0闭环;fact-check推翻2表名推断(vid_alias_log/visitor_fingerprint必备份);RTO保守2h/采样验证206s;坑=GTID残留/还原默认参数13倍慢/binlog爆盘/ugrep截长行
- [★★UDF审计Batch3=M3 pick-p迁web后监控失明 **已修+红绿双验+合master`a6cf8028`** (07-10)](project_udf_m3_monitoring_2026_07_10.md) — 规则108盯已死指标`ops_pick_p_total{admin}`(VM零series)+分母clamp_min致恒0永不触发;edge`nw_s_*`从未采集;修=108改盯web非2xx+新增4规则(含2条fail-safe静默检测)+edge×3增采`:81/__pick_stats`;红验401注入→事件6551+TG3508,绿验自动恢复;**新发现aws-s跨洋RPC常态失败2.92%(snapshot兜底掩盖,reach-aware已降级)**;backlog=aws-s跨洋治理/error比率告警待1周基线/B4告警(134)DB里disabled=1与memory声明不符;判据泛化见[[reference_n9e_dashboard_alert_internals]]
- [★★UDF审计Batch2=M1 SW逃生final-host二次排除 **已修+真Chromium红绿双证(沙箱+buyvm)+部署6节点live+合master`7cf09882`(存证`a8a82d86`)** (07-10)](project_udf_m1_batch2_final_host_2026_07_10.md) — 裸apex被channel前缀重构回当前死host无二次排除→偷探测预算;修法applied===currentHostname二次排除两处同步;e2e复用m1-probe-target-e2e.mjs加currentTraceHits===0断言+SW_PATH红绿;WebKit ENV-LIMITED靠parity+iOS灰度;**合master时pre-push全量门跨run漂移无关Java假红(多会话并行maven撞车),SKIP_CI_LOCAL推+存证**;订正07-10:M3已由Batch3合`a6cf8028`收口
- [★闸门审计:修backend-pl空转(叶子后端push曾零测试)+合master慢门+分支生命周期SOP **已合master`8ba9731b`**;续:memory悬空根治(nw-memory-commit+软守卫)**已合master`d928f098`** (07-09)](project_branch_lifecycle_gates_2026_07_09.md) — pre-commit/pre-push无真重复;全量7min<10min口径不上细粒度选测;SOP全文docs/process/BRANCH_LIFECYCLE.md;memory纪律见[[feedback_memory_commit_discipline]]
- [★★UDF全系统对抗式审计(8维fable+high subagent)+Batch1后端修复 **Batch1已部署+合master`2dd9e726`(merge`870a0eb5`,deployed/web=f481f6fd);worktree/分支已清** (07-09)](../../../../newworld/docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE-audit-batch1.md) — 台账`AUDIT-2026-07-10.md`14条finding无一证伪;真缺陷=M2 deadRoots无min-n门(已修已部署,ReachHintService MIN_SAMPLES在产)/M3 pick-p迁web后告警失明(N9E 108盯死admin路径,**订正07-10:已由Batch3合`a6cf8028`收口**)/M1 SW逃生channel后置注入击穿current-host排除(escapeRoots ON已挡,kill-switch回滚广域复活,**订正07-10:已由Batch2合`7cf09882`收口**);Batch1三面部署(web×6+admin+edge×3)验证全绿:reach:grid wildcard_ok在产/pick-p RPC error=0/ReachFusionServiceTest26-26;**合master夹带别会话memory教训见[[feedback_git_commit_pathspec_shared_checkout]]**;剩C-2 ccTLD护栏/G-2 staggeredRace降量=BL-8/BL-9(项目级backlog真相源已建docs/BACKLOG.md `b452e7d0`)
- [★★会话token成本审计:真成本cache_read~70%(旧减噪瞄错tool_result 10%靶)→修nw-token-report+复活28skill自动触发+委派skill/大Read hook 合`3882495c`/`787b52f1` (07-08)](project_token_cost_audit_2026_07_08.md) — 机制vs纪律地图,真吊纪律只剩/clear分段;skill真相源=平铺claude-shared/skills非plugin;>5min空窗缓存重建;方法论[[feedback_measure_real_cost_before_optimizing]]
- [★统一域名失败转移 P0逃生复核缺陷修复 已上线(合`df6c8fa5`,fe-web`3dfea327`,web×6) (07-08)](../../../../newworld/docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE.md) — 四路复核后修M1(探即跳候选构造)/ccTLD护栏/kill-switch/clobber竞态;E2E PASS+部署后四象限4/4;backlog=iOS真机门/ccTLD后端断言;版本核验坑见[[reference_postdeploy_version_verify_cf_swr_stale]]
- [★统一域名失败转移 escapeRoots前端消费+三flag已激活 (07-08)](project_udf_backend_half_2026_07_08.md) — SW逃生用escapeRoots.roots有序取代池原序;ESCAPE_ROOTS/A_POOL_SOFT_SORT已翻true,软排序reach有序live(top_changed 9→629,四象限8/8);融合早已live非dark;follow-up=ConfigController:210-211 anchor/migrateTo未归一rootHost(不活跃)/ca-web-04 journald 0B
- [★★统一域名失败转移 后端半5Task 已上线波1(web×6+admin,合`3a632119`) (07-08)](project_udf_backend_half_2026_07_08.md) — ReachFusion保真+rum_n+A软排序两阶段+pick-p迁web+P→P渠道池+escapeRoots契约;波2待ops CF hostname;follow-up=A侧rootHost未归一
- [★★渠道归因/统计审计闭环:2P1+8P2+留存A修复 (07-05)](project_channel_attribution_audit_2026_07_05.md) — ★待拍板=基线换源=BL-10(docs/BACKLOG.md)

## 2026-07-15 归档（MEMORY.md 索引超预算瘦身：07-12 及更早、已收口条目移出；07-13+ 近期条目仍留主索引未动）
- [★★supjav 正式生产启用全线上线 **已合master`10839b4cf`**(永久边车/opt/supjav-fetcher+ca-admin autossh隧道+data.env flag+段限流按源分档+每小时定时) 生产金标PASS真出片118238 16/16封面 (07-12)](project_supjav_prod_enable_2026_07_12.md) — 段限流按段host分档(supjav段=Google Drive`googleusercontent`,4并发+300ms只收紧它不误伤其他源);scrapling不拉playwright/patchright驱动须全量pin;R2孤儿转BL-54;BL-52/53(vcsi/定时配置驱动化)立项
- [★memory暂存机制+BL-46/47+纯docs免重测 全部实施合master`db13a673`/`4367b353`,分支已清 (07-11)](project_memory_staging_and_relax_2026_07_11.md) — staging对sweep三处排除变异双验;ci-local自检NW_GATE_CALLER是防炸慢门关键;镜像/真相源.gitignore必须两侧同改(当天咬人)
- [★★多会话并行工作流加固五条全落地 **已合master`171b27c9`(push落点`b4487724`),分支/worktree已清** (07-11)](project_parallel_workflow_hardening_2026_07_11.md) — 共享checkout只读化hook+master单点化(SKIP_CI_LOCAL不可绕)+backlog占坑+分支push编译轻门14.7s(vs全量7min)+memory暂存设计待评审;评审逮8真缺陷(判据=逃生口叠加必推演既有逃生口是否旁路新卡口);待拍板=条2实施/BL-46/BL-47
- [★★BL-44 javxx 重诊断:真出片阻塞=stream API 直连403(非交接档"封面编码")+三修复验真出片(id=118090)+barePath伪装MP4后台坏图修+**Owner决策弃用123av转supjav** (07-12)](project_javxx_rediagnosis_pivot_supjav_2026_07_12.md) — 交接档详细诊断在因果层错(uploadCover finalize门只查barePath,mozjpeg-c null不回滚);真阻塞=fetchM3u8FromSurrit裸直连403产线trace坐实;修①proxy②③封面-frames:v1(AVIF185s→2s)+barePath抽帧;红绿+895绿;后台坏图=cover_image存伪装MP4前端用变体故只后台坏
- [★★BL-34前端错误上报+BL-40上生产+金丝雀SOP首次真跑 **已合master`adea4ea0`,deployed/web=`62e18003`,三层证据验证通过** (07-11)](project_bl34_canary_deploy_2026_07_11.md) — 首跑逮SOP三真缺陷(PromQL空结果被读成零错误=fail方向错/对照组误含ca-admin/ca-web-04未接CF LB pool=金丝雀永久退化方案);细节见topic文件;验证姿势[[reference_frontend_monitor_report_chain_verification]]
- [★★HTML壳阶段一上线+合master`868346cb`+阶段二核心价值(CF边缘缓存index.html)单zone eduspace181已配Cache Rule验HIT,进24h观察窗 (07-11)](docs/sprint/_archive/2026-07-06-html-shell-best-practice/SESSION-STATE.md) — 阶段一=零cookie壳(撤HTML Set-Cookie挪seedVid+ITP续命收canary门),6台OpenResty+前端8f747aa3峰窗FORCE_PEAK部署;阶段二=CF Cache Rule(path=/或/index.html→edge_ttl override_origin 60s,规则id`09372ab2`)强制覆盖origin no-cache,金标MISS→HIT age递增;**探针安全评估(Owner提出原漏评):缓存不削弱反侦察**——缓存的是静态EduStream伪装壳(词边界零敏感词)、GFW裸探测本就只看到壳、probeGate是客户端JS、敏感内容在加密API路径未缓存;早期信号path=/HIT~21%偏低(疑60s TTL×PoP分散)待24h干净窗复核;CF token已补zone.analytics.read;后台等待教训见[[feedback_one_wait_mechanism_per_bg_task]]（该阶段已被 07-15「HTML壳阶段二观测收口」条目接续，见 MEMORY.md 近期工作节）
- [★★BL-3/4/5 部署段收口：ops七节点+data jar 全上线 **已合master`dde105d0`/`07b1dc9c`,分支已清** (07-11)](docs/sprint/_archive/2026-07-11-backlog-bl3-bl45-deploy/SESSION-STATE.md) — BL-5②证伪撤回(正确覆盖=规则130消费outcome=error,判据[[reference_alert_rule_series_existence_check]]);新增BL-42(熔断整池短路双重静默);**熔断生产行为验证未完成**;其余细节见SESSION-STATE
- [★★07-05告警triage→监控统一N9E批0-4(合`ab28cb5f`)+批5待办](project_alert_triage_rule42_disk_n9e_2026_07_05.md) — ★data爬虫零告警=最大盲区
- [★★javxx/123av 断流三层根因:IP封禁×2已修合master`0cb8d594`+源站改版待做BL-44 (07-11)](project_javxx_ipban_revamp_2026_07_11.md) — 部署验证逐层揭盖:列表页IP封禁→修proxy后暴露资产CDN icdn.123av.me同封→修后暴露源站改版(poster参数移除/embed域surrit→javplayer/metadata块#video-details→dl.watch__info无冒号);推翻backlog"BuyVM出口07-08已否决"旧记载(直连403/proxy200);stale-target假红判据=clean重编能复现才真红

## 2026-07-22 收口归档批（BL-72/jable/BL-70/BL-59/supjav 整条下沉 + GFW P0/BL-64/BL-60-61/xvideos-goldset 过程下沉，索引留未决 stub）
- [★★HTML壳阶段二观测收口+BL-72 504三线triage,Owner 07-16拍板收官 (07-15)](docs/sprint/2026-07-15-bl72-504-triage/SESSION-STATE.md) — HIT偏低(60sTTL×PoP分散)→edge TTL 60→300s;②keepalive分支fix/bl72-keepalive-hygiene未部署③拦通配毙(200出壳91.9%随机子域=load-bearing);①「真504在CF Argo/LB派发层」主线归因已证伪→真相=CF记账伪影/浏览器预连接[[reference_cf_504_unk_protocol_accounting_artifact]];教训=改配置前查引用面+早期结论必fact-check
- [★jable封面链路事故:恢复源站原图兜底,已合master1271130f2+部署验证真出片122896,分支已清 (07-15)](reference_cover_miss_not_ipban_placeholder_probe.md) — 根因=DMM封面未上架+清理删行堵死hardCap;markDead失效立BL-71
- [★★BL-70 crawl-monthly页范围缺口修复✅已收口:合master a9e7cd2f7+5/6月全量采集核验(07-16) (07-15)](docs/sprint/_archive/2026-07-15-bl70-full-month-crawl/SESSION-STATE.md) — 源站best每月111页(原上限50页只采45%);库存status=3 400→5814部;蓝军[BLOCKER]cap=20<27条/页静默丢片[[reference_hardcoded_cap_silent_drop_masked_by_old_concurrency]];副产双管理坑[[reference_buyvm_best_worker_systemd_vs_launch_script]];数据全躺status=3用户不可见=有意设计(发布策略BL-68/best零监控BL-69)
- [★BL-59 madou.club采集接入 开发+测试完成,已合master18897cc8d;生产已按Owner指令停采清库、配置可逆保留;金标B类真出片PASS (07-13)](project_madou_crawler_2026_07_13.md) — 蓝军4MAJOR全修;基类null→SKIPPED守卫有跨爬虫副作用(削弱supjav熔断)→revert改madou本地根治
- [★supjav断流修复(referer 429):部署ca-admin已live核实,已合master e3dc68ca3 (07-13)](docs/sprint/_archive/2026-07-13-supjav-referer-fix/SESSION-STATE.md) — 根因=effectiveReferer把盗链referer套到Google Drive段致429;修=hls.referer-agnostic-hosts豁免;fMP4/key路径缺口→BL-56;同型第5次[[reference_source_ip_ban_dual_whitelist_flaresolverr]]
- [★★★GFW P0 ④ 二次翻案实证收口（过程；未决点见 MEMORY.md 近期工作 stub）](../../../../newworld/docs/sprint/2026-07-20-gfw-p0-gate-productionize/SESSION-STATE.md) — 最终定性=我方 bug 非外部劣化:无词边界裸403把结果表403ms/403.40KB/s当拦截页整域丢弃成功探测(被丢行节点全200),误诊为「aliyun外部风控灰度40%拒绝」9天;对照实验denied 40.6%→0.0%、成功率57.2%→97.2%;修复182db34ed合master0966e0f39,live 5aa50ed1(07-20部署);方法论见[[reference_negative_control_must_match_probe_semantics]];诊断取样禁进程级PROBE_DIAG_SAMPLE=1(全轮写journal)改每请求diag:true;蓝军8条(4MAJOR)没一条能靠自审发现
- [★★BL-64(原BL-60/63) xvideos best榜接入+20类分类金标1353条（过程；未决点见 MEMORY.md 近期工作 stub）](project_xvideos_best_onboarding_2026_07_14.md) — 已合master2aeca89a5+BL-65预览bug修复合master0cc02f61d;buyvm worker真采已开;dry-run两键07-16已删;预览bug根因见[[reference_handoff_source_structure_claim_must_verify]];best零入库四叠加根因(代码零调用+301+mandatory双通路绕过forbid);无码解放口径冲突致F1暴跌0.757→0.057;LLM批量模式100%失效(json_object返不了数组)
- [★★BL-60/61 madou广告水印识别+厂牌映射（过程；未决点见 MEMORY.md 近期工作 stub）](docs/sprint/2026-07-13-madou-crawler/SESSION-STATE-BL60-61.md) — ❌BL-60已放弃(Owner 07-14拍板不做自动检测、全部入库后续人工剔除,零代码);BL-61厂牌映射已完成合master ac1ea35ec(40前缀/17厂牌离线建表、运行时零LLM);放弃理由:角落烧录域名水印无现成方案+OCR误差会误杀好片;方案非蒸发是没落档[[reference_session_jsonl_archaeology_before_redesign]];真对手=域名水印非片头横幅
- [★★xvideos金标复核+region规则改造+入库端接入（过程；未决点见 MEMORY.md 近期工作 stub）](docs/sprint/2026-07-12-xvideos-goldset/SESSION-STATE.md) — 已合master372db27c1(--no-ff,实合25commits);准确率93.0%→97.0%;撤回上会话「自评」签字(同模型自评被三盲评员逮出25个漏);核心教训=源站tag本身脏(-3d/hentai/young-man见tag即判);Owner四拍板(cn=内容非产地/AMWF按女优算/禁硬编码刷100%/实现入库端)

## 2026-07-22 BL-131 阶段 1 暗孤儿补索引（原先不在任何索引、无任何 wikilink 指入 = 已彻底不可达；经逐份读正文 + 仓库代码核实仍成立）

**生产架构唯一存档**（组件仍在线上跑，docs/ 无对应 durable 档，最危险的一类）
- [首页 cursor feed 三 tab 架构](project_cursor_feed_sprint_2026_05_24.md) — 3tab×(global+5region)=18 ZSET + sid-Bloom + client IDB + Base64url cursor；SHUFFLE_WINDOW=Math.min(pool,5000)；MyBatis IN 不保顺序须 LinkedHashMap 重排
- [采集/上线解耦 + StockPublisher（status=3「存量」语义唯一定义处）](project_cableav_decouple_stockpublisher_2026_06_16.md) — movie 状态机 0草稿/1上线/2dead/3存量；采集禁 addToBloom 只上线时 add；乐观锁 UPDATE...AND status=3；pilot 小量先跑揪出 3 个 prod-scale-only bug
- [缺索引慢SQL打爆 HikariCP 的诊断顺序](project_v6_cluster_root_idx_hotfix_5_12.md) — HikariCP 满→PROCESSLIST 找 TIME>5→EXPLAIN；ORDER BY+LIMIT 1 最易被优化器误选反扫；止血用 ADD INDEX ALGORITHM=INPLACE LOCK=NONE；buyvm-db 备份库 schema 不自动同步
- [rum_image_load 采集已冻结（含复活三步）](project_rum_image_load_collection_frozen_2026_06_21.md) — 停采不停清理会 7 天删空快照；Micrometer 低频 gauge 必用 AtomicLong 强引用否则 GC 后 NaN

**生产实测数据 / 选型论证（防重新论证）**
- [CF Free 缓存能力实测边界](project_firstscreen_edge_cache_2026_06_06.md) — CF 默认按扩展名不缓存 HTML/JSON；Free 的 Cache Rules 无 2h floor（那是旧 Page Rules），强制 60s edge TTL 可行；Cache Everything 会自动剥 Set-Cookie；serve_stale≠SWR；Custom Cache Key 是 Enterprise only
- [搬瓦工 HK 机房对移动结构性不可用](feedback_bandwagon_hk_mobile_fail.md) — 只接 CN2 GIA+联通无 CMI，移动多地 100% 丢包，改 IP/升级都救不了；HK 选址复议先看这条
- [S 层 edge 选型=搬瓦工 USCA_9 ×2 + aws-s](reference_edge_vps_usca_9.md) — 弃 HK 因移动 100% 丢包；「三网直连」必实测 ping.pe/itdog/17ce 不信文案
- [写主 binlog 撑爆盘：降 7 天 + PURGE + EBS 在线扩](project_ca_master_binlog_disk_2026_06_21.md) — PURGE 前必验 replica Source_Log_File 追平；MySQL 8.4 SHOW MASTER STATUS 已废；EBS 同卷 6h 冷却且只扩不缩

**诊断判据 / 排查坑（一次性极难重得）**
- [CF 5xx 分析必用 httpRequestsAdaptiveGroups，1hGroups 漏报 CF 自生成 504](reference_cf_graphql_504_adaptive_vs_1hgroups.md) — 同窗口 504=0 vs 167k；adaptive 是采样，百分比可信绝对数是估计
- [缓存/慢查询诊断三坑](project_cache_gap_slowquery_audit_2026_06_21.md) — TwoLevelCache 有 ±10% TTL jitter→禁据 TTL 跨度判「同时 warm vs 懒填」；配置改动效果必等稳态测（连接池重建造瞬时尖峰反向读数）；EU 无 redis-cli→手测「失败」是工具缺失假象
- [迁移后监控失真三类病根（未对应/多余/未上报）](project_n9e_monitoring_repair_2026_06_15.md) — 改 dashboard/alert promql 前先 curl VM 实测 label 真值；orphan ident 幽灵 series 会让主机告警误报；告警静默失真比服务挂更隐蔽
- [ip/uv 比例=流量性质信号 + bot cookie-churn 灌 UV 的识别法](project_ipuv_anomaly_bot_rca_2026_06_29.md) — <0.3=bot / ~1.0=桌面 / >1=移动（IPv6 隐私轮换+CGNAT）；真人基线看 watched_uv 与 IP 池是否同涨；IPv6 按 /64 归一会造口径阶跃断裂须灰度
- [爬虫源「下不动」先分层 curl 实测，别猜源站挂](feedback_cableav_hls_failfast.md) — 单段/并发/时段三测才定根因；下载并发按源站单 IP 容忍线定（10 被掐、4 健康）；HLS fail-fast 限单部不限整档
- [蓝军二轮复核四盲点与 lead 二查裁决法](reference_blueteam_rereview_blindspots_2026_06_21.md) — reviewer 只有 git 视野看不见会话内 live ops；它的机制描述可能错但方向对；回归 vs 漏网必 `git log -S` 溯源定 severity；★Dragonfly EVAL 比 Redis 严格，脚本内 KEYS 拿的 key 必须预声明→批删改客户端 SCAN + 分批 UNLINK
- [本地测试箱假死 RCA + oomd 加固 + MySQL 配置 alternatives 链](reference_localbox_freeze_oomd_mysql_repair_2026_06_21.md) — 内存耗尽时内核 OOM-killer 可能不触发（小 swap thrashing→整机冻），已装 systemd-oomd；★`/etc/mysql/my.cnf` 现是符号链→/etc/alternatives/my.cnf→/etc/mysql/mysql.cnf

**前端 / 浏览器层**
- [iOS Safari 卡死类问题必测 WebKit 进程 RSS 而非 JS heap](reference_webkit_native_rss_video_leak_probe.md) — 原生 media 内存不进 JS heap，JS heap 全程平会完全掩盖泄漏；video unmount 必 pause+removeAttribute+src=''+load() 四步
- [图标在 DOM 却不绘制=复杂 SVG path 栅格化 bug](reference_complex_svg_icon_raster_bug.md) — 开 DevTools 就显/关掉又没=首帧不绘制；诊断=比同类图标 path.d 长度找离群值；translateZ(0) 无效，唯一修法=换简单图标
- [owl-carousel + jQuery 不可轻易替换](feedback_owl_carousel.md) — CSS scroll-snap 替不掉 loop/drag momentum/touch velocity，已回滚过一次；要换只能 Swiper
- [PSI 审计只用 pagespeed.web.dev 不用 Lighthouse CLI](feedback_psi_testing.md) — CLI 模拟 4x CPU+慢 3G 过严不真实（Owner 工具偏好）

**采集 / 媒体**
- [HLS 注入广告片头去除 + 源站「Tags」是模板块的证伪](project_cableav_adintro_tags_javxx_2026_06_18.md) — 判广告片头用「片头段与正片段目录前缀不同」（按是否加密门控会被明文源击穿）；正片 AES 无显式 IV 时禁丢片头；判「是否 per-video」必 diff 两个不同视频的完整集
- [beeg/jable 官方预览 mp4 URL 规律](reference_beeg_preview_url.md) — 源站自带短 preview，别退回 HLS 抽帧拼接（fMP4 缺 EXT-X-MAP 会 ffprobe 失败）
- [广告图可靠性：SW 预缓存必须独立持久 + cache-bust 实证](project_ad_image_reliability_2026_06_14.md) — SW 缓存名禁随 BUILD_HASH 滚动（否则每部署清空又跨洋）；`?cb=` 对 CF 有效且不破防盗链（WAF 匹 referer 不匹 query）；impression 与图加载解耦→失败位必填品牌卡

**工具链**
- [.lsp.json Vue hybrid 配法 + plugin 打包权威结构](reference_cc_lsp_plugin_setup.md) — Volar 3.0 删了 take-over，.vue 必须路由进 tsserver 挂 @vue/typescript-plugin（单跑 vue-language-server=0 命中）；hooks.json 顶层必须有 "hooks" 包裹键。★订正 [[reference_lsp_toolchain]] 里过期的「无 vue-lsp」结论

**以下 4 份原判暗孤儿有误（实有 wikilink 指入，仅索引缺位），一并提升为索引直达**
- [DNS 摘除/回填=多 IP 轮询的止血手段](reference_dns_drain_refill.md) — 某 edge 节点 100% 500 时删该 IP 的 A 记录让流量走剩余 IP；必先存删除前 JSON 到 rollback 目录；回填前必 `curl --resolve` 强打该 IP 多次确认 302
- [confirmed_blocked / probe 0.00 ≠ 被 GFW 封](reference_gfw_confirmed_blocked_trap.md) — provisioning 没配完整会产生一模一样的信号；下结论前必查边缘 TLS / apex A 记录（探针探裸 apex 非子域）/ 中国 resolver；cert 下发只认 status=active→blocked 域永远拿不到证书的 catch-22
- [S 域 status 语义：standby 本就无 DNS、retired 仅给「用过」的域](reference_s_domain_status_lifecycle.md) — 核 DNS 齐全度只核 active，standby dig 0 记录不是 bug；never activated 的健康域其渠道被删应退回 standby 不能 retire
- [全栈 HK 时区统一 + 存量 UTC/HK 混合的雷](reference_timezone_hk_unification.md) — 盲目 +8h 会改错一半；DATETIME 需手工加、TIMESTAMP 不能再加；HikariCP 池回收致 split-brain 故重写用主键 id 边界不能用时间边界
- [OpenAI relay 迁移 AWS US + 过度设计自评撤回](project_openai_relay_aws_us_2026_05_25.md) — 「EIP 漂」先分源端还是目的端；AWS/GCP datacenter ASN 被 CF 内置规则直接 403（FlareSolverr 解不掉）须住宅池；非自家流量用 444 不用 403；OpenAI secret key 永远拿不到 usage

**以下 3 份原判 MERGE，改为保留补索引**（前两份的知识点目标是 skill 而非 memory，改 skill 须走 home+plugin 同步四步，不在本任务范围；第三份存在未决矛盾）
- [region 上线就绪门禁（回滚判据）](project_region_readiness_gate_2026_06_08.md) — 回滚只认 origin 5xx 绝对数 + cache-miss RTT，禁用 rate（分母稀释）和客户端 api_fail；★档内 `scripts/check-region-read-routing.sh` 已不存在，现仅 region-readiness-gate.sh 在
- [首页批量 API 失败 RCA：「缺 LIMIT」可能是设计意图](project_fe_error_rca_2026_06_04.md) — 发现「缺 LIMIT / 缺 X」先 `git log -S` 查是不是被人专门删过——删除即设计意图，加回去 = 重新引入已修的语法错
- [Phase 0 冷切换（矛盾已于 07-22 实测结案）](project_2026_04_21_phase0_golive.md) — 原「openresty systemd `EnvironmentFile` 传不到 nginx master、须 bash wrapper」**已证伪：从来就不成立，是判据错**——`/proc/<master>/environ` 被 nginx setproctitle 覆写成 argv 尾巴，对 nginx 天然不是有效判据；04-25 用纯 EnvironmentFile + lua `os.getenv()` 反查已正证注入正常（`docs/design/wave_stats_v4_sprint_closure.md:307-321` §6.4）。故 wrapper 功能多余但 3 台 edge 仍在跑（未回退，不阻塞）。副产：仓库 `ops/systemd-prod/openresty/wave_stats_v4.conf` 是僵尸文件，7 台实查生产哪儿都没装，勿照搬。档内 zone_id / IP / aws-monitor 均已退役

**二阶暗孤儿补索引**（因引用它们的档在本批被删而新失联；未经逐份价值判定，按「不确定则保留可达」处理，留待阶段 2 复核）
- [cdn-fail 告警 95-98% 是结构性指标假象](project_cdn_fail_metric_artifact_2026_06_21.md) — 成功路径静默无分母，非域名被烧；boce 实证 SNI 没烧→别急着买域；含 F3 双计数 bug
- [CF 静态缓存 × 前端版本时效 × 老客户端兼容](project_cf_static_cache_versioning_2026_06_05.md) — 证伪「静态没缓存=最大瓶颈」前提；76% 卸载率仲裁；iOS 白屏 P0

## 2026-07-23 BL-144 阶段③ Task 4 project 型清算批 1（净删 2 份，双判据+全域引用面核查后确认；清单/判据全表见 docs/sprint/2026-07-22-bl144-agent-first-restructure/PHASE3-TASK4-MEMORY-DISPOSAL.md，取回=本批 commit）
- project_docs_consolidation_2026_07_07.md — 已删。①已合 master `f3cb6042` 收官 ②memory 目录 + newworld 仓库全域 0 活引用（仅此归档账行） ③教训全沉淀：三层文档流水线→`docs/DOC_GOVERNANCE.md` v2.0；`TZ=Asia/Shanghai git push` 坑→保留档 `project_snack_sweetspot_transcode_2026_07_09` + `project_frontend_maintainability_audit_2026_07_06`；共享 checkout 干纯 docs 违纪→`feedback_shared_checkout_write_ops_owner_check` + `feedback_feature_branch_deploy_test_then_merge`。
- project_memory_staging_and_relax_2026_07_11.md — 已删。①已合 master `db13a673`/`4367b353` 收官 ②全域 0 活引用 ③机制已逐字沉淀 CLAUDE.md 分支铁律第 6 条（nw-memory-stage / --stage / sweep 三处排除 / --only 例外通道）；镜像与真相源 `.gitignore` 两侧同改坑→`feedback_memory_commit_discipline`（line 20①+line 35 泛化教训）。
> 同批据新证据改「维持现状（不删）」的原净删候选：`project_bl30_backup_dr_2026_07_10`（`docs/infra/DR_RUNBOOK.md:85` 有活指针「速览版在 memory」，durable 档故意引用，BUCKETS 漏检此外部引用）；`project_v6_cluster_root_idx_hotfix_5_12` 与 `project_firstscreen_edge_cache_2026_06_06`（BL-131 阶段 1 于 07-22 刚逐份判定「仍成立」并补进本档索引，不反转数日前的刻意保留）；`project_firstscreen_placeholder_lcp_2026_07_05`（VO×Redis 反序列化 500 / readAllBytes-before-waitFor 后端坑未沉淀 + SnackImageEncryptService 同款隐患未修 open item）；`project_region_replica_io_saturation_2026_06_08`（独有 EBS IOPS 非对称实测 + 误诊纠正教学价值）。
