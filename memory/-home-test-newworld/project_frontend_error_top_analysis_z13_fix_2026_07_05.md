---
name: project_frontend_error_top_analysis_z13_fix_2026_07_05
description: 前端错误TOP全类型分析(主桶被bucketInfix bug污染/ext桶埋真信号) + Z13域名上报链路0上报修复部署(分支643836d1未合master待Owner授权)
metadata: 
  node_type: memory
  type: project
  originSessionId: b2c9126a-4c80-47fb-b42f-ea5f8a09062a
---

# 前端错误TOP分析 + Z13修复 (2026-07-05)

## Z13 修复（已部署未合 master）
- **根因**：前端 cdn-failover 上报完整 CDN 子域，DomainErrorController 白名单只存裸域精确匹配 → 上线以来 100% rejected:unknown_domain，Redis/MySQL 双零。次因：web guard.lua 白名单缺 domain-error 路径（暂禁未拦，复启会二次死）。
- **修复**：分支 `fix/z13-domain-error-suffix-match`（`ec1beafa`→蓝军6条全修`643836d1`，已推远端）。resolveRegisteredDomain() label 边界剥离归约到注册域 + 尾点/小写归一；guard.lua 补路径。
- **蓝军关键抓获**：guard.lua 白名单是 **PCRE（ngx.re.find）非 Lua pattern**，`%-` 转义=字面%永不匹配（旧 redirect%-trace 两行同病已顺修）；白名单三表**现无任何调用点**（_M.check web/admin 提前 return），audit-suppressions P2-71"仍保留路径白名单"措辞已订正。/domain-health 补 category 标签（A-S 混池）。
- **部署证据**：web×6 零停机（回滚点 bak-pre-643836d1）+ openresty×6（rsync+restart+smoke 200）；线上实测子域→accepted、evil-域→拒；部署后 10 分钟 Redis domain:err:* 725 键（真实 CN 用户：内蒙古mobile/河北unicom/广东telecom）+ MySQL 采样 6 行 = 600+ 上报/10min（CN 凌晨5点）。
- **收口（Owner 07-05 授权①②③）**：①已合 master `27cc9a15` 并推远端（首次 push 被 ci-local 拦=我在门禁期间同 worktree 并行跑 admin 打包的经典污染，铁律再犯实锤；干净重跑全绿）；②ca-admin 已部署（jar 20260705-051832-27cc9a15，journalctl 0 ERROR + actuator 200 + jar 含 categoryByName）；③前端错误TOP治理已立项 docs/sprint/2026-07-05-frontend-error-top-cleanup/PLAN.md（P0 分桶bug/P1 XHR签名+版本检查503/P2 资源分桶）。

## 前端错误TOP分析核心发现（管理后台 MonitorErrors 页）
- **[P0 候选未修] MonitorService bucketInfix bug**：`net_echo`/`script_error_noise` 分支传 `"ext"`，bucketInfix() 只认 `"extension"`→fallthrough 主桶。主桶 TOP 被 7058 条 Script error 噪音+3937 条网络回声霸榜，真 js_error（8条/35min）被淹没；且噪音吃掉 TOP_KEY_BUDGET=200 基数预算。修法一行：改传 "extension"（或映射加 "ext"）。
- **ext 桶埋着真信号**（console_warn 全进 ext 不告警的设计副作用）：`[AppConfig] 版本检查失败: 503` ×1259/35min（GET /api/v1/settings/version 5xx，待查）+ `[NW-INIT] hard timeout` ×446 + `[NW-LAZY] pwa-install failed`（动态 import null 解构真 bug）×151。
- console_error 主桶 991/1035 = 第三方 WebView XHR 钩子读加密 API arraybuffer 的 responseText 报错（非我方代码，grep 0），污染 jsErrors KPI 65%——应加 THIRD_PARTY_SCRAPER_SIGS 签名。
- resource_error 12676/35min：百度 hm.js×3 站点 ID 1760+（广告拦截器，预期噪音）+ 自家 A 域资产失败（真 GFW 信号，Z13 修复后有正规通道）。
- 播放错误表 playback_error_log：99.98% network（前端只发这一类型，media/timeout 从未上报）；retry_count=49=轮完 50 域名全灭（建议封顶 8-10）；region=other 89% 是 06-30 前坏 IP 库失真。
- 分析窗口注意：Redis slot 是 HK 时间，30min TTL 只有 ~7 个主桶槽位可聚。

## 后续工作执行（07-06 凌晨，Owner"启动后续工作"+授权--force-peak）
- **P0-1/P1-1 已部署验证**：分支 fix/frontend-error-top-p0p1（6344e255+蓝军6条983187ae+合基线4492d8d3，**已合master`97669939`并推远端(ci-local全绿)**——注:按Gate 4设计连带把线上基线c5a0423a(别会话渠道统计分支)一起带进master）。web后端×6+前端×6部署；验证=主桶Top1 460/槽→15/槽只剩resource_error+ext桶249>200独立预算生效+jar真身True。
- **又逮两个潜伏bug**：third_party_scraper_noise后端无case被unknown静默丢弃（违背前端"保留数据"注释）；"ext"调用点实为5处非2处。
- **P1-2定位完成**：源站238MB日志503=0+六节点隧道24h仅8条相关 → 503产生于CF边缘/LB层；54k隧道EOF=bot路径444反侦察预期噪音（favicon/sitemap/robots）。CF侧取证待nw-cf修复（今晚取密链路故障）。
- **踩坑复盘**：deploy-web.sh峰窗门要--force-peak命令行参数（FORCE_PEAK=1环境变量是deploy-frontend/peak-guard.sh的口径，两脚本不一致）；Gate 4拦对了一次（线上基线c5a0423a=渠道统计分支未合master，merge后重测再部署）；EU重启窗口stats-async队列drain撞Lettuce已停=865条ERROR集中1秒，已知模式非事故。
- 剩余：P2-1 pwa-install/P2-2资源分桶/P3全项未动。
- **P2/P3批全收口（07-06 01:10）**：合master`f87b53dc`(Owner拍板搭便车部署,未单独部署)。P2-1 null守卫×3(带诊断信号)/P2-2自家域分桶全链路(分桶+own计数器+gauge nw_monitor_resource_errors_own_5m+看板卡)/P3-1良性策略拒绝分流browser_policy_benign双端/P3-2 msgKey归一(去query/去UA)/P3-3 plyr签名补onerror/P3-4 admin补console_error+csp_violation(CSP按钮此前静默失效=潜伏bug)。蓝军6条全修(★"写了没人读"=虚假完成度挑刺最狠——新计数器必须连到消费端才算完成)。分支已删。待办=搭便车部署后gauge验证+N9E规则+cf-ray取证埋点+CF Web Analytics评估。
- **P1-2最终假说**：CF LB层也洗清(24h仅2条健康事件)→503最强假说=用户侧中间盒(GFW/运营商)伪造响应；决定性取证=前端读cf-ray头(有=CF产生/无=中间盒)。nw-cf故障根因=直连生产内网mysql本机不可达。
- **收尾批（07-06 凌晨，Owner"都做掉"）合master`6689fcd6`**：cf-ray取证埋点(版本检查失败带ray=yes/none)/playback三项(①video.error.code+hls details细分network·media·timeout ②蓝军#2修订=软反馈SOFT_FEEDBACK_AT=8 toast+后台轮至全池, 弃硬截断防同族相关故障误伤 ③后端errorType白名单+PlaybackErrorServiceTest)/nw-cf走nw-mysql ssh取token(Owner拍板, 实测通, README+CLAUDE.md同步)/CF WebAnalytics评估=关闭须Owner在CF面板操作(API token无RUM权限, 证据evidence/cf-webanalytics-authcheck.txt)。蓝军5条全修(★挑刺=封顶8隐含故障独立性假设与he-same-family教训矛盾)。分支已删。
- **四线错峰部署已挂定时**（03:00 HKT自动: web×6→fe-web×6→ca-admin→fe-admin, 日志scratchpad/deploy-all-0300.log, worktree masterwt4=6689fcd6）。部署后验证: gauge出数/journalctl/错误类型细分出现。