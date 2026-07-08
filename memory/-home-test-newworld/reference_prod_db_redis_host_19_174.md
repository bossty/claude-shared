---
name: reference_prod_db_redis_host_19_174
description: prod DB+Dragonfly 现行内网 IP = 172.31.19.174（5/28 重建后），CLAUDE.md 旧写的 .16.161 已死；服务器真值必查 /proc/PID/environ
metadata: 
  node_type: memory
  type: reference
  originSessionId: d040d32b-2e98-4c95-acc0-220cd4d6d6b9
---

> **⚠️ 2026-07-07 状态标注**：三个 HK IP(.19.174/.16.161/.27.200) 终态架构 B 后全死；终态 DB=172.34.1.222/Redis=172.34.1.128。保留价值=查 /proc/environ 铁律 + 硬编码 IP latent bug（仓库 ~10 脚本仍中招）。

# prod DB/Redis 真值 = 172.31.19.174（aws-db-poc 重建后）

**真值（2026-05-31 实测）**：prod MySQL + Dragonfly 同机在 **`172.31.19.174`**（aws-db-poc，PTR `ip-172-31-19-174.ap-east-1.compute.internal`）。admin 进程 `DB_HOST=REDIS_HOST=172.31.19.174`；`.16.161:3306` 已死（closed）、`.19.174:3306` OPEN。

**历史 IP 链（均已退役）**：
- `172.31.27.200` aws-db（t3.xlarge，5/27 迁移前）
- `172.31.16.161` aws-db-poc（5/27 迁移目标，**5/28 灾难重建前**）
- `172.31.19.174` aws-db-poc（**5/28 灾难重建后，现行**）

**教训（owner 2026-05-31 点出）**：CLAUDE.md + AWS_HK_DEPLOYMENT.md 一直写已死的 `.16.161` / `.27.200`，是 5/28 重建后没同步的 **stale 文档**（commit `f60eb929` 已修 durable 档；历史 sprint 档不改写）。**铁律：服务器连接真值（DB/Redis host、port、token）必查 `sudo cat /proc/<MainPID>/environ | tr '\0' '\n' | grep DB_HOST`，CLAUDE.md 写了 ≠ 真值**。MainPID 用 `systemctl show <unit> -p MainPID --value`。datasource 用户名在 `application-prod.yml`（=`newworld`），DB_PASSWORD 在 env，CF_API_TOKEN_B 不在 env（在 system_config 表）。

**2026-05-31 全量 stale IP 清扫（commit `a5940b2f` + 后续）**：
- 实测真值（IMDSv2）：aws-web-01 public `43.198.206.231`、aws-web-02 `43.198.240.144`、aws-data `18.167.41.192`（internal 全稳定 .27.120/.121/.130）。**aws-* 非 EIP，public IP stop/start 会变，仅 SSH 用（回源走 CF Tunnel），以 IMDSv2 实测为准**。
- 修了 9 个 durable 档的死 IP（CLAUDE.md / AWS_HK_DEPLOYMENT / AWS_MONITOR / AWS_S_INFRASTRUCTURE / EDGE_VPS / NEW_SESSION_PROMPT / P_POOL_GLOBAL_SHARED / SHORT_LINK_PLAYBOOK / S_ENTRY_LUA）；历史 runbook/plan/sprint 档不改写。
- ⚠️ **secret 泄漏**：`docs/NEW_SESSION_PROMPT.md` 曾含明文 DB 密码入 git（已改占位符 `$DB_PASSWORD`，但 **git 历史仍含**，owner 决定密码轮换+历史清理"先不改"，遗留待办）。
- 🔴 **W4-CRAW 工具 latent bug**：`tools/tag_dict_filler.py` 的 prod-DB 安全护栏 `if host in ("172.31.27.200","18.166.209.100")` **不含现行 .19.174 → 对真 prod 库静默失效**；`config.py`/`export_runner.sh` 默认 DB_HOST 兜底仍是死的 .27.200（带 env 跑才正常）。**教训：DB 迁移后必 grep 全仓库硬编码 IP 护栏/默认值，不止改文档**。

关联 [[feedback_secrets_env_diff_baseline]]（/proc/environ 验真注入）、[[project_db_migration_2026_05_27]]（5/28 灾难重建全文）、[[reference_cf_waf_referer_skiplist]]。
