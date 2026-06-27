---
name: project_snack_upload_gate_fix_2026_06_15
description: 广告图上传 pilot 闸门解除已上线(SQL v40+admin jar);prod admin 跑未push commit 2375f855
metadata: 
  node_type: memory
  type: project
  originSessionId: e9a0d00d-b555-4e41-9d2b-12653de1f305
---

广告管理编辑广告上传图片报 `slot=p08 未配置 component_code，无法确定加密路径`。

**根因**(非 R2 文件夹问题)：前端唯一上传路径 `/v1/upload/snack-image` 闸门只放行 `component_code∈{Snack01,Snack05}`(pilot)；线上 snack_slot 19 行实测**只有 z02=Snack05 配了 code**，其余 18 行 NULL(含 2 text)→ **16 个非 text 位全堵**，p08 只是其一。连本该是 pilot 的 Snack01 都已丢 code。

**修复(已上线 2026-06-15)**：
- 后端 `SnackImageEncryptService`：删 `PILOT_COMPONENT_CODES`/`isPilotSlot`，新增 `hasComponentCode`(非空+数字段非空护栏防 `snack//` 坏路径)。
- `UploadController`：**两个**上传接口(`/snack-image`+`/snack-image-encrypted`)闸门都改 `hasComponentCode`(蓝军 BLOCKER)。
- `sql/v40_snack_component_code_backfill.sql`：16 slug→唯一 code 显式映射(g→Snack1x/l→2x/p→3x/z→4x，数字段与既有 05 全不撞)；幂等+text 排除。
- 前端解密**与 component_code 无关**(只取 url+ts，key 由 ts 派生)；web 侧零处读 component_code(component_code 仅 admin 派生 R2 路径用)→ 故放开零前端风险(蓝军实证)。

**LIVE 状态(防重做)**：
- ✅ v40 已在 prod 库执行(ca-db-master 172.34.1.222)：16 位回填，need_backfill=0，零撞号，z02/text 不动。
- ✅ admin 已部署 `admin-20260615-2375f855.jar`(PID 起于 20:53，Started in 13s，8888 listening)。**该 commit 2375f855 = origin/master + cherry-pick；本地 master 上是 8a243402，两者均未 push**(owner 决定先部署暂不 push，因 origin/master 落后本地 29 commit，其中 28 个是其他未验证工作)。
- ⚠️ **prod admin 跑的是未 push 的 commit**；origin/master 不含本修复。下次别因 "origin 没这代码" 误判。
- 🔶 **e2e 缺口**：未做真实 UI 上传(需 admin 登录态+会真写 R2/DB)；gate 通过是确定性证明(jar 逻辑+DB p08=Snack38+单测)，待 owner UI 实点最终确认。
- 回滚：`ln -sfn deploys/admin-20260614-cfd2c57c.jar deploys/current.jar && systemctl restart newworld-admin`(SQL 回滚=`UPDATE snack_slot SET component_code=NULL WHERE slug IN(16个) `，但放着无害)。

**验证**：mvn -pl newworld-admin -am test=1847 pass；蓝军两轮 GO(7 findings closed)。
设计/复核档：`docs/sprint/2026-06-15-snack-upload-gate-fix/`。

**后续 fix（同日，取消编辑 3 问题）**：上传成功后取消编辑暴露 3 个同源问题(加密改用新路径 `snack/static/snackNN/{hash8}.js`+8位hash，但 admin 删除/预览仍停旧 v3=12位hash+AD_PATH/{hash}_p.js)：①取消报"非法路径"(deleteSnackImage 不认新前缀+前端传裸8位hash)②R2孤儿(删除失败残留)③`ERR_BLOCKED_BY_ORB`(预览解密blob未就绪时回退`<img src={CDN}/{hash}>`裸hash 404 text/html被当图→ORB拦)。
修复 commit `270d407e`(本地)/部署 sha `54a39575`：后端 deleteSnackImage 加 `snack/static/` 前缀分支；前端删除链路改用真实 `encryptedImageUrl`(8位hash反推不出slot文件夹号!)+新增 pendingUploadEncPath/originalEncImageUrl+deleteImageFile helper；预览加密图只显blob不回退裸URL。
**已部署**：admin jar `admin-20260615-54a39575.jar`(含gate fix+本fix，origin+cherry-pick两commit隔离build) + frontend-admin dist(backup=dist.backup-snackfix)。验证 mvn UploadControllerTest=25 pass(+1 snack/static删除用例)+vite build通过。回滚 jar=symlink→`admin-20260615-2375f855.jar`、dist=`mv dist.backup-snackfix dist`。
铁律补充：frontend-admin 服务目录 `/newworld/frontend-admin/dist`(static，无需重启，backup=dist.backup-*)；本地多commit时 `mvn 不带 -am` 会链 ~/.m2 旧 common 致 rider 编译错(假错)，必带 -am；admin host 验 jar 内容用 python3 zipfile(无unzip)。

教训：admin host(Ubuntu26.04)**无 mysql/unzip 客户端**(本次装了 mysql-client 8.4.9)；查 jar 内容用 `python3 zipfile`(无 unzip)；本地多 commit 时部署必查 prod jar 实际内容(`unzip/zipfile` grep 类名)确认没夹带 rider，build 走 origin+cherry-pick 隔离 worktree。
