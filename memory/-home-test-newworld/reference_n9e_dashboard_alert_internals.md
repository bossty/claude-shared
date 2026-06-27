---
name: reference_n9e_dashboard_alert_internals
description: N9E v8 dashboard/alert 取数与改法 + categraf 缺插件的 input.exec 通用逃生口 + MySQL8.4 replica 监控 + edge openresty logrotate
metadata: 
  node_type: memory
  type: reference
  originSessionId: 55b6c752-c743-48d4-9475-c0663cd54e40
---

N9E v8 监控修复/排错的可复用知识（2026-06-15 sprint 实证，配 skill `newworld-monitoring-ops`、access 见 [[reference_n9e_ca_monitor_aws_access]]）。

**dashboard/alert 真值在 DB（n9e_v8）**：
- config 在 `/opt/n9e/etc/config.toml`（非 /etc/n9e/）。n9e DB user 仅 `n9e@127.0.0.1`+caching_sha2 且密码可能含 `#`、socket 连接被拒 → 只读统一用 `sudo mysql n9e_v8 -e "..."`（root maintenance socket）。
- dashboard：`board`(元) + `board_payload`(panel JSON，含模板变量+PromQL targets；payload 有换行用 `to_base64()` 传)。模板变量形如 `label_values(<metric>, <label>)`。
- alert：`alert_rule`，PromQL 在 `rule_config` JSON 的 `queries[].prom_ql`。
- **datasource_queries 铁律**：改 alert 后必确认该字段非 NULL/非空（值如 `[{"match_type":0,"op":"in","values":[1]}]`）；NULL=engine 永不 eval。`datasource_ids` 是 deprecated 字段别认它。改完 n9e v8 自动热加载。
- **坑**：部分 rule_config 是**非法 JSON**(promql 内层 `label="val"` 引号未转义)，n9e 宽松解析能跑但严格 parser(迁移/备份脚本)会**静默丢 prom_ql**——迁移前规范化。

**categraf 缺插件的 input.exec 通用逃生口**（最高复用价值）：
- flashcat categraf v0.5.6 是**精简构建**，`ntp`/`x509_cert`/`nginx_log` 二进制未编入(`-test -inputs X` 报 not supported)；`nginx_log` 在主干根本不存在。**别为这个升级 categraf**(fleet 二进制替换 blast radius)。
- 解法：`input.exec` 跑脚本输出 prometheus 文本格式（`data_format="prometheus"`），categraf 自动附全局 ident/region/dc 标签。**emit 的 metric 名严格对齐现有 alert → 零 alert 改动**，metric 一出数告警即生效。
- 实证落地：x509(openssl s_client|x509 -enddate→`x509_cert_expiry_seconds{project="newworld"}`)、ntp(`chronyc tracking`→`ntp_offset_ms`)、procstat rlimit(读 /proc/<pid>/limits→`procstat_rlimit_num_fds_soft`)、nginx_log(mtail tail access-log→`nginx_log_status_total{status,target}` + categraf input.prometheus scrape mtail :3903)。凭证用 `--defaults-extra-file`(600) 别明文进脚本。

**MySQL 8.4 replica 监控**：8.4 **移除** `SHOW SLAVE STATUS`(报 ERROR 1064)，只留 `SHOW REPLICA STATUS` → categraf mysql input `gather_slave_status=true` 永不出 replica 指标。解法 input.exec 跑 `SHOW REPLICA STATUS\G` emit `mysql_replica_seconds_behind_source`/`_io_running`/`_sql_running`(1/0)/`_last_io_errno`/`_last_sql_errno`，alert 指这些。**master 节点 gather_slave_status 保持 false**(无 upstream，开了也空)。

**edge openresty logrotate**：USR1 reopen 法(logrotate postrotate `kill -USR1 $(cat nginx.pid)`)，**禁 copytruncate**(大日志会瞬时翻倍 copy + 丢拷贝间日志)。compress+nodelaycompress+`maxsize 2G`+独立 hourly cron+独立 state file(不放 /etc/logrotate.d/ 防系统 daily 双轮转)。首次压大日志用 `nice/ionice` 防影响生产转发。**★轮转后必验 mtail/categraf 仍续采**(rotation 可能断 tail)——VM 查 counter 续涨，停滞则 restart。

**监控机暴露**：N9E 经 cloudflared 隧道(出站)对外，源站 :80/:17000/:8428 走 SG 仅放内网即不可直连——判暴露看 SG 实际 inbound(`aws ec2 describe-security-groups`)，别只看 `ss` 的 0.0.0.0 绑定。
