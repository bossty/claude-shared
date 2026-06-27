---
name: newworld-edge-bootstrap-cert
description: Edge VPS 新机上线必跑 scripts/edge-bootstrap.sh（acme.sh + wrapper + secrets 0640 + known_hosts + authorized_keys + SSL 目录预建）；SNI 证书必须 root:nogroup 0640 私钥（openresty worker 跑 nobody，通过 group 读），acme.sh 默认 0600 root:root 会触发 TLS alert 80；fullchain.pem + privkey.pem 命名对齐 SNI loader。Triggers on edge vps, edge-bootstrap.sh, bootstrap, acme.sh, acme wrapper, known_hosts, authorized_keys, sni, sni_loader, privkey.pem, fullchain.pem, root nogroup 0640, alert 80, openresty worker, ssl certificate permission, install -m 0640.
---

# Newworld Edge VPS Bootstrap + SNI 证书铁律

## 触发场景
- 新 edge VPS（aws-s / usca-X / 任意 P 域用 edge）首次上线
- 部署 acme.sh / 续签证书 / 改 SNI 证书目录
- 排查 TLS alert 80 / SSL_ERROR_RX_RECORD_TOO_LONG
- 改 OpenResty `ssl_certificate_by_lua` / `sni_loader.lua`

## 1. Edge VPS Bootstrap 强制清单

**背景**：Wave 8 boldpoint395.com 累爆 12 根因，90% 是 edge 侧 bootstrap 漏项 — acme.sh 未装 / wrapper 未部署 / known_hosts 缺 IP / authorized_keys 缺 admin pubkey / secrets 权限错 / SSL 目录未预建 / wrapper 写 `.cer` vs SNI loader 读 `.pem` 不对齐。

铁律：
1. **新 edge VPS 必跑 `scripts/edge-bootstrap.sh`**，幂等含 7 步：
   - 创 newworld user
   - acme.sh 安装
   - wrapper 部署（`/newworld/scripts/acme-sh-wrapper.sh`）
   - secrets 0640 root:newworld
   - known_hosts hostname + IP 双扫
   - authorized_keys admin pubkey
   - openresty SSL 目录预建
2. **不 bootstrap = 上线阻断**：runbook 必须 verify bootstrap 产物就位（`/home/newworld/.acme.sh/acme.sh` / `/newworld/scripts/acme-sh-wrapper.sh` 等）
3. **admin ↔ edge 契约**：cert 产物文件名统一 `.pem`（`fullchain.pem` + `privkey.pem`），SNI loader hardcode 行号是真相源
4. **改 PurchaseConfig / enum 值**：必 grep 全仓 filter/match 点同步（如 `triggerCertForPendingSDomains` `purpose='provision-s'` 过滤）
5. **CNAME tunnel 路径 (`configureWebZone`) 与 edge 直连 (`provisionSingleDomain`) 显式隔离**：S 域必走后者，Java 代码 guard + javadoc `@deprecated`

## 2. SNI 证书 group 权限

**背景**：boldpoint395 / silvernest26 持续 `SSL alert 80 tlsv1 alert internal error`。表层 cert 文件都在，error log 真相：
```
[sni_loader] cert found but key missing host=boldpoint395.com
err=.../privkey.pem: Permission denied
```
根因：openresty worker 以 `nobody:nogroup` 跑，acme.sh 签完默认 install 是 `newworld:newworld 0600` → worker 读不了私钥 → 返空 → alert 80。

铁律：
1. **SNI 证书文件权限必须对齐 worker user**：
   - `fullchain.pem`：`root:root 0644`
   - `privkey.pem`：**`root:nogroup 0640`**（group 必须 `nogroup`，worker `nobody` 通过 group 读）
2. **acme.sh / certbot 签完不自动 chown**：deploy-hook / install 命令显式 `install -m 0640 -o root -g nogroup privkey`
3. **runbook 必验权限**：签完 `ls -la /usr/local/openresty/nginx/ssl/<host>/` 确认 privkey 是 `root nogroup 0640`，否则 reload 后 alert 80
4. **sni_loader 扫两个路径**：`LIVE_ROOT=/usr/local/openresty/nginx/ssl`（主）+ `FALLBACK_ROOT=/etc/letsencrypt/live`（兜底）。**acme.sh home 的 `~/.acme.sh/<domain>_ecc/` sni_loader 不扫**——必须 install 到 LIVE_ROOT
5. **诊断**：握手挂第一时间 grep `sni_loader` openresty error.log，不要瞎改 cert / reload

## 检查清单
- [ ] 新 edge VPS：`scripts/edge-bootstrap.sh` 跑过，7 步产物全在
- [ ] cert 文件名是 `fullchain.pem` + `privkey.pem`（不是 `.cer` / `.crt`）
- [ ] `ls -la <ssl_dir>/<host>/privkey.pem` = `root nogroup 0640`
- [ ] cert 在 `LIVE_ROOT=/usr/local/openresty/nginx/ssl`，不只在 `~/.acme.sh/`
- [ ] TLS 挂时第一步 grep `sni_loader` error log

## 违反后果
- bootstrap 漏跑 → 新域上线后 acme 签证书失败 / cert 没 install / TLS 握手挂
- privkey 权限是 `root:root 0600` → worker 读不了 → alert 80（生产用户 SSL 错误）
- cert 文件名 `.cer` 而非 `.pem` → SNI loader 扫不到 → 返空 → 同样 alert 80
- 不看 sni_loader error log 瞎改 cert → 浪费 1+ 小时 debug
- 上述任一项 = **3.25 级别**复盘

## 源
- CLAUDE.md L538-L552（edge VPS bootstrap）
- CLAUDE.md L836-L856（SNI 证书 group）
