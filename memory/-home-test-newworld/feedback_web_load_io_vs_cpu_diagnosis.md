---
name: feedback_web_load_io_vs_cpu_diagnosis
description: web 节点高负载先判 CPU vs IO:iowait≤1.3%即非IO;io_util峰可能是自己的gzip artifact;日志写~500KB/s非瓶颈
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9532d6aa-c746-4dc8-9e64-aaed3bb1448b
---

2026-06-15 spectrumdigest.study P 域推广脉冲 ~6000 req/s 打满 5 台 web。owner 一度怀疑"IO 高/日志写太频繁",实测推翻:

**判据**:web 节点高 load 先分 CPU vs IO——
- `cpu_usage_iowait` 峰 ≤1.3%(全 1h) + `disk %util` 稳态 0-1.8% → **盘从未拖后腿,瓶颈 100% 是 CPU**(`cpu_usage_active`/100-idle 峰 99.9%)。iowait 才是判 IO 真伪的权威信号,光看 `diskio_io_util` 会被骗。
- N9E `diskio_io_util` 1h 峰看到 47-59% 一度像"IO 高",**真相是我自己 logrotate 触发的 20GB 历史日志 gzip 压缩 artifact**(一次性),不是稳态。改运维操作(大压缩/大拷贝)会在监控留 io_util 尖峰,排查时先排除自己的动作。
- 日志写入实测 ~500KB/s = gp3 带宽(125MB/s)的 0.4% → "日志写太频繁"前提不成立。

**Why**:扩盘 size / 调 IOPS 都救不了 CPU 打满;方向必须从"防 IO"切到"削 CPU"(削请求量/扩 CPU 池)。和 [[reference_dragonfly_iowait_cosmetic]] 同源教训:io 类指标(iowait/io_util)在多种场景虚高,判真 I/O 要交叉(iowait + 字节级 write_bytes + 自己的操作)。

**How to apply**:① 高 load 先 `top` 看 us+sy+si vs wa,wa≈0 即 CPU 问题;② 看 N9E 1h 历史峰值不要只看 instant;③ io_util 尖峰先问"是不是我刚跑的压缩/拷贝";④ 别用扩盘/调 IOPS 应对 CPU 瓶颈。

**logrotate 配套坑**:web.log 涨到 20G 根因=logrotate.timer 每天只跑一次,`maxsize 200M` 一天才检查一次→突发下两次检查间撑爆。修=cron 每15min 跑 + 去 delaycompress + nice/ionice 压缩防抢用户 CPU(commit/config 见 docs/sprint/2026-06-15-beacon-cost-reduction)。
