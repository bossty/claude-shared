---
name: project_full_code_audit_closure_2026_07_04
description: 全代码审计(~113条)完整收口 07-04/05——backlog/openresty/relay证书pin/低价值6项修复+误报19项归档suppressions;含可复用技术pattern
metadata:
  type: project
---

# 全代码审计完整收口（2026-07-04/05）

接 [[project_p1_security_batch1_2026_07_03]]（批次1/2 P1）。本会话把 ~113 条审计**全部收口**（批次3-14）。真相源 `docs/sprint/2026-07-02-full-code-audit/`（FINDINGS.md 113条 + P2-VERIFICATION-batch4/5.md + SESSION-STATE.md）。

## 最终分流（master 基线 `d865af5b`+）
- **已修+部署验证**：P0×2 + 全 CONFIRMED P1 + P2 主批~29 + backlog 12（含中危 P2-29 JWT吊销）+ openresty(P1-19/20+lua P2×8) + P2-41 relay证书pin。
- **已修+测过+待搭便车部署**（Owner 06:00排程取消改搭车）：低价值 6 项 P2-46/54/68/20/43/33，合 master `35f291af`，照 `DEPLOY-RUNBOOK-p2-cleanup.md` 搭下次 data/admin/fe-web/fe-admin 任一面部署时上。
- **误报归档 suppressions**（19条 REFUTED/DUP + P2-67过度工程，合 `5ab28b6e`）：审计遇到直接跳，防重报。
- **待自然验证**：Kanav 封面（见 [[project_kanav_health_cover_fix_2026_07_04]]，无cron待crawl-pages）。

## 可复用技术 pattern（跨会话价值）
- **relay 证书 pin（P2-41）**：连自签证书 relay（buyvm-data:443 nginx 反代 OpenAI，证书 `/etc/nginx/ssl/openai-relay.crt` CN=buyvm-openai-relay 2036到期）禁 trust-all。改**SHA-256 指纹 pin**（`RELAY_CERT_SHA256_PIN` 编译进 jar 的常量，运行时零文件依赖，比 truststore 文件轻）；主机名校验因 CN≠IP 仍关但证书 pin 死。**部署前必 `openssl s_client` 实测 relay 出示证书指纹==pin**（否则 LLM 全断），部署后等一轮爬取真验 LLM 标题翻译成功+pin/TLS失败=0。证书轮换需改常量重部。
- **openresty edge 三面部署**：guard.lua 在 `web/`+`admin/`（源站，非 edge/）。**web guard 的 L7 限流自 5/22 起死代码**（CF 注入自身 edge IP→同 POP 共享桶 5min 误杀 8547 次），**admin guard 限流仍活**（444行 role=web）。**lua 改动需 systemctl restart（reload 不重 require lua）**。逐节点 nginx -t→restart→smoke，rsync --delete 前先 dry-run 防误删。P1-19 root_host key 塌缩防随机子域灌爆 ssl_certs（专项 smoke：200随机子域 delta=0）。
- **LLM 批量对齐（P2-43）**：结果按数组下标对齐输入有重排/丢+重复错配风险；**不能按 title 交叉校验**（system prompt 任务1"优化标题改写简体中文"=LLM 重写 title 非回显）→ 让 LLM **回显输入 index**，按 index 稳健重排；向后兼容（无 index 回退数组序零回归）。
- **race-safe 收尾 pattern**：P2-20 Redis 读后无条件 DEL→**条件删 Lua**（删时仍空才删，防读-删窗口新写被抹）；P2-54 localStorage 无原子 CAS→**token 写后 re-check 选主**（竞态窗口缩到 µs）。
- **删资源前查引用（P2-33）**：删 R2 图前查 `snack.encrypted_image_url` 引用防裂 live 广告（IDOR 核心证伪=内网无 per-admin 归属，此为在用资源防护非越权）。

## 方法论收获
- **蓝军优先证伪逮到多处 finding 误判**（因果说反/前提事实错/约束已限死）：P2-21/23/49/38/83/68 等 19 条。审计报告本身必抽样 fact-check。
- **"过度工程"是合法结论**：P2-67 乐观锁需多实体 schema 迁移+全栈冲突UI，单操作员内网不成比例→suppress 不硬修（Owner"全修吧"下仍诚实保留，作独立 sprint 立项）。
- **低价值≠难**：P2-20 我一度把"麻烦"说重，实为 4 行条件删 Lua，真因是价值低（≤1曝光）非难度——被 Owner 追问逼出诚实复盘。
