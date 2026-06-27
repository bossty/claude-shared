---
name: project_ca_master_binlog_disk_2026_06_21
description: "ca-mysql-master(.222 CA写主)DISK_USED_HIGH告警 RCA=binlog 45G/30天默认保留,已降7天+purge"
metadata: 
  node_type: memory
  type: project
  originSessionId: 843d7b10-e033-4dbb-a425-d3d7335b1d67
---

2026-06-21 20:24 N9E S2 告警 `DISK_USED_HIGH` ca-db-master(=`ca-mysql-master` .222,SSH 别名 `ca-mysql-master`,EIP 13.57.1.70),`/` 81%。

**RCA**:`/` 116G 单盘(数据目录不独立挂载),`/var/lib/mysql` 90G = 数据 `newworld` 45G + **binlog 45G(455 文件 ×100MB)**。binlog 保留 `binlog_expire_logs_seconds=2592000`=30 天(**MySQL 默认值,非有意设定**)。binlog 写量在 6/14 起从 ~3 文件/天 跳到 ~54/天(~2.4G/天),时间点对上 **6/13 终态架构 B 收口**(所有写入合并到这台 CA 写主),属预期非异常。

**安全前提**:仅 1 个活 replica=EU slave(`eu-mysql-slave` .248,`SHOW REPLICAS` Server_Id 4),已追平到活动 binlog .000455 延迟 1s;buyvm-db 是离线 dump 非活复制。故 .000001–.000454 可安全清。

**处置(Owner 选"保留7天+降7天")**:① `SET PERSIST binlog_expire_logs_seconds=604800`(7天,写 mysqld-auto.cnf 防重启失效);② `PURGE BINARY LOGS BEFORE DATE_SUB(NOW(),INTERVAL 7 DAY)`。结果 81%→74%(仅释放 8G 因 379 文件/37G 都在 7 天内),replica 仍健康延迟 0。

**治本已做:在线扩 EBS 根卷 120→200 GiB**(Owner 拍板)。instance `i-0dda3eadcc202eac0`(us-west-1a)单根卷 `vol-07a552d18e133cc3c`(gp3,/dev/sda1)。步骤:本地 `aws --profile nw-dev --region us-west-1 ec2 modify-volume --volume-id <v> --size 200` → 轮询 `describe-volumes-modifications` 到 `optimizing`(此时 OS 才见新容量)→ 写主上 `sudo growpart /dev/nvme0n1 1` + `sudo resize2fs /dev/nvme0n1p1`(ext4 挂载在线扩)。结果 `/` 116G→193G,用量 74%→**45%**,MySQL uptime 8.5 天**未重启零中断**,EU replica 延迟 0。⚠️ EBS 同卷 6h 冷却期、只扩不缩。AWS account=748579767645(nw-dev)。复用:写主 binlog 清理必先验 replica `SHOW REPLICA STATUS` 的 Source_Log_File 追平再 PURGE;MySQL 8.4 `SHOW MASTER STATUS` 已废弃→用 `SHOW BINARY LOG STATUS`。
