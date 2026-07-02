---
name: reference_frontend_deploy_checkout_npm_ci
description: 从 maven-only 部署 checkout 跑 deploy-frontend.sh 前必 npm ci（缺 node_modules build 必失败，但不碰生产）
metadata: 
  node_type: memory
  type: reference
  originSessionId: b08a1208-fdf5-4954-937c-d5db75882c23
---

deploy-frontend.sh 在脚本所在 checkout 的 `frontend-web/` 里本地 build。若该 checkout 是为后端 JAR 临时建的（如 `/home/test/newworld-master-merge`，只跑过 maven），**没有 `node_modules`** → vite.config.js 解析 `@vitejs/plugin-vue`/`vite`/`rollup-plugin-visualizer`/`vite-plugin-javascript-obfuscator` 失败 → `ERR_MODULE_NOT_FOUND` build error（连 vite 都缺，npx 会想现拉 vite@X）。

**安全性**：deploy-frontend.sh 是 build→`dist.new`→成功后才 atomic mv。build 失败发生在 "Step 1/web: 本地 dev build"，前面只跑 Step-0 SSH 可达性探测（只读）→ **没有任何节点 dist/ 被动**，live frontend 完好。

**修**：checkout 里 `cd frontend-web && npm ci`（package-lock.json 在），再重跑 `deploy-frontend.sh web`。

**坑2**：用 `... | tee log` 启后台时，pipeline 退出码是 tee 的（0），会掩盖脚本 set -e 的真失败。直接 `> log 2>&1` 重定向才拿到脚本真退出码。

实证：2026-06-29 GFW 整合后 web 层部署（merge 5ed76306），首跑 frontend build 失败=此因，npm ci 后重跑成功（s.dat=152B 全 6 台、atomic 无 0 字节窗口）。相关 [[feedback_local_build_deploy_no_push_pitfalls]] [[reference_ca_admin_deploy_model_2026_06_21]]。
