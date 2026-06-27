---
name: reference_n9e_ca_monitor_aws_access
description: "现役 N9E 在 ca-monitor(us-west-1,非HK n9e)、ssh config monitor IP 全失效、AWS 操作走 nw-dev profile"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9532d6aa-c746-4dc8-9e64-aaed3bb1448b
---

2026-06-15 排查 web 负载告警时实测:

**监控(N9E)已迁到加州,HK n9e 不在运行列表**:
- 现役 N9E = `ca-monitor`(Name tag),us-west-1,私网 `172.34.1.29`。TSDB=VictoriaMetrics 在 `:8428`(`/api/v1/query` + `query_range`),n9e UI 在 `:17000`(`:9090` 不通)。
- HK `n9e`(172.31.18.101)+ `aws-monitor`(16.163.94.193)+ `aws-ca-monitor`(52.53.225.109)的 ssh-config public IP **全部 SSH 超时**(aws-* 动态 IP 失效;ap-east-1 running 仅余 302-01)。
- 连法:ssh config 里 IP 是旧的,用 `nw-dev` 查真实 public IP 再连:`ssh -i ~/.ssh/aws_region ubuntu@<现IP>`(ca-monitor 用户=ubuntu)。

**AWS CLI 凭证**:本地 `default` profile 无凭证(NoCredentials),**必须用 `AWS_PROFILE=nw-dev`**(user/nw-dev,account 748579767645),有 ec2 describe/modify-volume 权限。web 节点本身**无 IAM role**(`iam_role=NONE`),不能在节点上跑 aws ec2。EBS 扩容/查 IP 都在本地用 nw-dev 跑。

**查节点真实 public IP(动态)**:`AWS_PROFILE=nw-dev aws ec2 describe-instances --region <r> --filters Name=instance-state-name,Values=running --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,Priv:PrivateIpAddress,Pub:PublicIpAddress}" --output table`。

判 web 节点真忙用 N9E `system_load_norm_1`(决策B,绕 iowait);判 IO 真伪用 `cpu_usage_iowait`(≤1.3% 即非 IO 瓶颈)+ `diskio_io_util`,见 [[feedback_web_load_io_vs_cpu_diagnosis]]。
