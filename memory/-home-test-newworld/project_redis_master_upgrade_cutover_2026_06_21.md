---
name: project_redis_master_upgrade_cutover_2026_06_21
description: ".128 Redis主(2vCPU)快照35s饿死命令致EU snack写超时→升.170(r6i.xlarge 4vCPU,快照期命令max1ms)；新机已挂replica同步好待cutover；runbook+蓝军过，预约04:00 HKT自动执行(预授权)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 85dc3fe1-5403-474d-941b-c0f0f36ee859
---

**根因**：`.128`(ca-redis-master, r6i.large **2vCPU**, Dragonfly v1.38.1, 全站唯一写主)快照 `last_success_save_duration_sec=35s`(snapshot_cron */30)吃满双核→命令饿死→**EU web snack 曝光写(hIncrBy→statsRedisTemplate→REDIS_HOST=.128 跨VPC-peering)5s 超时丢曝光**(QueryTimeoutException,聚在 :00/:30)。CA 本地零超时。**实证排除磁盘**：EBS 拉到 500MBps/6000IOPS 快照仍 35s/写仅 83MB/s(Dragonfly 2vCPU 序列化产出慢);非跨洋延迟(EU→.128 ICMP 149ms 稳,远<5s,VPC peering)。**升 vCPU 治根**:新机 .170(4vCPU)实测快照 19s 但**期间命令 max 1ms**(留核给命令不饿死)。

**已就位(不碰生产)**：新机 `ca-redis-master-2` i-0bcbb51f4eb5368ea，**r6i.xlarge 4vCPU**，私网 **172.34.1.170**，Dragonfly 同版本 v1.38.1-8dbbd4f0(scp .128 二进制)，maxmemory 24gb，EBS 50G/500MBps/6000IOPS，同 subnet/SG(sg-054a1c57 已放行 buyvm)/key(nw-poc)。已 `REPLICAOF .128` full sync 完，DBSIZE 对齐(~970万)，实时跟随。临时 EIP 13.57.122.136(SSH:ec2-user@ -i ~/.ssh/aws_region,redis6-cli)。密码全 wKkaW98dNJAYPiCNSp6CzuEoPVU0Rbf6。

**★实测铁律**：Dragonfly replica full resync 期间所有命令返 `LOADING`(连 PING)**不 serve stale**。故"正在被读"的 replica 不能 cutover 期 resync→EU 读走 .184,.184 换主必 resync 5-6min LOADING→**必须先把 EU 读临时挪到 .170 跨区,腾空 .184 后台 resync,再切回**(否则 EU 读中断)。

**cutover 计划(蓝军过+lead二查7/8有效,C1 N9E误报)**：写统一.170/CA读.170本地/EU读.184本地(.184跟.170)。全客户端=CA web×4+EU web×2+ca-admin(admin+data)+buyvm×3(Lettuce活跃,走EIP184.72.0.67→搬到.170零配置跟随)+EU replica.184(REPLICAOF.170)+.170提主。**OpenResty非Redis客户端(lua用shared_dict,删步);N9E用本机Redis非.128**。drop-in:CA web REDIS_HOST=datasource.conf/REPLICA=redis-replica.conf;EU REDIS_HOST=datasource.conf/REPLICA=replica-redis.conf(**有引号**);ca-admin REDIS_HOST在主unit。EIP:184.72.0.67=eipalloc-08101be2a9fa71e2b/assoc-07cb09854ec96a6f1(.128);13.57.122.136=eipalloc-00ff5d1b59a97e0df/assoc-08832309f72e4c31b(.170)。

**★最终结论(2026-06-21 夜)：cutover/升级 全部作废,.170 已停。** 关键反转(两轮蓝军 max-effort + 实测):
- **R2 蓝军 10 条(5 BLOCKER)**:无人值守机制本身坏(工具调用卡审批/留半截坏状态)、premise 没在真负载验、EIP 搬家自断 SSH、EU sed 漏、S4 redis-cli 漏等。已**取消 cron**。
- **Dragonfly 官方文档(用户逼查)**:快照并行吃满所有核(share-nothing),"加核留空闲核"假设站不住;真杠杆=`--background_snapshotting`(默认false,true=快照降后台fiber+`scheduler_background_warrant`保前台命令CPU)。
- **.128 真盒设 background_snapshotting=true 后 21:30 快照 EU 超时仍 14(基线16)= 没修好**;**受控模拟铁证:2核+10万ops/s写+快照,本地写吞吐不塌(48k→122k)= "2vCPU快照饿死命令"premise 对本地写根本不成立**。EU 14-16/快照超时更可能是快照期偶发亚秒停顿×跨区(149ms in-flight)个别写,千次中几次。
- **本质**:全程为修 EU snack 曝光每快照丢~14-16条≈0.002%统计误差零用户影响,不值任何高风险操作。**早期没把"收益0.002%"摆最前权衡=教训。**

**当前真值**:① **.170 已 terminate**(i-0bcbb51f,EBS DeleteOnTermination 一并删全省;EIP 13.57.122.136已释放;runbook REDIS-CUTOVER-EXEC.md 在,要时可重建)。.128 生产主没动(保留 EIP 184.72.0.67)。② **.128(+停机的.170)background_snapshotting=true 留着**——非为EU超时,而是**通用减压**(缓解任何dump时CPU争抢/本地命令延迟/admin掉线类本地击穿),runtime+unit持久化下次重启生效,无害。③ .184 没设(SSH拒+跨区连不上,EU replica次要,follow-up)。④ cutover 文档(PLAN/EXEC/cutover-reviewer*)**已作废**留作记录。**不再升级/failover。** 真要修EU(不必)唯一对路=代码层write-coalescing。**cdn-metric 等见 [[project_cdn_fail_metric_artifact_2026_06_21]]**。
