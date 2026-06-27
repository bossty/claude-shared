---
name: project_code_topology_realignment_2026_06_13
description: 终态架构B后代码流程对齐sprint——域名onboarding指死HK tunnel根因+build-host退役缺口+蓝军两轮/lead二查(2026-06-13)
metadata:
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-13 终态架构 B 实例层收口后，owner 问"代码很多流程是不是也要相应改，特别是域名部分"→ fact-check 实代码起 sprint「代码对齐终态架构 B」。5 阶段 SDLC 全闭环（commit 链 0bde1c6f）。

**★核心根因 = 域名 onboarding CNAME 指死 tunnel（潜伏地雷）**：`DomainLifecycleService.addWebDnsRecords`+`addWildcardCnameRecord` 建 A/C/P 域 CNAME 时 target 来自 `getTunnelCname(account)`→`{CF_TUNNEL_ID_x}.cfargotunnel.com`（单 tunnel 直连，pre-LB 旧模型）。实测 **CF_TUNNEL_ID_A=63594ad3=A-HK-tunnel DOWN、CF_TUNNEL_ID_P=1af743b6=P-tunnel DOWN**（HK 退役死的），C-tunnel healthy。→ **新 onboard 的 A/P 域 CNAME 到死 tunnel 一上线即 502**（现有域名不受影响因已迁 LB；bug 仅新域触发）。终态 A 域应走 LB `tcos-canary.dnsv106.com`(geo-steering)、P 走 `p-lb.lbedge.org`。**修=新 resolver `getDomainCnameTarget(account)`：A/P→LB(走 SystemConfig 键 A/P_CNAME_LB_TARGET 非硬编码)、C→保留 getTunnelCname(C-tunnel活)、S→null(走 Wave8 独立路径,加守卫 throw 防误入静默失败)**。

**★build-host 退役缺口（连锁坑）**：退役 aws-data（HK admin 主机）时它也是 admin 的 build host（有 git+maven），退后 **aws-ca-admin 无 git+无 maven**→admin 没法在机上 build。解=本地 build jar+scp（也更合"build 一次 ship 制品"铁律）。**铁律：退役服务器前查它是否兼任 build/CI host**。+ Ubuntu26.04 SSH 用户非 newworld，scp 进 newworld-owned 目录要先 scp /tmp 再 sudo mv+chown。

**蓝军两轮 13 条 + lead 二查双向纠**：一审(PLAN)7 条 F1-F7、三审(code)6 条 B1-B6。lead 二查实测纠偏两处：①**B1 BLOCKER 下调**——蓝军说"删 v1 短链 fallback 后冷启动 S 域 500"，但二查发现**改前 v1 连的就是死 IP 172.31.27.200**(冷启动也连死IP→跳错域)，删 v1 是"错跳转→干净 500"非新回归；last_good 落盘是既有缺口顺手修非 blocker。②**B3 坐实真漏改**——`SystemMonitorTask.isOriginHealthy():353` 残留 HK 死 web IP 172.31.27.120/121(dev 只改 checkDisk 漏了这个)→origin 5xx 监控盲区，改动态读 system_config WEB_LAN_IPS。dev-senior 也当场 fact-check 出蓝军 F4 部分误报(SSH 本就有 ConnectTimeout=5)。**教训：蓝军挑刺质量高但会 framing 过严/误报，lead 必实测二查双向(既不放真问题也不被误报带停)**。

**其他坑/铁律**：①edge openresty 部署是 **restart 非 reload**（short_redirect/pool_snapshot_puller 是 lua 模块,require 缓存,reload 不重新 require 改动不生效）②CNAME→proxied LB hostname 模型现网已验证(17.rip/bytebase26.top 的 @+* 都→tcos-canary proxied→200)非新发明③WS1 验收:A 域无手动激活 API(走调度器)+无干净 deactivate→峰窗强行触发+手动 release 风险>价值,改"现网模型证实=新代码产出 target"等价闭环④context-mode hook 拦 mvn(dev-senior 工具集无 ctx_execute)→lead 用 ctx_execute 兜底跑⑤死 tunnel(A-HK/A-OR/P-tunnel)owner 裁定"HK 退役回滚弹药是伪命题"直接删不留 re-arm。

**部署**：admin(aws-ca-admin 新 jar 0bde1c6f,旧 jar rollback)+edge×3(usca-1/2/aws-s,各.deploy-bak rollback)+死 tunnel 删。全程峰窗 FORCE_PEAK(owner 授权)、逐台、rollback 位齐、站点零影响。详见 docs/sprint/2026-06-13-code-topology-realignment/(PLAN+reviewer 两轮+phase4-deploy)。

**How to apply**：①任何基建迁移/退役后必 fact-check 实代码旧拓扑假设(死 IP/tunnel ID/region 硬编码),尤其域名/DNS/健康检查/监控这类"配置驱动但可能硬编码源 IP/tunnel"的流程 ②退役服务器前查它兼任的角色(build host/CI/relay/proxy 对端白名单——见 [[project_phase_f_admin_data_california_2026_06_13]] buyvm UFW 同类)③蓝军挑刺 lead 必实测二查(误报下调+漏报坐实双向)④edge lua 改动必 restart 非 reload⑤LB-CNAME 模型用 SystemConfig 键不硬编码(LB 改名零 deploy)。关联 [[project_hk_web_retirement_2026_06_13]]、[[project_phase_f_admin_data_california_2026_06_13]]。
