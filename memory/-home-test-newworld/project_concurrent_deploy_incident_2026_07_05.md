---
name: concurrent-deploy-incident-2026-07-05
description: 07-05两会话27秒间隔并发deploy-web互相覆盖事故：现场收敛+三防线机制化(Gate M/A+sha路径)，B需merge基线后重部署
metadata: 
  node_type: memory
  type: project
  originSessionId: c5caee8a-f62d-4b1f-a4c0-3a770cdda70b
---

2026-07-05 07:56 两会话并发跑 deploy-web.sh：B（`afe2a6f9` fix/channel-saturation-no-scan，07:56:23 起）每台先装，A（`9ba95945` feat/viewcount-live-display，07:56:50 起）尾随约 25 秒逐台覆盖——B 自报 CA×4 部署成功，实际其 jar 每台仅存活约 25 秒。Gate 4 当时因 deployed/web tag 从未登记而空转。第三方会话现场处置：07:01 杀掉 B 进程（其产物已被全覆盖，止损最小），A 作为单一写者跑完全舰队。

**终态（已实证）**：web×6 全部 = `9ba95945`（CA×4 逐台 md5=da82fdb6 核过），`deployed/web` tag 已登记 = `9ba95945`（首个基线 tag，Gate 4 自此生效）。**B 的渠道饱和修复未上线**——B 重部署时会被 Gate 4 正确拦截，必须先 merge `9ba95945`（或合 master 后基于新 master）重新 build，禁 GIT_PREFLIGHT_FORCE 绕。

**三防线已机制化并合 master `55599422`**（Owner 拍板合入，分支已按流程删除）：Gate M flock 互斥锁（按部署目标一把，进程死自动释放，锁测 7/7 绿）+ Gate A Owner 授权门（[[owner-approval-all-deploys]]，OWNER_DEPLOY_APPROVED=1 才放行）+ 远端落地路径带 sha（jar+前端三处 tar，消换包 TOCTOU）。另 git_mark_deployed 加重试+醒目告警，tag push 加 --no-verify（省每次部署 ~7 分钟重复门禁）。

**教训**：nohup 起的部署脱离会话存活，暂停/关会话杀不掉（A 即如此，反而因此善终）；时点检查防"先后"不防"同时"；"某场景从未发生"不是不设防的理由。
