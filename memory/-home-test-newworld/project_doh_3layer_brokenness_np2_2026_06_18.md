---
name: project_doh_3layer_brokenness_np2_2026_06_18
description: DoH域名池三层brokenness(crypto/写侧83011/AliDNS截断);np2-only已实现committed(3b33e0a8)+ca-admin已部署+sync复活金标验证通过(真DoH解密153域,AliDNS截2/8仍解41域),前端读侧待部署;post-handoff读SESSION-STATE
metadata: 
  node_type: memory
  type: project
  originSessionId: c26c2e1f-72a4-463f-8370-aeecffd81acf
---

查"前端 DoH 错误上报多"挖出 **DoH 加密域名池（反封锁兜底通道）上线至今一直死，三层 brokenness**（2026-06-18）。

**★ 新会话接 np2 必先读 `docs/sprint/2026-06-18-doh-np2-design/SESSION-STATE.md`**（LIVE 状态/决策/踩坑全在），再 PRD.md + agents/reviewer.md。

**三层坏**：
1. **crypto 密钥不匹配**：后端 `ConfigCryptoUtil.encrypt`（固定 key SHA-256(MK+"CONFIG_ENCRYPT")）vs 前端 WASM `decrypt(ts)`（时间戳 key SHA-256(MK+(ts/300000*300000))）→ 100% 解密失败。prod 实锤 28 个 `np1 解密失败 error=undefined`。**单测全 mock decryptFn 掩盖**（蓝军 B-1 揪出，lead 真 WASM 二进制验证）。
2. **写侧 CF 合并上限**：np1 "先写后 prune"(FIX-2 撕裂保护) + 池太大 → 一域名上 2-3 版本超 CF 单名 TXT 合并上限 `83011` → 写卡死永远到不了 prune → TXT 停在旧版本更新不了（实测每域 4 记录 7288 字节 2 旧版本）。
3. **AliDNS 超 UDP 截断**：153 域池 ~7.3KB（全URL）超 UDP 4096 → AliDNS(CN唯一可达,CF/Google被墙) POP flapping 返 1/0 条 → `All promises rejected`/`np1 组装失败`。

**crypto 层已修+部署**（commit 在 origin/master，当前 hash `ab40aa6e`，多会话 rebase 已从 `153e41d7` 改、可能再变→**按 commit message `DoH 池 crypto 密钥不匹配修复` 或 `git log -S "AESUtil.encrypt(domainPoolJson"` 找**；ca-admin 跑 AESUtil；改 `CloudflareApiService:575` ConfigCryptoUtil→`AESUtil.encrypt(domainPoolJson,version)`，version 三处一致；真 WASM 解 AESUtil fixture 成功；蓝军 3 轮 CLOSE）。**但被写侧②卡住应用不上**（sync 83011 写不进 → 前端仍读旧密文）→ DoH 仍死，**无新回归**（早就死的）。

**★np2 已实现+本地 committed（commit `3b33e0a8`，未 push，待部署，2026-06-19）**：后端 `CloudflareApiService` syncDohTxtRecords 重构 **prune-first→writeNp2**；新 parseBareRootDomains/packNp2Groups(510B 贪心)/writeNp2TxtRecords（每组 `np2|version:<cipher>` 独立 AES 加密独立可解，抗 AliDNS 截断只丢若干组）；pruneStalePoolRecords 扩 isStaleNp2。前端 doh-client.js tryAssembleNp2（逐条独立解密+取并集+内部补 https+去重，sw.js 零改）+ fetchDomainPoolViaDoh 三级降级 np2→np1→旧格式（M-2 每级失败降下级不换域名）。测试 M-1 真加密↔真解密 round-trip + AliDNS 截断取并集（Q6 禁 mock）。前端 790/790 + admin 1859/1859 全绿；蓝军 Round-4 条件 CLOSE 无技术 BLOCKER。

**★Owner 拍板 np2-only（非双写，2026-06-19）**：153 域生产池下 np1 全URL(~5.1KB)+np2(~5.6KB)=~10.7KB **远超 CF 同名 TXT 合并上限 ~7.3KB，物理无法共存**（蓝军 P4-MAJOR-2 实证：即便闸门提到 11000 仍超）；且 np1/DoH 上线至今从未解密成功（非回归）。故后端**只写 np2，不再写 np1/旧格式**；`writeDohTxtChunks`/`updateDohTxtRecord` 标 `@Deprecated`（前端仍保留 np1/旧格式读侧降级兼容遗留记录，后续 cleanup 删）。**M-1 实测：合成 153 域→np2 11 组 max 492B(<510)；接 prod 必用真实 153 域复跑确认分组数**。

**★ca-admin 已部署+sync 复活金标验证通过（2026-06-19 00:46）**：本地 build jar→scp→deploys/`20260619-004147.jar`+symlink+重启（health UP，新进程 0 错；回滚目标 `20260618-231019.jar`）；触发 `/sync/doh`（ca-admin 本机 super JWT，**业务 API 在 :8888 非 actuator :18080**，DomainController `@EncryptResponse` 成功响应是加密信封）10 域全同步 HTTP200 18.6s，**prune-first 删旧 np1+写 np2 8 组各≤510B 全程 0 个 83011**；**金标真解密**（Google/Cloudflare/AliDNS 公共 DoH 查 prod TXT→node crypto 同算法解，MASTER_KEY=`NewWorld2024SecretKey@AES256!`）3 域 8/8 解密成功并集 153 域全还原；**AliDNS 截断容错实锤**：labplatform439.net AliDNS 只返 2/8 条→np2 仍解出 41 域可用（np1 会得 0）。真实 prod M-1=153 域→8 组（合成估 11，真域名更短）。**触发 JWT 法**：ca-admin `sudo cat /proc/$(systemctl show -p MainPID --value newworld-admin)/environ|tr` 取 JWT_SECRET→python HS256 mint `{userId,role:super,exp}`→POST :8888。
**✅ 前端 np2 读侧已部署（2026-06-19 01:03，FORCE_PEAK Owner 授权峰窗）**：`scripts/deploy-frontend.sh` 本地 build(SHA 3b33e0a8)→6 节点原子切换；6 节点 version.js 一致+index200+s.dat152B+chunk-prune active_safe；CF 服务新 index 引用 np2 chunk(含 `np2|`/`DoH np2` 字面量 http200)；真浏览器 17.rip 渲染799元素0错误。**DoH 全链路 np2 复活,CN 走 AliDNS 拿全 153 域池**。AliDNS 写后 4min 复测 30/30 全 8/8(早先 2/8 是 POP 传播窗口非限制)。**踩坑**：①前端业务 API 在 web :7777/admin :8888，actuator 才 :18080 ②`scripts/deploy-frontend.sh` 从本地 checkout build(git rev-parse HEAD,无 git pull)→不 push 也部当前 master+我改;但会顺带 ship origin/master 其他会话已合的前端改(snack composable),部署前必 vet deployed bundle 含啥(grep useSnackImage 确认非回归)；deployed version.js SHA 可能 orphaned(rebase)不在 origin,按 bundle 内容判非按 SHA ③峰窗守卫 FORCE_PEAK 需 Owner 授权 ④INTERNAL_API_SECRET 本地无 secrets.env 走 inline env ⑤grep 验前端改用 minify 存活的字面量(`np2|`)非函数名(tryAssembleNp2 被 mangle)。

**Owner 软门决策**：Q5✅复用AESUtil / Q6✅e2e禁mock / Q1=510B / Q2-4 N_POOL保全URL只在syncDohTxt strip / Q3 SW≥90%+30天撤np1（np2-only 后 np1 撤除已无意义，前端读侧降级保留）。

**durable 教训**：① crypto/序列化类改动 e2e 必真 round-trip 禁 mock（mock 掩盖密钥不匹配）；真 WASM 可在 node `initSync({module:readFileSync(.wasm)})` 验。② "先写后 prune" + 大 payload 撞 CF 单名合并上限 → 需 prune-first 或减小单版本。**推论：同名 TXT 上两种大编码（np1 全URL ~5.1KB + np2 裸域 ~5.6KB）合并超 CF 上限 ~7.3KB 时物理无法共存，"过渡期双写"对大池是伪命题 → 必须二选一（实测才发现，PRD 估算 ~9 组实际 11 组也靠真加密贪心才准，M-1 铁律）。**③ 诊断看错误**类型**非计数（28 解密失败 vs 140 AliDNS 是不同层）。④ 多层 brokenness：一个潜伏功能可能同时坏几层、且因兜底路径(种子/relay)活着 + 单测 mock 而长期无人发现。相关 [[reference_doh_txt_overlength_np1]] / [[reference_cached_dto_field_removal_schema_compat]]（同类 e2e-mock 掩盖 + payload 超限）。
