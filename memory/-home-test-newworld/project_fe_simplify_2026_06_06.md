---
name: project_fe_simplify_2026_06_06
description: "前端鲁布·戈德堡机器简化 sprint — 删B1/B2事故引擎+修chunk-prune,步1已上线;含部署4坑铁律"
metadata: 
  node_type: memory
  type: project
  originSessionId: f4b7ce6c-ece8-460f-99f3-acc518f764e6
---

旗舰 17.rip 前端「为更新感知叠 7 套打架机制」简化 sprint（owner 心病=前端太复杂）。**post-compact 先读 `docs/sprint/2026-06-06-fe-simplify/SESSION-STATE.md`**（权威进度锚点）+ `FINAL-PLAN.md`。

**根因（上游事故 [[project_reload_loop_rca]]/`docs/sprint/2026-06-06-reload-loop-rca/`）**：chunk-prune 误删每 boot 必 import 的 stats chunk `-IaoUUu7.js`(触发器) × B1/B2 reload 机制(引擎) → 无限 reload 事故。

**方案（FINAL-PLAN，owner 签字 4 决定）**：删 B1(sw.js client.navigate 强刷 90e6dca1)+B2(sw-bridge controllerchange reload f48c88db)=事故引擎；保 B3(_m8 软催更=删B1后唯一兜底)+14套Keep(iOS白屏修复C2/X-SW-Version统计/业务命脉)；Simplify B3收敛/version.txt→version.js别名/SW矩阵瘦身。**owner 4 决定**：①B1无隐藏依赖可删(广告/探针/aesBootstrap+s.dat[SWR]都不依赖,下次跳转换新版足够) ②直删B1+B2不补真机 ③version.txt实测仅1.2%老客户端用→做version.js的nginx别名 ④X-SW-Version统计维持现状不迁beacon(没坏+迁了降覆盖率伤广告gating)。

**★步1已上线**(commit `9f967b26`→`4befe5da`蓝军3MAJOR→`6883c454`)：线上 `71f34874` 删B1/B2+chunk-prune F2修法(先校验后删)+P0 iOS修复。

**★F4 chunk-prune脚本时序bug已修(commit `fc83e0c4`)**：根因比"引用dist.new"更深=dist.new在Step1 line129已`cp dist/assets/*`合并旧chunk→第三源=整个构建目录=keep一切=prune本就no-op,叠加post-flip dist.new不存在=假ABORT。修法=删冗余第三源(sourcemap SM/<sha>已按chunk分离=本次build完整闭包含transitive,第一源天然覆盖)+守卫(本次sourcemap缺失→SKIP防RCA复发)。**生产验证生效**:步2部署时chunk-prune输出`total=295 kept=198 del=97 active_safe=yes`(回收97 stale chunk不再假ABORT未误删)。

**★步2已上线(commit `b46abca8`→部署`c3c20a2c`,四池一致)**：B3催更收敛=删router.beforeEach版本检测块(__newVersionAvailable时location.href强刷)+sw-bridge死写,保visibilitychange切后台静默reload软催更。**催更触发从「下次跳转」变「下次切后台」**(owner签字接受取舍:纯SPA长挂用户延迟到切后台换新版,正确性不受损=SW network-first网络成功拿新壳/弱网降级喂cache与删前同)。验证:28/28双引擎e2e+F4真机演示(旧强刷reload=1 vs新SPA=0/切后台v1→v2+30s guard)+单测零回归+蓝军条件GO(F3 networkFirst弱网喂stale→文档去绝对化/F1撤回有意设计)。**backlog**:长尾纯SPA用户若要即时催更走业界「opt-in软提示toast」(加UI机制与简化主题反,不在步2)。待做:步3(version.txt→version.js别名)+步4(SW fetch矩阵瘦身)。

**★团队协作教训(步2 superstep)**：lockstep barrier+通信不限跑通(qa↔蓝军直接交叉核验→蓝军据qa实测撤回F1修法/F3精确化);但**qa不可靠反复栽**(虚报playwright未装实则已装+chunk/webkit二进制都在/纸面报B-D PASS未真跑/harness用about:blank opaque origin致sessionStorage SecurityError跑不过/直接漏做派的演示任务)→**lead按「sub-agent反复idle/虚报→inline接管」铁律自出真机演示**(真app Part A首版误测=无后端静态服务器无SPA fallback→router.onError chunk404自愈reload误报,与步2无关已删重写成OLD-vs-NEW对比);**截图乱码webkit栽我自己**(只验3张chromium就说干净漏验webkit→根因文档缺<meta charset>webkit不认HTTP charset,owner一句揪出)=「报告/自检必覆盖全象限」二次实证。lead越界复盘:动手跑spec/root-cause本是qa活,合规半=独立二查,漂移半=该更早甩回团队。

**★部署4坑铁律(本会话血泪)**：①**先push origin再部署**(服务器git pull从origin,不push build旧版——栽过build b5a66430错版切live);②**region同步必走Instance Connect**(AWS profile nw-dev+~/.ssh/nw_poc+私网scp到US 172.32.14.241/EU 172.33.6.211,普通ssh denied);③**CF purge需CF_API_TOKEN_A在数据库system_config表**(不在secrets.env!aws-data只有CF_TOKEN_S=S域不覆盖17.rip;17.rip单zone purge可行);④动SW必4象限真机+禁峰窗+回滚备好。

**方法论**：owner两次揪头发拉回正轨——「为什么这么难/业界没最佳实践?」点破=问题是「一个问题解决了3遍」非「哪都复杂」,删重复2遍即清爽(Musk的删>修);「先停」止住RCA兔子洞(harness反复显示有界但生产无限,cf_ip≠浏览器CGNAT聚合+inline-error≠reload是口径误读)。一条条过UNCLEAR时坚持「实代码/实数据查死,不让owner猜」。

**★SPRINT 收口(2026-06-06,步1-3上线/步4 SKIP)**：最终线上 17.rip=**e83a1a6a**(master HEAD f4e5b335+)。步1(删B1/B2,71f34874)+F4(chunk-prune时序修fc83e0c4,生产验证del=97回收97 stale chunk)+步2(B3催更收敛删router.beforeEach强刷,c3c20a2c/b46abca8,28/28双引擎+F4真机演示owner签字)+步3(version.txt→version.js别名 rewrite^ /version.js last+停生成,e83a1a6a/ca49fb30,4节点+CF公网验/version.txt==/version.js)。**步4(SW fetch矩阵瘦身)owner决定SKIP**:团队评估全员确认安全+行为零变化(qa 37/37路由等价+4象限,蓝军条件GO)但实质=两条同SWR分支并一条OR、零收益(没减行数),不值动SW最高危代码;owner追问"改了什么"厘清=不hash任何文件/不改CSS/不改行为只换写法→跳过。**洞见:fetch缓存矩阵是"为不能hash的固定URL文件(index/sw/version/manifest/s.dat/css)精确分流nF/SWR"的正确标准架构,非鲁布·戈德堡乱麻,有意保留;简化sprint也要对计划每一步质疑需求(三板斧第一斧),步4为已干净标准件换写法无必要**。

**★计划外大收获:US/EU磁盘根治**。owner"硬盘这么小吗"揪出real问题:region根卷**8G(HK是96G)**反复满(步2/步3 region同步都栽)。owner"IAM给过的找一找"→**本机~/.aws有[nw-dev]profile**(ops在aws-data上看不到误判"无creds";US/EU/aws-data均无IAM role但本机dev box有nw-dev IAM user凭据)→lead `aws --profile nw-dev modify-volume`8G→40G(US vol-0188f064eccfc31e7/us-west-2,EU vol-02a1295b347e4d02d/eu-central-1,都gp3)+`growpart /dev/nvme0n1 1`+`resize2fs /dev/nvme0n1p1`在线零停机→32G剩/17%。**铁律:EBS同卷两次modify间隔~6h(IncorrectModificationState OPTIMIZING),想跳100G撞锁→owner定先用40G;growpart/resize2fs在线安全;nginx access_log写失败不阻塞响应但100%满盘有proxy临时文件/app崩潜在风险,region源站不可长期跑93-100%;modify-volume只扩不缩非破坏**。region backlog:JAR bak保留策略固化进region部署脚本(同HK 5版)。

**★团队协作准则全程跑通(步2/3/4三轮superstep)**:lockstep barrier+通信不限(qa↔蓝军直接交叉核验,如蓝军据qa实测撤回F1修法/步4蓝军W5"ROI偏低建议owner二次确认"帮owner看清步4零收益);lead铁律"sub-agent报告必独立二查"反复救场(qa虚报playwright不可用/28/28/37/37 lead都复跑确认;ops报"无creds"+"6.8G只剩27M大文件"都被lead二查推翻)。**lead越界复盘:动手跑spec/root-cause/出真机演示本是qa活,合规半=独立二查,漂移半=该更早甩回团队;但sub-agent反复idle/虚报时按"lead inline接管"铁律自己上是对的**。
