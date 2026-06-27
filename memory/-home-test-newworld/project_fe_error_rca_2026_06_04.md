---
name: project_fe_error_rca_2026_06_04
description: fe-error-rca sprint — 首页批量API失败/503 真因=00:00 Redis超时风暴(缓存层)，B-RC1 两类缺陷分治后端修复已上线 error.log upstream timeout=0
metadata: 
  node_type: memory
  type: project
  originSessionId: e6967cbf-7c21-4771-b2da-ac57f2b6885c
---

2026-06-04 fe-error-rca sprint（我=infra/后端 RCA）。前端错误监控数千条「首页批量 API 失败 Load failed/Failed to fetch/503/AbortError」定性 + 后端修复。SOT=`docs/sprint/2026-06-04-fe-error-rca/infra-findings.md`。

**B 类真因（infra，已自愈+已治本）**：00:00–00:05 HKT 一次 ~5min origin 故障——`Redis command timed out`(Dragonfly 缓存层) → web 请求线程阻塞(spring.data.redis.timeout=5000ms × Tomcat max-threads=800 秒级耗尽) → OpenResty「upstream timed out while connecting」~30000 条(两 web 节点都中) → 用户 5xx。证据：web app log `记录 snack 曝光失败`7241条+`Redis command timed out`708条全集中 00:00-04，error.log 三个 52MB 00:04 轮转；自愈(00:05 后零 ERROR)；JVM 无重启。瓶颈在**缓存层非 MySQL/CF/tunnel**(同 [[project_peak_perf_debate_2026_05_29]] + [[reference_lettuce_pipeline_command_timeout]])。

**B-RC1 修复 commit `265285f7`(master, mvn 640 pass, 蓝军签字, 已滚动部署, 线上 error.log upstream timeout=0)**——两类缺陷分治(本 sprint 最高价值定位)：
- **类②(真 5xx 源)**：MovieService 7 首页 READ 的 Redis 读**未 try-catch**，DB fallback 只在「Redis 返 null」走、**抛超时直接冒泡 GlobalExceptionHandler→503**。修=Redis 读包 try-catch fall-through 到既有 DB fallback / 个性化降级 getDiverse/getRelatedById。
- **类①(线程耗尽源)**：snack 曝光/点击 Redis 写**已 try-catch 吞但同步跑请求线程**，5s 超时前干等吃满线程池(SnackController 循环 N event×5s 最毒)。修=新 statsAsyncExecutor(core2/max8/queue5w/DiscardOldest 可丢统计不回退)+SnackService.recordEventsAsync @Async+`new ArrayList<>(events)`副本。
- **A 类配套**：MonitorService 加 `script_error_noise` type→`monitor:script-error-noise:{slot}`独立桶不计 js-errors。
- **FIND-4(前端)**：api-fails/api-total=0 因前端从未发 `api_error/api_success`(只 console_error)，后端桶(:341-345)空转+API失败污染 js-errors KPI；归 fe-rca 改 fetch.js。

**铁律级教训**：
1. **MyBatis mapper「缺 LIMIT」可能是有意设计非缺陷**：findMoviesByCategoryId/TagId 无字面 LIMIT 是 5/26 hotfix **专门删的**(MovieMapper.xml:37/:60 注释「与 PageHelper 追加 LIMIT 冲突双 LIMIT 语法错」)，靠 PageHelper.startPage 紧贴调用追加 LIMIT。我和蓝军都一度想「补 LIMIT」推反了——**发现「缺 X」先 grep 是不是被人专门删过(删除即设计意图)**，加回去=重引已修语法错 bug。覆盖索引(消 filesort)才是 fallback 真隐患(backlog 待 owner)。
2. **claim「已实现/intact」前必 `git diff` 实证**(verification-before-completion)：中途差点上报 fix② intact，git diff 揭示工作树残留 staged LIMIT 版本才发现，清后才 commit。
3. **多 agent 共享工作树 + git stash = 混乱**：我的 commit 一度被 fe-rca 的 stash 卷走；恢复后 team-lead 描述的「dead limit param」其实是 stash 备份旧态非 live tree——**对方描述与实测矛盾时先 git/grep 实证再动手，别盲改**。
4. **诊断**：service active≠业务健康(5min 故障无人发现，同 [[feedback_secrets_env_diff_baseline]])；N9E 应加 web `Redis command timed out`+OpenResty upstream connect timeout 告警(backlog)。

---

## 前端侧 + lead 仲裁 + ops（main session 补全，2026-06-04 收官）

**数据源复用法**：生产前端错误数据在 Dragonfly `172.31.19.174:6379`(aws-db-poc 无 redis-cli)。从 **aws-web-01 用 redis-cli**，密码 `REDISCLI_AUTH=$(sudo tr '\0' '\n' </proc/$(pgrep -f newworld-web|head -1)/environ|grep ^REDIS_PASSWORD=|cut -d= -f2-)`（**变量名 REDIS_PASSWORD 非 REDIS_PWD**）。schema 见 docs/FRONTEND_MONITOR.md。

**前端 5 类修复 commit `65fff601`(npm 598 pass+QA 四象限全绿+已部署)**：
- **A `Script error.`空source(2.8万)= 第三方/iOS应用内WebView注入噪音，非缺crossorigin**(三域 curl 证主bundle已带crossorigin+CORS、bundle反查全站1处throw、QA WebKit headless 0复现)。修=monitor.js `source==''&&msg==='Script error.'`→`script_error_noise`(后端独立桶)。线上验证 script-error-noise 桶 4076 出现、js-errors 槽降至 344(噪音已剥离 KPI 回归)。
- **FIND-4 api-fails/api-total=0=埋点从未接通**：修=`fetchWithTimestamp`(utils/fetch.js,**唯一请求入口,全仓库无axios**)成功/失败 enqueue api_success/api_error。线上验证 api-total=6561/api-fails=1333(真实API失败率~20%首次可见)。
- **B-1566 unhandled_rejection**：cdn-failover.js `.finally()` 缺 catch→`.finally().catch()`(catch后置)。QA before=1/after=0。
- **B-RC2** loadFullConfig 失败日志 console.error→warn。
- **C `No TXT records`(641)**：QA 三轮 WebKit/Chromium **证伪 Promise.any 晚 reject 假设**(泄漏=0)，确切触发路径**未复现确认**；修=防御性封闭所有 DoH 路径(per-query .catch+fetchApiDomainsViaDoh try/catch+sw-bridge .catch)，**诚实标注根因未复现+部署后监控 641 桶**(不谎称已锁)。

**lead 仲裁/process 教训（durable）**：
- **lead 读实代码 override 团队错误共识**：蓝军 4 轮反复+infra 都想给 findMoviesByCategoryId/TagId「补 LIMIT」，lead 据 MovieMapper.xml:60 注释+MovieService:503-504(PageHelper.startPage 紧贴)裁定**绝不加**(双 LIMIT 语法错重引 5/26 bug)。诊断冲突 lead 查实代码仲裁不选边(multi-agent-coord 铁律)。
- **多 agent 必各开隔离 git worktree**(newworld-using-git-worktrees)：本次共享工作树+一人 git stash→卷走全员改动+stash pop 被 hook 拦死。零丢失恢复=`git stash show -p >backup.patch`+`git checkout stash@{0} -- <file>`。
- **hook 相对路径 `.claude/scripts/X.py` 是 bash-lock 雷**：shell cwd 漂到子目录(我 cd 子目录未回退)→hook 找不到脚本→全 bash 被拦(多 agent 连环中招)。修=settings.json hook command 改 `$CLAUDE_PROJECT_DIR/...` 绝对路径(commit 3aa7b4dd)；bash 命令保持 cwd 仓库根。
- **部署前必 fact-check off-peak 假设**：raw-samples 时间戳≈04-05 HKT 被误判 off-peak，实测仍≈40 PV/秒(站点凌晨重流量)，向 owner 更正后再确认；滚动部署(web 逐台+OpenResty proxy_next_upstream 故障转移)在此流量安全。
- **owner 红线全程贯彻**：「stale 测试」声明 lead 用 HEAD 对照独立复验(4 失败确为 pre-existing)；部署声明 lead 独立复验线上桶生效；不轻信 sub-agent 自报。
