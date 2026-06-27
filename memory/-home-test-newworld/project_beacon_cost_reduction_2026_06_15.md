---
name: project_beacon_cost_reduction_2026_06_15
description: beacon 降本
metadata: 
  node_type: memory
  type: project
  originSessionId: 9532d6aa-c746-4dc8-9e64-aaed3bb1448b
---

**2026-06-15 起因**:`spectrumdigest.study` P 落地域**每日定时推广脉冲**(两天均 ~23:38 HKT 爆发,峰 ~78k req/min/节点≈6000 req/s 全队列),91% CN 真实流量(cf_country CN),打满 3 台 CA web CPU(load_norm 峰 20.98 后降;EU 不受影响)。N9E 1h 实证瓶颈=CPU(99.9%)非 IO(iowait≤1.3%)。头部流量是埋点 beacon(每 PV 多 beacon 放大)。

**先做的止血**(已闭环):①5 台 web logrotate 修复(daily timer 太慢→cron 15min+去 delaycompress+nice/ionice;web.log 20G→364M)②5 台 EBS root 48/50G→100G 在线扩容。

**#2 beacon 降本(已上线 commit e66f3c53)**:
- 抓手 A redirect-trace:ok 批量+采样/fail 即时全留/okByLevel 按 level 计数还原(owner 选 c);RedirectTraceMetrics SLO bucket 改造(防重蹈 [[project_rum_cardinality_fix_2026_06_14]] categraf OOM);batch 端点 MAX_BATCH=20+body 64k。
- 抓手 B inline-error:**真凶是 index.html:160 内联 reportInline 非 aes.js**,内联 Map 1s 节流去重。
- 抓手 C telemetry:**降级为 system_config 静态键**(TELEMETRY_SAMPLE_RATE/ADAPTIVE_ENABLED,默认 1.0/false=全量关),推广前人工改 0.3+递增 systemVersion(12min 生效);动态 CPU 感知否决(12min 轮询延迟在脉冲内失效+多实例 CPU 不一致+过度设计)。
- **snack:精确批量非采样**(owner 二次澄清"非实时≠非准确",撤采样)→ flush 2s→15s+pagehide+sendBeacon keepalive,+1 精确零丢失;见 [[feedback_realtime_vs_accuracy]]。KPI(hit PV/session UV)硬编码 KPI_NEVER_SAMPLE 不读采样率。
- **降幅实测(非乐观估):常态 -12~15% / 脉冲态 -18~22%**;PLAN v1 的 -40~50% 已纠正(可削表面仅 redirect-trace+inline,KPI/计费动不了)。**#2=CPU 边际缓解+卫生,非脉冲主力解**。

**方法论**:3 轮蓝军(设计 28+Phase3 7+snack 6)+ lead 实代码仲裁(证伪 2 误报=reviewer 看错 worktree;真 bug 全修)+ qa 四象限 40/40(playwright route 拦截验 beacon 时序)+ 合并后全量集成闸门(后端 809/前端 741 绿)。dev/qa/reviewer 全程隔离 worktree。

**CA 扩容 ca-web-04(2026-06-16 完成)**:AMI 克隆 ca-web-01 加第 4 台(i-0659eeb154ad36064,内网 172.34.1.169,动态 public 18.145.102.138)。分流真生效铁证:其余 3 台 load 应声降(01 10.6→5.3/03 10.9→3.3),ca-web-04 接 5.08;cloudflared token 型自动接入(ha_conn=4 三 tunnel,CF 零改动)。详见 [[reference_clone_ca_web_node_sop]]。

**采样激活(2026-06-16 已开,owner 拍)**:`TELEMETRY_ADAPTIVE_ENABLED=true`/`SAMPLE_RATE=0.3`,6 节点 /settings 实测 diagSampleRate=0.3。激活三件套=改 master DB + `PUBLISH shared:ch:sysconfig-refresh <key>`(失效 web valueCache,8 订阅者)+ `INCR shared:system-version`(前端 /settings/version 重拉)。回滚=改回 false/1.0 + 同样 PUBLISH+INCR。⚠️redis ops 坑:①Dragonfly 要 auth,web 侧密码在 `/proc/<web-pid>/environ`(EnvironmentFile,非 systemctl show Environment)需 sudo cat;redis 主机侧密码在 dragonfly systemd `--requirepass`。②redis 主机=**Amazon Linux 2023**(非 Ubuntu,无 apt,用 dnf),自带 **`redis6-cli`**(已软链为标准 `redis-cli`);web 节点(Ubuntu)redis-cli 走 apt 装(已装 ca-web-01)。教训:apt 失败先看真实报错(`command not found`=非 Debian 系)别猜出口。

**待办(owner-gated)**:①~~开采样~~(✅ 已开 0.3)②~~CA 扩容~~(✅ ca-web-04 已加)③MySQL QPS 专项(readOnly 补标+vid_metadata 缓冲)(#2 不挂钩,readOnly 补标+vid_metadata 缓冲,见 [[feedback_web_load_io_vs_cpu_diagnosis]] 末)④S2 告警加 for:5m 降噪(可预期脉冲)。
