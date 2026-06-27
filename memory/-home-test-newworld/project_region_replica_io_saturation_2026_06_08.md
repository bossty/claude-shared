---
name: project-region-replica-io-saturation-2026-06-08
description: region DB replica 磁盘 I/O 长期饱和事故根因+修复(EBS扩容+bufpool)；区分真告警vs可疑告警的多源交叉法
metadata:
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

# region DB replica I/O 饱和事故（2026-06-08 ~05:00，A 域放量监控期间）

> ⚠️ **重大纠正（2026-06-08 后续，见 [[project-region-cutover-false-alarm-2026-06-08]]）**：本档原把 replica I/O 饱和当成"region 读慢/p99 长尾"的根因——**错了**。inv-path 实测 region web `/proc/environ` DB_HOST=REDIS_HOST=172.31.19.174(HK)，**region 根本没连这两台本地 replica，读写全跨洋打 HK master**。replica I/O 饱和+满盘是**真实问题**(已 EBS 扩容修，有效)，但**不在用户读路径上**，不是当时用户侧故障的根因。真根因=region 数据层跨洋(cache-miss 571ms)+告警虚报。本档以下"A 域放量→region 读走本地 replica"的因果链作废，其余 EBS/iowait 实测数据仍有效。

**触发**：一批告警涌入（REPLICA-LAG-HIGH EU 409s / HTTP_RT_LONG_TAIL aws-data / JVM_HEAP_HIGH / JS错误105%·API失败27% / S池低水位 / EasyList命中basicshift.click）。owner 要求"信息+12h N9E+日志+代码组合分析"。

**方法论闭环（关键）**：先打通数据源再定因，不堆砌猜测。N9E TSDB=VictoriaMetrics `127.0.0.1:8428`（n9e:17000 是 SPA，prom 查询走 VM `/api/v1/query[_range]`）。多源交叉拍真相。

**真根因（多维度实证）**：**两 region DB replica 磁盘 I/O 长期饱和**。
- 12h: 两 replica iowait_avg **93%**（user 仅 4%→纯磁盘等待非 compute），`Threads_running=2`（非查询并发问题），磁盘已用 **90%/87.5%**，loadN_max 仅 1.7（1-2 进程卡 D 态）。
- EBS 实测**不对称**：US vol gp3 60G/**15000**IOPS/125MB/s；EU vol gp3 60G/**3000**IOPS/125MB/s。
- EU 主因=**IOPS**（写 IOPS 时序死顶 3000=基线，lag 期 iowait 52%、catch-up 后飙 98%）。US 主因=**吞吐125MB/s + bufpool错配**（bp_miss 11.2‰ vs EU 0.84‰）。
- 共因=**innodb_buffer_pool_size 只 4GB / 15.4GB 盒子**（m5.xlarge 全员，应 ~10G；mem available 仅 5.7G→不能激进调）。
- **A 域放量把 CN 读流量导到 region→走本地 replica(read_only=1,readOnly路由slave已验)→给饱和盘加读压→读 p99 长尾**(US289/EU383ms,p50=1ms仅尾部)。region web 层本身健康(cpu<7%,5xx=0)。

**修复（owner go 后执行，2026-06-08）**：
- EBS 两盘在线 modify-volume→**120G/16000 IOPS/600MB/s**（无停机；执行后 optimizing 进度0%、iowait 未立即降，需等 optimizing+预热复测真实 KPI=region 读 p99）。
- US replica（ssh config 有条目 ProxyJump，ubuntu+sudo OK）：文件系统 growpart+resize2fs 58G→116G(87%→44%)；`SET PERSIST innodb_buffer_pool_size=6G`(4→6,保守防OOM,Completed)。
- **EU replica OS 访问被拦**（无 ssh config 条目，4key×3user 全 publickey 拒）→ EU 扩盘fs+bufpool 待 owner 给 key；但 EU 主修=IOPS 已经 EBS 层生效不需 OS。

**可疑告警定性**：**JS错误105%/API失败27% 在源站无法复现**——四节点 60万+请求 5xx=**0**、4xx=0.13-0.20%(全499客户端断开)。需读 Redis `monitor:error-top` 桶才能定真伪(NOAUTH,需凭据,sudo取secrets被拦)。JVM_HEAP 70%=健康GC锯齿(1425↔1757MB震荡非泄漏)。**结论：不因这俩回滚 canary**。S池低水位+EasyList命中=同一事(域被过滤表烧→需轮换→补给跟不上)。

**残留跨洋写**（承接 fullcut-5xx round4/5/6，未覆盖批）：analytics/* + snack/tally + rum/image-load + feedback/batch + auth/gw-token + courses/search 在请求线程同步写 HK master(EU>US梯度=跨洋指纹)→另起 SDLC sprint 收口。详见 [[project-fullcut-5xx-rca-2026-06-06]] + skill [[newworld-multiregion-crossocean-hotpath]]。

**架构启示**：replica 必须先解 I/O，才能承接更多 region 读流量；终态 sizing 见 [[project-region-ha-topology-2026-06-08]]。锚点 docs/sprint/2026-06-08-region-final-migration/SESSION-STATE-2026-06-08.md。
