---
name: project_zero_downtime_hostid_2026_06_16
description: v4 零停机滚动部署(cloudflared不停+nginx同区backup failover)生产实证上线 + 主机标识统一AWS Name + HK retarget；分支 zero-downtime-hostid
metadata: 
  node_type: memory
  type: project
  originSessionId: ed36f894-57b3-4f1e-b7f5-2b5f59c3a13c
---

2026-06-16 epic，分支 `zero-downtime-hostid`（6 commit，off origin/master 97cb6423，已 push，**未 merge master/未开 PR**——gh/token 缺，待 owner 一键 `pull/new/zero-downtime-hostid` + PR-BODY.md）。

## A. v4 零停机部署（设计→蓝军→M1→canary→fleet→接进 deploy-web，全闭环，生产实证 5xx=0）
- **根因**：旧滚动靠 `stop cloudflared` drain → CF 边缘 connector 注销/重注册有秒级控制面窗口 → 部署期 5xx。（根因未现网 CF GraphQL 实证=蓝军 BLOCKER-1 降级；但 fix 覆盖 CF窗口+JVM窗口两类候选根因=根因无关稳健）。
- **方案**：cloudflared **全程不停**，仅 `systemctl restart` JVM；本地 :7777 重启窗口由 **nginx 同区 backup failover** 兜。两层：app graceful 排在途 + nginx failover 接窗口新请求。
- **落地形态（owner 决定，非 lua）**：每节点一份静态 `openresty/.../conf.d/upstream-<ssh-alias>.conf`（127 primary + **同区其他节点 backup、不含自身** + EU `max_fails=0`）；共享 nginx.conf 加 `include conf.d/active-upstream.conf`（固定名，nginx include 不支持变量）仍字节一致；`deploy-openresty.sh` 按 HOST 落地 active-upstream + `--exclude` 防 --delete 误删 + `--check` 漂移检测（替代退役 sync-region parity）。`proxy_next_upstream_tries 2→5`（与加 backup 原子）。
- **生产实证**：canary ca-web-01（JVM down 16s，222/222=200，5xx=0）+ EU eu-web-02（748 个 :7777=000 采样里 :80 **全 200**，eu-01 单 backup 扛 2× 成功）+ web.log 真实 CF 流量 5xx=0。
- **B2/B1 接进流程**：deploy-web.sh 删 drain/restart_tunnels/verify_drained → `peer_ready_gate`（重启前验同区≥1 peer READY）+ JVM restart 走 failover，保全回滚/状态续跑/readiness/错峰；region-readiness-gate G1 从「无 backup」翻转为「本地 primary+同区 backup≥1+无跨洋」（真 fleet PASS）。

**Why**：owner 痛点=部署期短暂不可访问。**How to apply**：① 每节点静态 config > lua/hostname（blast radius=1 台 vs 全机队；无运行时魔法）② `tries ≥ 1+同区peer数`，且 backup **不含自身 IP**（含自身+tries小→死后端耗尽 tries→502，DESIGN §5b 实测）③ **薄池(EU=2) `max_fails=0` 必须**——熔断把"一时变慢"放大成 no-live 黑窗（[[project_fullcut_5xx_rca_2026_06_06]] 同源机制，M1 第一轮 2869 条 502 重现）④ failover 测试金标=同循环采 :7777(证 down)+:80(测 5xx)，看"down 的采样里 :80 是否 200"，别只看 :80 全 200（可能 JVM 没真 down=空测，我第一次 EU 测就栽这）⑤ EU JVM 启动 ~38s（>CA 16s）→ readiness warm 超时给够⑥ peak 窗 owner 授权可单台 force（记复盘），但首次验生产偏挑峰窗=风险最大时机，能错峰就错峰。

## B. 主机标识统一 AWS Name（在役 12 节点，repo 先行）
- canonical（AWS 实查 ground truth，owner 已改 Name tag）：`ca-web-01..04`/`ca-mysql-master`/`ca-redis-master`/`ca-admin`/`ca-monitor`/`eu-web-01/02`/`eu-mysql-slave`/`eu-redis-slave`。改 ssh config + 部署脚本 + 6 个 v4 文件 + CLAUDE.md 主机表；退役引用（aws-web/aws-data/*-old）**保留**（历史）。
- **陷阱**：`ca-redis`→`ca-redis-master` 防双替(负向前瞻)、`ca-db-master` 避 `-old`、bulk 必 word-boundary 非裸 sed。ssh config IP 是动态公网会 stale（ca-monitor 52.53→实测 54.67.137.125）。`ops/region-nodes.conf` 的 EU IP(.6.211/.10.241) 是 stale phase0 老 POC，真值 .58/.14.95（必问真实节点 `hostname -I` 非信文档）。
- live 服务器 hostname/categraf/n9e ident 改动=另出清单 owner 执行（`LIVE-SERVER-CHANGE-LIST.md`），改 n9e ident 会断历史 metric 时序。

## C. HK retarget（活脚本指退役 HK = 真 bug，耦合非盲删）
- 退役 HK 别名被 ~40 脚本引用，**活脚本仍以退役 HK 为目标=stale-target bug，会连 AWS recycled-IP（比报错更险）**：`deploy-frontend.sh ADMIN_HOST=aws-data`→ca-admin、监控链 deploy-categraf/nightingale 端点指 HK→ca-monitor（**实证 n9e 在 ca-monitor 172.34.1.29:17000**）。删退役 ssh 别名前必先 retarget 引用它的活脚本。剩 deploy-categraf 车队白名单+per-host 逻辑（HK 拓扑→CA/EU 终态）= 配置设计 rework（FOLLOWON.md §2b）。

## D. 分支卫生（并发 master 写线）
- master 是多会话并发写线，另一会话在改写。我的工作叠在 stale `restore-p03e`（3 个 cableav commit）上→**新建干净分支 off origin/master 只装我的**（cableav 实查只碰 newworld-data，与我零重叠）。删 restore-p03e 前 `git cherry`/内容 diff 判定（cableav 已在 master=a2dd6388+蓝军6条，restore-p03e 是被超越的旧线）；删前记 tip SHA（reflog 恢复）。**owner 一句"cableav 不是合了吗"揪出我"SHA 不在≠内容不在"的判断不精确——内容层 fact-check**。

权威细节：`docs/sprint/2026-06-16-zero-downtime-deploy/`（DESIGN §5b/c 实测、PROPOSAL §9/§10 仲裁、CANARY-RESULT）+ `docs/sprint/2026-06-16-hostid-standardization/`。
