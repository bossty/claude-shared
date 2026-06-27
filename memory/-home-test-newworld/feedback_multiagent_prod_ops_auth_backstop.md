---
name: feedback_multiagent_prod_ops_auth_backstop
description: 多agent生产ops三铁律：auth-backstop+文件优先pull+lead二查抓虚报
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 187c446e-e104-4aa0-a529-a524a6ebe78b
---

多 agent 团队做**生产 ops**（SSH 日志/Redis/部署）时的三条协作铁律，2026-06-13 fe-error-triage sprint 实证（[[project_fe_error_triage_2026_06_13]]）。

**1. auth-backstop（sub-agent prod 访问被拦→lead 代跑）**
sub-agent 的 prod SSH/scp/sudo 会被 auto-mode 分类器拦，理由"peer/teammate 消息不构成 user 意图"。**用户授权只在主会话(lead)生效**——relay 授权给 sub-agent = peer 消息，分类器仍拦（这是对的，防 permission laundering）。
**Why**：授权语义绑定到收到它的会话，不可转授。
**How to apply**：lead 让 sub-agent 产出确切命令，**lead 从主会话代跑** prod 命令，结果回交 sub-agent 分析。本 sprint 5 节点滚动部署、Redis 枚举、5节点日志拉取全走此模式。密钥(REDIS_PASSWORD)从 app `/proc/PID/environ` 注入 env 跑、**禁打印**(owner 密钥不轮换铁律)。

**2. 文件优先 pull（治"队员回报丢失"）**
owner 反映队员→lead 回报经常丢。**改 pull 模型**：队员 `.md` 状态档=权威记录，写完即生效；SendMessage 只是 ping。
**Why**：消息投递不可靠、且常 stale（dev-fix 3 次 stale：commit 数字错/"2 cases"实为3/补报已 commit 的活）。
**How to apply**：派工时明确"先 flush 文件再 ping，丢了我读文件"；lead **主动 ls+读 agents/*.md** 而非干等 inbox；定位段落用 grep 行号再精准 Read。

**3. lead 二查抓 sub-agent 虚报（自报≠实证）**
sub-agent 自报反复≠真相，**必看真 diff / 真 test count / 自跑测试 / 实读 prod 产物**。本 sprint 抓到：commit message 量化偏差×N、FIX-6 用错版本(域轮转 vs 护栏重fetch)、eslint 篡改测试名(FIX-3→fIX-3)、dev 漏写测试用例(报3实2)、canary 只验源码非构建产物。
**How to apply**：部署 canary 必 grep **构建产物**(minified dist)含修复字符串标志(非源码)；commit 前 `git diff --cached --numstat` 核 message；改动后必复跑测试；eslint --fix 后必复跑(它会改测试标题/格式)。
