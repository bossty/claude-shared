---
name: reference_clone_ca_web_node_sop
description: 加/克隆一台 CA web 节点(AMI 克隆)的 SOP + 三个必踩坑(categraf ident/EIP配额/cloudflared出站)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9532d6aa-c746-4dc8-9e64-aaed3bb1448b
---

2026-06-16 加 ca-web-04 实证。CA web 用 cloudflared **token 型**(`tunnel run --token`)→ 同 token 多副本 CF 自动跨 tunnel 负载均衡,**加节点 = 克隆一台起服务即接入,CF/LB/DNS/steering 零改动**(ha_conn 自动 +1)。

**SOP**:① `create-image --no-reboot` 从 ca-web-01 建 AMI(不扰在跑节点)② launch(m5.xlarge / us-west-1a / subnet-0285f465a18ba580f / sg-054a1c57fdb6cfb02 / root 100G gp3 / **`--associate-public-ip-address`**)③ 节点唯一项 fixup ④ 验证服务+真分流 ⑤ 文档+ssh config。

**三个必踩坑(AMI 克隆共享态)**:
1. **★categraf ident 硬编码**:`/etc/categraf/config.toml:3 hostname = "ca-web-01"`(非 OS 派生)→ 克隆后不改会**以 ca-web-01 ident 上报撞掉真节点监控**。必 `sed` 改 + restart categraf。验:N9E `system_load_norm_1{ident="ca-web-XX"}` 独立有数 + 源节点未被污染。
2. **★public IP / cloudflared 出站**:CA web 现役**全用 EIP**(CLAUDE.md "非 EIP 动态"已过时),us-west-1 EIP 配额 5/5 满;子网 `MapPublicIpOnLaunch=false`。不带 `--associate-public-ip-address` launch → 新节点无 public IP → 无 NAT GW → **cloudflared 出站连不上 CF edge(:7844/:443 timeout)→ 没接入没分流**(内网服务全正常会假绿)。解=launch 加 flag 给动态 public IP。public IP 在本架构只用于 cloudflared 出站 + SSH(可走 ProxyJump 经 ca-admin 内网),**不需稳定 IP,动态够用**。
3. **clone 卫生**:regen SSH host keys(`rm /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server`)+ 重置 machine-id + truncate 克隆带来的旧 nginx web.log/error.log。

**无需改(实证自动覆盖)**:DB+Redis 同 SG sg-054a1c57fdb6cfb02 放行 172.34.0.0/16 + MySQL grant `newworld@'172.34.%'` 通配 → 新节点网络层+应用层自动放行;nginx.conf(127.0.0.1 primary)/systemd env(DB .222/Redis .128)AMI 带的就对;web 无 peer 配置。

**真分流验证(非假绿)**:本节点 web.log 出现真实用户请求(cf_ray 非空)+ cloudflared ha_conn=4 + 其余节点 load 应声降。关联 [[reference_n9e_ca_monitor_aws_access]]、[[feedback_repo_nginx_conf_stale_upstream]]。
