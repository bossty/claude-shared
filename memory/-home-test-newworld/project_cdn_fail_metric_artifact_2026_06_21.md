---
name: project_cdn_fail_metric_artifact_2026_06_21
description: cdn-fail 告警 95-98% 是结构性指标假象(成功静默无分母)非域名被烧;boce实证SNI没烧→别买域;修在feature/cdn-fail-metric-denominator(纯前端);含F3双计数bug
metadata: 
  node_type: memory
  type: project
  originSessionId: 85dc3fe1-5403-474d-941b-c0f0f36ee859
---

**告警 `stats-v7-redirect-trace-cdn-fail`(N9E rule 42)长期 95-98% = 结构性指标假象,不是真有 95% 广告图加载失败,更不是 snack 域被 GFW SNI-burn。** 这**反转**了 [[project_snack_cdn_pool_rotation_2026_06_21]] 的买域前提。

**根因**:`traceCdn` 全前端只调一次且只发 `'fail'`(`cdn-failover.js:214` reportFailure 内),**图片/视频 CDN 加载成功时不发任何 trace**。rule 42 live 查询(N9E `rule_config` JSON 实证,非 SQL 文件)= `sum(rate(redirect_trace_total{level="cdn",outcome="fail"}[5m]))/sum(rate(redirect_trace_total{level="cdn"}[5m]))>0.10` → 分母=全 cdn trace≈fail(成功静默)→ **比率结构性恒 ~98%,CDN 再健康也降不下来,告警永响**。prod counter:cdn fail=722993/ok=14502(遗留默认 outcome 残留,okByLevel 对 cdn 恒 0)。同本会话 tomcat-reset/vitals/retention 一个套路(失败计数无成功分母)。

**域名没被烧(别买域)**:阿里云拨测 `boce.aliyun.com/detect/http`(playwright 驱动;itdog 6/21 大面积故障)对 5 个 R_SNACK apex(ux1a.{assetlibs/imgedustock/node-sync/previewedu/stream-lesson}/snack/static/snack05/dcd24532.js)各 200+ CN 节点拨测:每 apex 100+ 节点 HTTP 200+真图、延迟多数<2s、DNS 污染<2%、TLS 全握手(SNI 被烧 IDC 也 RST)。**坑**:boce 下载有 **64KB cap**(图 94KB)→ 所有节点显示精确 64.00KB 不是截断,证不了完整下载。DNS 也没污染(CN 解析器 114/223.5.5.5 返正确 CF IP)。CF 对浏览器 `content-encoding:br` 压缩了不可压的加密图(纯开销,但压缩响应无 Content-Length→截断检测跳过非误判源)。CORS 反射正常(A/P 域 origin 都回 ACAO)。cdn fail 的 from_root 近1h top20 全 snack/图片域零视频(refute 视频主导)。

**蓝军复核 + lead 二查**(`docs/sprint/2026-06-21-cdn-fail-metric-rca/agents/reviewer.md` + DESIGN §2):核心结论成立。额外揪 **F3 双计数真 bug(BLOCKER)**:`encrypted-image.js _doLoad` 首次失败+重试再失败=2 次 reportFailure→fail counter 翻倍+双重轮转。

**修复**(分支 `feature/cdn-fail-metric-denominator`,commit d6031964,已 push,**未部署未合 master**):**纯前端,后端/N9E rule 不用改**(beacon controller `record`/`compensateOk` 早支持 cdn ok,只是前端从没发)。① `encrypted-image.js` 成功加载→`traceCdn('ok',{type:'snack'})` 给 rule 42 真实分母(缓存命中不发口径干净;走 enqueueOk 采样+okByLevel 补偿不爆 beacon)② F3 修:`_reportFailureOnce`+`_reportedRef` 跨首次+重试共享,每链路最多上报一次(**用 ref 非 _retried 守卫**——保 decrypt 失败→重试才首次 fetch 失败仍正常上报一次)③ `cdn-failover.js` reportFailure 的 traceCdn('fail') 带 type 流到表供离线 breakdown。测试+4,encrypted-image 11/11、全 frontend 825/825 绿。video/images 的 ok 埋点留后续(本 PR 只 snack)。

**★已部署(2026-06-21,feature 分支本地构建,Owner 定"测试通过后再合 master")**:后端 6 web 节点(commit 4c050b57)+ 前端 6 节点(deploy-frontend.sh,version dcf4b9fc)。**顺序铁律:后端先(跳 cdn-ok 落库)→ 前端后(开始发 ok),否则旧后端把新 ok 全落库爆表**。**live 验证两效果都生效**:① ca-web-01 重启后 ~10min cdn ok=7181/fail=6314→rate 98%→47%(还在降,old client 不发 ok 随铺开继续掉)② redirect_trace 表部署后 cdn level 只进 fail 零 ok 行(写放大挡住)。EU 部署报错是重启窗口 SnackService.recordEventsAsync 瞬态(近30s归0+CA同jar零错=非回归)。

**部署前自查抓到的真坑(蓝军没抓)**:beacon batch 每条 trace streamWriter 落 redirect_trace 表(已17.5M行),snack 成功~10^7/天即使0.3采样也每天数百万写主库爆表+挤掉 fail。修=后端 `shouldPersist(level,outcome)` cdn+ok 跳 streamWriter(counter 经 record/compensateOk 仍准)。**所以本修是前端+后端都要(我一度误判纯前端)**。

**web 节点部署模型(终态 CA,同 [[reference_ca_admin_deploy_model_2026_06_21]])**:SSH=ubuntu 免密 sudo、jar 在 `/opt/newworld/newworld-web.jar`(非 deploys symlink,runbook Step2 对这些节点 STALE)、部署=本地 build→scp /tmp→备份→sudo cp /opt→restart;**INTERNAL_API_SECRET 不在 secrets.env 文件而在进程 environ**(/proc/PID/environ 取);值=`nw-internal-2026-Kx9mZ!pQ`(25字符,本就在 runbook skill 明文)。deploy-frontend.sh 已 Owner 决策内置该 secret 默认值(commit 57b34539,单人开发省捞,内网端点泄露调不通)。

**★已合 master + 删分支(2026-06-21,观察30min健康后)**:fast-forward 合 master(HEAD 57b34539,3 commit),feature 分支本地+远程已删。观察期 rate 98%→47%→**9-11% 稳定**(各节点 9.0-11.3%,假象消失=真实率),CA 全零错、表持续零 ok 行;EU 报 SnackService 记录snack曝光失败(部署前52次=pre-existing 与本改无关,CA同jar零错确认非回归,snack曝光≠redirect_trace)→不阻塞合并(合并只 git 不改运行时)。

**待办/follow-up**:① rate 稳态 ~9-11% **正卡在 rule 42 阈值 10% 上下会 flap**——真实率,owner 可重标阈值(>10%→比如>20%)或先观察;若稳态仍偏高是真信号但**非域名烧**(boce证可达),可能跨洋下载完成度/CF压缩,与买域无关 ② video/images 的 ok 埋点留后续(本 PR 只 snack 主路径)③ EU snack曝光写失败是独立 pre-existing 问题待单独查。**轮换/连买带轮换能力(上 sprint 已部署)留以后域真被烧时用。**
