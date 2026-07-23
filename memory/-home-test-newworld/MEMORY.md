<!-- 索引仅留：近期工作 + 全部 feedback 铁律 + load-bearing reference。已完结一次性 sprint topic 文件在盘,文件搜索 recall,不进索引。07-05 压缩:hook 一行要点,已完结旧条目仅留标题,细节看 topic 文件。07-09 瘦身:已收口旧条目移 MEMORY-archive.md(同目录,不进每会话 context),收口即归档为常态。 -->

> **backlog 单一真相源 = 仓库 `docs/BACKLOG.md`（BL-1~27，建于 2026-07-10 `b452e7d0`）**。memory 只记教训与已完成事实，**不记待办状态**（待办写进 BACKLOG.md）；下方条目里的 backlog 引用一律指向 BL-x 编号。

## 近期工作 / 进行中（生成段：nw-bl render-memory-recent，禁手编）

- ★BL-145 DoH TXT 同步无互斥:并发运行互删记录 → 83011 写失败致域名池残缺（分支 `fix/doh-sync-concurrency-race`，认领 2026-07-22） — 详情 `docs/sprint/2026-07-22-bl145-doh-sync-race/SESSION-STATE.md`
- ★BL-144 伞形：agent-first 项目重构（分支 `feat/bl144-state-consolidation`，认领 2026-07-22） — 详情 `docs/sprint/2026-07-22-bl144-agent-first-restructure/PRD.md`
- ★BL-78 BuyVM 三台采集机零监控 + 6 实例无回滚（分支 `feat/bl78-bl69-crawler-monitoring`，认领 2026-07-21）
- ★BL-76 GFW P0 部署工具安全线（分支 `fix/gfw-supervised-p0-rollout`，认领 2026-07-19）
- ★BL-12 全局 secret fail-fast 校验器（分支 `feat/bl12-secret-fail-fast`，认领 2026-07-19）
- ★BL-1 aws-s 跨洋 pick-p RPC 常态失败 2.92% 治理（分支 `fix/bl1-pickp-read-timeout-700`，认领 2026-07-19）

> 上表由 BL 台账 in-progress 条目生成(nw-bl render-memory-recent);旧手写近期行已随 BL-144 阶段②生成化移除,状态查 docs/BACKLOG.md。


## reference(load-bearing,常 recall)
- [pipefail管道「生产者|提前退出消费者」大输入SIGPIPE 141静默翻转判定,一天四逮](reference_pipefail_early_exit_consumer_sigpipe.md) — 闸门脚本禁echo|grep -q/awk提前exit,改herestring/纯bash;修复必grep同文件全部同构点;红绿验必含>64KB用例
- [每日增长型产物必算稳态占用对照盘容量](reference_daily_growth_steady_state_capacity.md) — binlog/备份爬坡期水位会涨到稳态;运行值vs持久化值diff揪未落档SET GLOBAL

[给既有流程加钩子必须单独证明「钩子真的执行过」，测试全绿常是绕开新代码](reference_new_hook_needs_execution_proof.md) — 加钩子前须通读宿主早退点+造必触发输入单独验
[文档校准必须三层：校准→蓝军审diff→复验处置](reference_doc_calibration_needs_three_layers.md) — 52 份实测 0 份自评可信；每层都逮到上一层的错；蓝军须审真实 diff 不看自述
[文档为文档背书不是证据：X档说Y档有效只当线索](reference_doc_vouching_for_doc_is_not_evidence.md) — 档头与正文矛盾则两者都不可信;权威性=常量>注释、生产实查>文档
- [cohort 池化必须 list+count 双覆盖](reference_cohort_pool_list_count_dual_coverage.md) — 只改list是把慢SQL挪到count上;须全栈扫描而非逐个打补丁
- [抓源站视频流必须做 frame 归属判定](reference_media_stream_attribution_needs_frame_ownership.md) — URL关键词宽松匹配会把广告小组件流误认成正片,据此凭空立项过一个解扰器
- [采集集体冻结先查 /tmp：tmpfs 泄漏致池归零](reference_tmpfs_leak_starves_playwright_pool.md) — pool-size=1把「一次重建失败」放大成永久死亡,全程只有一行log.error
- [Redis拒绝active-active完整论证链(2026-06-02)](reference_redis_no_active_active_decision_chain.md) — 换引擎门槛0/3永不触发;再有人提Redis多活先走本条,别重跑调研
- [广告转化下跌误诊教训(2026-05)](reference_ad_conversion_drop_misdiagnosis_2026_05.md) — 真因=灰产落地域轮换被封周期复发;拨测必用DB完整URL含端口路径;binlog只留~6天须早取证
- [负对照采样口径必须与被测判据逐字一致，否则量出假零](reference_negative_control_must_match_probe_semantics.md) — GFW④实事故:裸403判据误杀成功探测、误诊9天;★journalctl --utc只改显示不改解析
- [「不存在/没做/未发生」类断言必须两条独立判据交叉验证](reference_absence_claims_need_two_independent_probes.md) — find -newermt 撞 cp -p 保留mtime=必然漏检;判存在性用路径+sha256不用时间;与[[reference_bare_substring_gate_needs_success_evidence_backstop]]是硬币两面
- [「文本匹配即丢弃」类判据必须有成功证据兜底](reference_bare_substring_gate_needs_success_evidence_backstop.md) — 否则裸子串必误杀;★结构性防护优于把正则写准;判据无真样本则结论不可证伪
- [信号「整月0→突增」先查采集机制何时建的，别当劣化](reference_signal_onset_is_collector_birth_not_phenomenon.md) — 翻案靠跨改动的同口径基线;坏探针会伪造「全绿」
- [sprint 文档归档清算三坑](reference_doc_archive_audit_pitfalls.md) — 机械判据「memory提过=已完结」系统性过宽须全量复核;exclude用路径不用basename
- [主checkout被他会话占用时安全合master](reference_merge_master_when_main_checkout_busy.md) — 临时detached worktree合并+回主checkout推特定sha;直接合会夹带别人未推送commit
- [N9E规则落库+PromQL对≠engine真eval](reference_n9e_rule_live_redtest.md) — live红验证法(压阈+for=0看真出事件);★凡「稳态恒0」的告警都该做一次live红验证
- [冷却/短路/跳过类修复的生产验证:命中路径常无日志](reference_nolog_codepath_validate_via_state_key_trajectory.md) — 用状态key(fail-count)分布轨迹看runaway/frozen,非grep
- [CF 504+origin=0 先查protocol=UNK判记账伪影(07-16重大订正:GFW归因已证伪)](reference_cf_504_unk_protocol_accounting_artifact.md) — 最佳解释=浏览器预连接伪影,用户无感无需修;地理集中必换对照源验分母
- [「同几番号反复失败+产出骤降」≠IP封](reference_cover_miss_not_ipban_placeholder_probe.md) — 历史命中URL复测+占位图语义判别;封面miss删行→markDead失效→循环重采堵死hardCap
- [buyvm best worker: systemd unit vs launch脚本双管理打架](reference_buyvm_best_worker_systemd_vs_launch_script.md) — 会报假READY;判活=ss看ESTAB+CPU时间+线程数,非日志
- [硬编码 cap < 每页条数 = 静默丢片](reference_hardcoded_cap_silent_drop_masked_by_old_concurrency.md) — 旧并发冗余扫描意外补缺口掩盖它,改硬分片才第一次真咬人
- [手敲启动的worker重启必丢env→回落退役默认值10.0.0.40](reference_handstarted_worker_restart_loses_env.md) — worker假「UP」但业务必败;一律用launch-*.sh,杀进程禁pkill -f

- [交接档说「方案随context蒸发」必先去会话jsonl考古再重做](reference_session_jsonl_archaeology_before_redesign.md) — 根因=subagent正文只口头复述从未落档→必须当场整段写进sprint档
- [交接档「源站无某字段」结论必抓真页面证伪](reference_handoff_source_structure_claim_must_verify.md) — 凭代码注释推断被一次curl翻案;附preview上传不验类型+key复用CF stale坑
- [金标真值与被评测配置同源=循环论证](reference_goldset_truth_config_same_source_circularity.md) — F1看不见同向传播的噪声;多标签macro类集必须两榜固定一致;同模型双实例≠独立标注员
- [git push exit 141=SIGPIPE:慢门晾死SSH连接,门绿但一字节没推](reference_git_push_141_sigpipe_slow_gate.md) — push后必核origin真值,禁以「门绿」推断「已推送」

- [BuyVM多机分片爬虫走HTTP触发非@Scheduled](reference_buyvm_worker_scheduling_gate_sharding.md) — 须关全局scheduling防定时任务N重跑;主+管理端口都要错开;CAS闸门+brands fail-safe
- [A族爬虫 parseDetail 返回null的语义陷阱](reference_crawler_parsedetail_null_contract.md) — 基类对null计FAILED非SKIPPED;改共享基类前须枚举全下游隐式依赖
- [HLS 段 PNG 伪装前缀剥除](reference_hls_segment_png_disguise_strip.md) — 必按PNG chunk锚IEND,纯周期扫会被同相位诱饵误命中[[feedback_goldset_must_play_real_video]]
- [段被套盗链referer致签名CDN大面积429断流→referer-agnostic host段豁免](reference_source_referer_ban_agnostic_host_exempt.md) — 换IP/UA无效,唯一判别量是referer[[reference_source_ip_ban_dual_whitelist_flaresolverr]]
- [跨机房永久边车=autossh systemd隧道+pkill -f自匹配杀自己坑](reference_autossh_sidecar_tunnel_pkill_gotcha.md) — 切边车用显式PID或pkill -x,禁pkill -f含命令行字符串
- [长视频抽等距帧必先remux成MP4再keyframe seek](reference_thumbnail_grid_seek_remux_mp4.md) — 对concat/裸TS做-ss是顺序解码慢死长片;时长必ffprobe真产物
- [源站按机房IP封→FlareSolverr双白名单必成对](reference_source_ip_ban_dual_whitelist_flaresolverr.md) — bypass与proxy口径不同,漏配proxy=该源断供+熔断静默;已第三次同源复发
- [告警规则加label正则前必验series真实存在](reference_alert_rule_series_existence_check.md) — counter常动态创建,而「零产出」恰是要监控的故障态本身→规则永不触发
- [env键归属判定 + systemd EnvironmentFile累加语义](reference_env_key_ownership_and_systemd_envfile.md) — 归属必追@Value所在模块禁凭类名;drop-in覆盖须先空赋值重置
- [Spring实例化≠代码引用](reference_spring_bean_instantiation_vs_import.md) — 给common类去@Value默认值前必查下游ComponentScan,朴素去默认值会炸6台web
- [部署jar必symlink切换不覆盖实文件(inode实证)](reference_jar_symlink_vs_inplace_overwrite.md) — cp -f原地覆盖同inode与运行中JVM mmap竞争;附迁移harness三坑
- [UDF deadRoots判死无样本门,隐式依赖REACH_FUSION_ENABLED](reference_deadroots_sample_gate_implicit_contract.md) — 关融合=立失小样本保护;REACH_HINT_ENABLED 07-10 已 live
- [前端错误上报链路怎么验才算真通](reference_frontend_monitor_report_chain_verification.md) — 三坑:__e2e cookie整体禁上报/sendBeacon是观测盲区/注入throw不进js_error主桶
- [SW生命周期+前端逃生测试铁律](reference_sw_lifecycle_escape_testing.md) — SW改动必真浏览器e2e;内存态不跨重启须IDB恢复;harness自己会骗人
- [爬虫dry-run三铁律(id撞键/mock LLM/备份漂移)](reference_crawler_dryrun_id_collision_mock_llm.md) — 隔离库AUTO_INCREMENT必设高值
- [edge nginx 如何用 reach + 覆盖率缺口](reference_edge_reach_coverage_pickp_rpc.md) — 验证必edge /__pick_stats(:81)交叉
- [前端封面占位/懒加载技术铁律](reference_frontend_image_placeholder_lessons.md) — IO root=scrollRoot
- [CA读master是正确设计非缺陷](feedback_ca_reads_master_by_design.md) — read池指.222是终态B就近读
- [Redis超时真根因+shareNativeConnection反模式](reference_redis_sharenativeconn_antipattern.md) — shareNativeConn=false勿试
- [parked jitter优化(未上线)](reference_parked_jitter_settings_read_cache.md) — patch在memory目录
- [ca-admin查Redis坑](reference_redis_cli_caadmin_proc_password.md) — 密码在/proc非secrets.env
- [actuator健康端口在:18080](reference_actuator_port_18080.md) — 主端口假200+body404
- [Dragonfly高iowait是cosmetic](reference_dragonfly_iowait_cosmetic.md) — 判真I/O用write_bytes+iostat%util
- [N9E搬ca-monitor+AWS走nw-dev](reference_n9e_ca_monitor_aws_access.md) — web节点AWS_PROFILE=nw-dev
- [N9E dashboard/alert改法+input.exec逃生口](reference_n9e_dashboard_alert_internals.md) — 真值在DB
- [CF tunnel/LB 全量拓扑](reference_cf_tunnel_lb_topology.md) — guard origin host≤10字符
- [终态CA 网络/EIP/N9E 实证](reference_terminal_ca_infra_eip_nat_n9e.md) — VPC无NAT→public IP是出站
- [克隆CA web节点SOP](reference_clone_ca_web_node_sop.md) — categraf ident/EIP配额/clone卫生三坑
- [CloakBrowser评估=暂不上留后备](reference_cloakbrowser_cf_bypass.md) — FlareSolverr顶不住再上
- [DoH/B域 apex CNAME→r2.dev=hstspreload(禁删)](reference_doh_domain_apex_cname_hstspreload.md) — load-bearing禁删
- [DoH池TXT超CF上限→np1多记录](reference_doh_txt_overlength_np1.md)
- [运行时构造资源错误live-debug法](reference_frontend_runtime_resource_error_livedebug.md) — 源码grep=0但prod在产=运行时构造
- [广告位图片渲染统一](reference_snack_adslot_render_unify.md) — image_url=裸hash经cdn
- [死代码审计 SOP](reference_deadcode_audit_sop.md) — grep必含scripts/docs/lua全引用面
- [零停机峰窗三源金标验证法](reference_zerodowntime_peak_validation_3source.md) — 三源缺一不可
- [前端部署checkout先npm ci](reference_frontend_deploy_checkout_npm_ci.md) — tee掩盖真退出码
- [部署后版本核验:CF边缘SWR裸curl读旧版假阴](reference_postdeploy_version_verify_cf_swr_stale.md) — 版本核验用浏览器no-store/直读节点文件,别裸curl
- [安全清理分支/worktree 协议](reference_safe_branch_worktree_cleanup_protocol.md) — 删ref需merged+pushed验
- [CF immutable+id复用=边缘stale陷阱](reference_cf_immutable_stale_id_reuse.md)
- [CF WAF referer 白名单 skip 多规则](reference_cf_waf_referer_skiplist.md) — 超4096字符=N skip规则
- [N9E v8 dashboard 真 schema](reference_n9e_v8_dashboard_schema.md) — 唯一权威board_payload非docs
- [LSP 工具链](reference_lsp_toolchain.md) — 4 LSP在~/.local
- [域名池 TARGET vs N_xxx](reference_domain_pool_target.md) — N_xxx下发列表需手动sync
- [分类页路由 /subjects](reference_categories_route.md) — 教育伪装
- [Apple Bot 流量识别](reference_apple_bot_traffic.md) — 17.0.0.0/8=AS714
- [CN三网国际出口路由分化:电信→EU/移动联通→CA](reference_cn_isp_international_routing_split.md) — per-node telecom=0/unicom=0 是真实路由非bug
- [Claude Code 配置目录在 ~/.claude-work/](reference_claude_config_dir.md)
- [skill 验证方法规格 v3](reference_skill_verification_redgreen_v3.md) — RED-GREEN+held-out门控
- [Newworld 项目全景](project_overview.md) — 架构/模块/部署/Sprint v3.3

## feedback(铁律,长期适用)
- [删worktree前必盘点抢救gitignored工作档](feedback_worktree_cleanup_rescue_gitignored_artifacts.md) — merged+pushed双验只保git内容;入库文档禁引用gitignored路径
- [双账户permissions必同步+allow语法坑Bash(*)无效](feedback_dual_account_permissions_sync_and_allow_syntax.md) — 全放开=裸工具名;Tool(*)在allow被静默跳过;各文件allow非并集、deny一票否决
- [Owner授权:必要时自行拉agent team + 难任务用fable 5 subagent-driven](feedback_convene_team_and_fable5_for_hard_tasks.md) — 07-21站立授权不必每次等点名;主线程仍保持薄只回收结论
- [「失败集中在X」先验分母效应:单样本源的分布=样本构成非现象特征](feedback_distribution_reflects_sample_not_phenomenon.md) — 必换构成不同的对照源;报比率不报绝对数+反问「成功的那批什么分布」
- [读SESSION-STATE必先消化档头追加,与BACKLOG交叉核对再开工](feedback_session_state_header_addendum_wins.md) — 只按正文旧节推荐会让Owner据此授权错方向;订正旧节须就地标注失效
- [worktree一律开在仓库外/home/test/worktree-<名>,禁EnterWorktree默认落点](feedback_worktree_location_outside_repo.md) — Owner 07-14指令;用path参数进手动建的worktree
- [视频源金标验证必须真点正片播放](feedback_goldset_must_play_real_video.md) — 只验封面+preview会漏正片不可播;判据用站点真实播放器videoWidth>0非自建Hls
- [Bash工具超时不杀命令只转后台→跑飞必留野进程;真开枪的只有命令自带timeout](feedback_bash_timeout_does_not_kill_stray_processes.md) — 杀进程组不够须递归杀整棵树;已机制化告警

- [拍板问题必附我的意见和理由](feedback_decisions_with_recommendation.md) — 推荐项放前面,不假装中立
- [给Owner的反馈输出要简洁明了](feedback_concise_reporting.md) — 结论+拍板点先行,细节落档不进正文,不清楚Owner会单独问
- [闸门/守卫/告警必造反例红绿双验+未知输入须fail-safe](feedback_gate_redgreen_and_failsafe_direction.md) — 守卫失效是静默的,纯读代码全看不出;★第5种=多跳链路三道守卫全挤在中间跳,最后一跳零守卫→「gate全绿」与「加载的是旧铁律」长期并存;判别法=逐跳问「谁证明生成物真重新生成过」
- [memory提交用nw-memory-commit;带尾巴必须--only划范围](feedback_memory_commit_discipline.md) — ★「写完立刻提交」已证伪(共享目录编辑窗口内照样被他会话夹带);守卫与sync两侧都必rsync -c
- [认领backlog/开分支前扫worktree+分支防多会话并行撞车](feedback_check_parallel_worktrees_before_backlog.md) — 开工前30秒git worktree list即可避免;清理别人worktree前先备份其独立产物
- [hook=特权基础设施:禁触碰主通道(改写/deny/污染stdout)+实现对齐声明契约](feedback_hooks_privileged_infra_invariants.md) — 改hook须隔离行为测试;输出异常先判通道不可信做对照实验
- [优化成本前先测真实成本结构+机制兜底判断](feedback_measure_real_cost_before_optimizing.md) — 按message.id去重看cache_read累计,别被观测工具瞄错靶;列在清单的skill≠自动触发
- [1M窗口换会话盈亏模型:看任务相关性+近40%,不看绝对%](feedback_context_switch_breakeven_1m_window.md) — 启动前缀~50K,盈亏点≈5轮;边界+(无关或近40%)才换,非一到边界就换
- [domain-health是12.45M键SCAN慢端点smoke禁连发](feedback_domain_health_scan_hammering.md) — 连发耗尽Lettuce连接池致pick-p饥饿+线程满告警
- [任何时间部署都要Owner拍板,不分峰谷](feedback_owner_approval_all_deploys.md) — 机制层=git-preflight Gate A(OWNER_DEPLOY_APPROVED=1才放行)
- [门禁运行期间禁同worktree并行maven/改源码](feedback_no_concurrent_maven_during_gates.md) — 部署jar必须无并行窗口重建
- [给存量加字段:先部署生成端再回填](feedback_deploy_generating_end_before_backfill.md) — 别用周期cleanup掩盖部署时序
- [声明式结构 > 过程式脚本](feedback_declarative_over_procedural.md)
- [前端组件按行为边界切非数据切](feedback_component_split_by_behavior_not_data.md) — FeedCard vs MovieCard
- [所有新功能走feature分支开发-测试-才合master](feedback_feature_branch_deploy_test_then_merge.md) — master永远可部署基线
- [web 模块永远第一优先](feedback_web_module_top_priority.md)
- [沟通用词:不用简称能中文就中文](feedback_communication_style.md) — 用户铁律
- [禁手写工具返回的数字](feedback_no_handwritten_numbers_from_tools.md) — 逐字复制原始输出
- [引用易变事实回原文核不凭记忆](feedback_verify_not_recall.md)
- [声明部署行为中性/flag off前必查生产DB真值](feedback_verify_live_flag_value_not_code_default.md) — 代码默认≠生产真值,灰度门常被运维翻开;ops查DB才逮住批A「中性」是错的
- [指标解读前先验证数据源](feedback_verify_metric_source.md) — grep追写入方
- [实验结论必落档防重复论证](feedback_experiment_conclusions_to_doc.md) — 含被推翻的
- [实时性≠准确性](feedback_realtime_vs_accuracy.md) — 禁有损采样
- [E2E 必须真实浏览器](feedback_e2e_real_browser.md) — 禁curl塞cookie
- [CN拨测必用aliyun真浏览器](feedback_cn_probe_aliyun_realbrowser.md) — boce垃圾
- [前端验证必须 Safari + Chrome 双引擎](feedback_qa_safari_chrome_dual_engine.md) — Owner铁律
- [前端 dev server 不可靠](feedback_frontend_deploy_devserver.md) — 必部署线上验证
- [前端部署必走 deploy-frontend.sh](feedback_frontend_deploy_standard_script.md) — 禁手跑npx vite build
- [Vue scoped CSS 不覆盖 global 同名类](feedback_vue_scoped_vs_global_css.md) — 需:deep或:global
- [部署谨慎原则](feedback_deploy_caution.md) — 前端必本地验证后再部署
- [部署前必查三项](feedback_deploy_preflight.md) — SQL migration/PageHelper LIMIT/启动链路真调用
- [部署 SSH 不混 & 和 &&](feedback_deploy_no_concurrent_chain.md) — 纯顺序部署
- [master cutover事故教训](feedback_master_cutover_incident.md) — 502/503先查DB外
- [ss断言IPv6-mapped坑](feedback_ss_ipv6_mapped_assertion.md) — ss grep漏[::ffff:IP]
- [迁移必审外部依赖三件套](feedback_migration_external_dependency_audit.md) — 本体/可达性/IP白名单
- [隔离worktree多agent跨件key格式必漂](feedback_cross_component_key_format_align.md) — canonical单函数两侧
- [worktree Bash cwd 重置](feedback_agent_bash_cwd_reset_worktree.md) — 每条cd或绝对路径
- [服务OOM-kill先dmesg实证根因](feedback_cgroup_oom_diagnosis.md) — 常MEMCG cgroup欠配
- [web高负载判CPU vs IO](feedback_web_load_io_vs_cpu_diagnosis.md) — 扩盘救不了CPU
- [categraf读配置目录所有文件禁留备份](feedback_categraf_config_dir_globs_all.md) — 备份放目录外
- [长任务防停滞SOP](feedback_long_task_no_stall_sop.md) — until-watcher+CronCreate骨干
- [后台任务每个只配一个等待机制](feedback_one_wait_mechanism_per_bg_task.md) — 别叠poller造孤儿空转"假死";退出条件必须grep真实存在的完成标志
- [secrets.env 改动必跟备份 diff 对账](feedback_secrets_env_diff_baseline.md)
- [repo nginx.conf是node-managed存死upstream](feedback_repo_nginx_conf_stale_upstream.md) — 只patch行禁整份覆盖
- [本地 admin 禁用定时任务](feedback_local_admin.md) — 连生产误触告警
- [百美金级月成本不作决策约束](feedback_cost_threshold.md) — 反脆弱优先
- [HE 同族多 IP 不 race](feedback_he_same_family_no_race.md) — 冗余必跨族
- [所有CF DNS记录TTL一律Auto](feedback_cf_dns_ttl_auto.md)
- [CF API 必先查文档](feedback_cf_api_docs.md)
- [guard.lua 白名单维护](feedback_guard_whitelist.md) — 改API路径必同步白名单
- [Lua require 链失败=进程级 500 雪崩](feedback_lua_require_chain.md) — 缺文件被缓存
- [env 命名 nginx.conf vs secrets.env 必同名](feedback_env_naming_consistency.md) — 找不到=空字符串
- [deploy-backend.sh 不做 git pull](reference_deploy_backend_no_pull.md) — 会静默build工作树
- [本地构建部署+多会话master踩坑](feedback_perf_rca_deploy_gotchas_2026_06_16.md) — -DskipTests被pom无视
- [共享master竞态:push被拒≠工作丢失](feedback_shared_master_race_push_reject.md) — 用merge-base --is-ancestor判
- [不push本地构建部署一路坑](feedback_local_build_deploy_no_push_pitfalls.md)
- [清理分支必查能力级 supersession](feedback_branch_cleanup_supersession_check.md) — 代码不在master≠未合活价值
- [多agent生产ops三铁律](feedback_multiagent_prod_ops_auth_backstop.md)
- [多agent团队必须互相沟通质疑](feedback_agent_team_crossfire.md) — Owner铁律
- [蓝军/审计 agent 方法论](feedback_audit_methodology.md) — 必守10条
- [清登记≠清实体 + 关团队SOP](feedback_registry_vs_entity_cleanup.md)
- [admin axios 响应 unwrap 双兜底](feedback_admin_axios_response_unwrap.md)
- [如何获得 P9 级表现](feedback_p9_prompting_style.md)
- [禁 headless 对别账户跑 claude CLI](feedback_no_headless_claude_cli_other_account.md) — 回写凭证=登出
- [gh CLI 未安装+本项目不走 PR 流程](feedback_no_gh_cli_no_pr_workflow.md) — 别装gh别建PR
- [共享checkout写操作前必认HEAD属主](feedback_shared_checkout_write_ops_owner_check.md) — master更新永远--ff-only
