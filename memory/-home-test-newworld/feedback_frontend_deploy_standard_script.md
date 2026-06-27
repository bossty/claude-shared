---
name: feedback_frontend_deploy_standard_script
description: 前端部署必走 scripts/deploy-frontend.sh，禁手跑 npx vite build / home 目录野脚本（2026-05-31 version.txt 洪流事故）
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 54236e30-dbdb-47b2-a9be-9e37a422af85
---

前端部署**只走仓库标准脚本** `scripts/deploy-frontend.sh`（web/admin/both），禁止手跑 `npx vite build` 或 home 目录临时脚本（如已废弃的 `/home/test/deploy-fe-safe.sh`，无构建/无校验/无 GIT_SHA）。

**Why（2026-05-31 真实事故）**：图快跑了 `npx vite build`，漏掉 package.json `build` 的后半段 `&& node scripts/obfuscate-sw.js` → ① `version.txt` 不生成（它由 obfuscate-sw.js 写 build hash）→ OpenResty 找不到静态文件，`/usr/local/openresty/nginx/logs/error.log` 狂刷 `/newworld/frontend-web/dist/version.txt failed (No such file)`（实测两台 5989+3861 条）+ SW 版本检测拿 404 失效；② sw.js 未混淆。注意 origin :7777 对 version.txt 返回 **HTTP 200 但 body 是 `{"code":404}` JSON** → `curl -w %{http_code}` 会误判 200，必须看 body 或走 CF。

**How to apply**：① 改完 commit + push **master**（标准脚本在 aws-web-01 `git pull` master 再 build，feature 分支必先 merge 进 master）；② 跑 `INTERNAL_API_SECRET="$(ssh aws-web-01 'set -a;. /etc/newworld/secrets.env;printf %s "$INTERNAL_API_SECRET"')" bash scripts/deploy-frontend.sh web`（secret 从服务器 source，不落盘不硬编码）；③ 标准脚本 7 步含 Step1 全构建(GIT_SHA+obfuscate-sw)、Step5 验 version.txt 一致(`abort` on mismatch)、Step6 s.dat≥32、sync-seeds 写 dist.new 消 0 字节窗口、sourcemap 留 5 版。④ OpenResty 真错误日志在 `/usr/local/openresty/nginx/logs/error.log`，不是 `/newworld/logs/web/`。相关 [[feedback_secrets_env_diff_baseline]] [[reference_feed_native_scroll_flicker]]。
