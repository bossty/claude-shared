---
name: Newworld 项目全景
description: Newworld 视频平台完整项目概述，包括架构、模块、部署、Sprint 状态
type: project
originSessionId: 6d0b5de8-05de-4add-839f-f3754720cad2
---
# Newworld 项目概述

## 项目性质
多模块视频平台，Spring Boot + Vue 3，4 后端服务 + 2 前端应用，目标 100 万 DAU / 500 万 DAU 中期。

## 后端模块

| 模块 | 端口 | 职责 |
|------|------|------|
| newworld-common | - | 共享实体/DTO/Mapper/两级缓存 |
| newworld-web | 7777 | 用户前台 API（无状态，纯读 + 统计写 Redis） |
| newworld-admin | 8888 | 管理后台 + 统计管道 + DNS 自动摘除 |
| newworld-data | 9999 | 爬虫服务（Jsoup + Playwright） |

## 前端
- frontend-web（:5566）— Vue 3 + Vite，用户端
- frontend-admin（:6655）— Vue 3 + Element Plus，管理后台

## 部署架构

### AWS ap-east-1a（线上主集群）
- aws-web-01（18.167.42.216）+ aws-web-02（43.199.163.153）— web + frontend-web + OpenResty + cloudflared (A/C/P tunnel)
- aws-data（16.162.253.75）— admin + data + frontend-admin + OpenResty + cloudflared (Admin tunnel)
- aws-db（18.166.209.100，内网 172.31.27.200）— MySQL + Redis
- **aws-monitor（16.163.94.193）— N9E v8（n9e.17.rip）+ VictoriaMetrics :8428 + categraf；alert rules /newworld/ops/n9e-alert-rules.yaml**
- aws-s（95.40.168.207）— S 域 edge VPS（Lua SNI 证书池）
- usca-1（67.230.182.105）+ usca-2（67.230.161.24）— S 域 edge VPS（美西，反 GFW 备份）

### BuyVM（离线 / 重计算，SSH 用户是 test 不是 newworld）
- buyvm-web-01（209.141.57.183，4 核/15Gi/315G）— 首选 ffmpeg backfill 节点
- buyvm-web-02（205.185.115.35，同规格）— 备用 backfill
- buyvm-data（209.141.48.177，2 核/7.8Gi/79G）— 爬虫批处理
- buyvm-db（209.141.57.119，4 核/15Gi/315G）— 离线 DB 备份（schema 变更不自动同步，需手工跑 migration）

## 关键特性
1. **视频分发 v3 全静态**：R2 自定义域直连，相对路径 m3u8，前端 cdn-failover.js 多域名 failover
2. **CDN 配置键**：R_VID（视频）/ R_IMG（图片）/ R_PRV（预览）
3. **两级缓存**：Caffeine L1 + Redis L2，@Cacheable/@CacheEvict
4. **API 伪装**：Web 路径用教育主题（movie→course, actor→instructor）
5. **AES 加密响应**：@EncryptResponse + WASM 解密
6. **探针检测**：WASM detectProbe，自动化浏览器渲染 EduStream 伪装页
7. **GFW 应对**：CF Tunnel 回源 + S/P/A 三域体系 + DoH + Relay
8. **百度统计**：hmId 归因 + 渠道分析

## Sprint 状态（2026-04-21）
- Sprint 1（灰度 5%→100%）：进行中，Sprint 1 收官 2026-04-24
- Sprint 2（推广渠道隔离 + P0 清零）：大半完成（TP-07/01/05/OPS-01/02 全 ✅）
- **v3.3 架构**（2026-04-21 Owner 拍板）：渠道独占 S 域 + Lua SNI 动态证书 + acme.sh 多 CA，P0 救火阶段（3-5 天）
  - 5 .com 新采购 + schema 允许 S 绑定 + Lua SNI POC + 采购拨测 API

## 凭证规范
- 生产凭证不入 git，存 `/etc/newworld/secrets.env`（0600），systemd EnvironmentFile 注入
- 强 secret：DB 密码 / N_RS / JWT_SECRET / R2 Key / CF API Token / GW_JWT_SECRET
- 弱签名（公开）：N_AGS（防傻瓜爬虫，非 secret）

## Why
进入 v3.3 阶段的原因：v3.2.4 Phase 0 暴露 5 .cc S 域 3 天被 GFW DNS 污染，多渠道共用 S 域传染面大，脚本手工流程繁琐。
How to apply：新功能涉及域名/渠道/S 域时参考 S_P_ARCH_V3_3.md 的 12 决策锁定表。
