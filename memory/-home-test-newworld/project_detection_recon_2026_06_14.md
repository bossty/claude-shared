---
name: project_detection_recon_2026_06_14
description: 反发现调研→暴露面盘点→整改→全量上线 sprint（GFW发现路径地图+probeGate删除盲点+接口明文后门+整接口加密上线）
metadata: 
  node_type: memory
  type: project
  originSessionId: ed36f894-57b3-4f1e-b7f5-2b5f59c3a13c
---

2026-06-14/15 多 agent sprint：调研中国 GFW/网监/浏览器如何**发现**站点含成人内容 → 盘 newworld 暴露面 → 整改 → 全量上线。产出 docs/sprint/2026-06-14-detection-recon/。

**发现路径地图（顶层逻辑）**：「发现/定性」与「封锁/执行」是两层人马。**GFW 网络层只是执行器**（DNS注入/IP黑洞/TLS SNI 明文查表），**没有实时判黄能力**，只执行别处离线判好的黑名单。**发现几乎全在内容层 AI 鉴黄 + 人工层**。发现权重排序（境外部署前提）：①群众/竞品举报(12377/12321,极高) ②搜索引擎/百度安全中心爬取 ③**CT 证书透明日志**暴露新域名(签证书即暴露,推广前就中) ④微信/QQ分享被腾讯安全云库扫 ⑤网监专项行动 ⑥境内支付/引流产业链(境外部署则低)。封面/预览**图**最先被鉴黄；图鉴黄=CNN多分类(porn/sexy/hentai),商用API(阿里绿网/腾讯IMS/网易易盾/百度/数美)。

**暴露面真发现**：① **★probeGate 探针伪装页已于 commit e8135159(5/12) 删除**，但 CLAUDE.md/skill 仍宣称存在=全队认知盲区（已校正 CLAUDE.md）② **9 个首屏接口 @SkipEncrypt 明文**：直接 `curl https://17.rip/api/v1/courses/featured` 无referer→200 裸中文成人片名，探针(前端)对这层零作用=后门 ③ HSTS preload 主动把 S 短链域提交 hstspreload.org 公开 list（edge nginx.conf:211 Owner 5/21 拍板）④ 百度 hm.js 三重注入主动喂百度 ⑤ P/S 共 CF 账号 9a1d6632 ~31 zone=爆炸半径。**支付/收款用户侧近乎零=结构性优势**（无 CPC/CPM/billing）。

**已上线（commit 712bc10e, 前端 version ede838de, 全5节点CA×3+EU×2）**：D=整接口恢复 @EncryptResponse 于 topics/subjects/courses-list（settings 明文）+ **BV3-1 WASM gate 原子解耦**（main.js fire-and-forget + fetch.js await ensureReady）+ 探针折中C(probeGateLite 轻量门,选项C)+ B referer 闸门 log-only 灰度 + D4 撤百度被 Owner 否(hm.js 保留)。端到端实证：真 prod 加密 taxonomy 解密渲染零控制台错误。详见 [[reference_api_encryption_lcp_backcompat]]。

**移出 backlog**：D3 拆 P/S CF 账号(爆炸半径运维非反发现,但能力代码已建好 CloudflareApiService getTokenByAccount("S")+S_ACCOUNT_ONBOARDING.md) / D5 HSTS preload S 域(抵触 5/21 拍板待重判) / B 切 enforce 前必修 referer 白名单 `.link/.top` TLD 通配 + /actors·/tags/categories 漏保护。

**P0-3E 续(2026-06-15 上线)**：Owner 追问"还有未加密接口吗/snack 那么多关键词/settings 高危测过吗"→补 snack/list + settings(ConfigController) 加密 = 当年 9 接口 **9/9 闭环**；EXCLUDE 3 个非前端消费有意明文+落注释；揪出 **BV5-1**(app-config.js decryptResponse 同 BV3-1 遗漏面，config 加密裸部署=白屏)修复。canary→smoke(隧道打单节点全栈验白屏)→fleet 全 5 节点上线，真 prod 端到端零白屏。加密机制细节见 [[reference_api_encryption_lcp_backcompat]] ⑤⑥。

**LIVE 状态**：线上跑 worktree 分支 feature/probe-lite-web(5b87d66d探针+712bc10e B/D/D4+cf90bf34 P0-3E+2bc1efc8 BV5-1) **未 push origin**；origin master 另有别 session 的 newworld-data commit(5e4f579a jable/HLS/geo-block)我没 merge/背书。**待 Owner 定何时 push 我们这批**。部署一路踩坑教训见 [[feedback_local_build_deploy_no_push_pitfalls]]。
