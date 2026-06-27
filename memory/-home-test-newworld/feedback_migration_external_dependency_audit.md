---
name: feedback_migration_external_dependency_audit
description: 迁服务到新机/新OS必审外部依赖三件套(本体+可达性+IP白名单);+ geo-block修复验证的signed-URL时效陷阱 + grep实代码抓plausible-wrong默认值
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ce27c9bf-720e-4350-ba00-8892b604bf34
---

迁移工程(服务搬机房/换 OS/换 region)后,排查"采集/下载/外部调用出问题"先怀疑**外部依赖没跟着迁**,而非应用 bug。

**铁律一:env 迁了 ≠ 依赖迁了。迁服务必审"外部依赖三件套":**
1. **依赖本体**:docker 容器(如 FlareSolverr)、二进制(gif2webp/node/javxx-m3u8/acme.sh)、本地服务(tinyproxy/MySQL)是否真在新机跑。
2. **网络可达性**:新机能否连到目标(私有 VPC IP 跨公网不可达;SG 入站规则;EIP vs 动态 IP)。
3. **IP 白名单/ACL**:目标侧是否放行了新机出口 IP——注意**两层 ACL(防火墙 UFW + 应用层 tinyproxy Allow / nginx allow)要同时改**,只改一层=包进得去但被应用层拒(curl 返 000)。
**Why:** 2026-06-15 data 每小时采集 3 个断点全是这一类(tinyproxy ACL 漏改一层 / FlareSolverr 容器没装 / buyvm yml 指死 HK IP),见 [[project_data_hourly_collection_fix_2026_06_15]];Phase F 也漏装过二进制 [[project_hk_web_retirement_2026_06_13]]。
**How to apply:** 迁移后扫所有 ProcessBuilder/exec/docker/@Value 外部端点;`ss/docker ps/systemctl` 查依赖本体;`nc -vz` 测可达;两层 ACL(ufw status + 应用 conf)对照查。

**铁律二:验 geo-block/防盗链修复,signed-URL 时效是混淆变量。** wowstream/hanime 等 m3u8 是时效签名 URL,过期后任何 IP 都 403。验证必须**同一新鲜 URL、直连 vs 代理、背靠背对照**(直连403→代理200=代理真有效)。用过期 URL 测会把"过期403"误判成"代理也被封"。
**Why:** 蓝军 F1 BLOCKER"代理也 403"就是测了过期 URL 的误报,lead 同 URL 对照证伪。
**How to apply:** 从最新日志取 URL 立即测,且必跑直连+代理同 URL 对照,别单测一条就下结论。

**铁律三:验 agent 交付别信自述,grep 实代码 + 钉真实生产值测试。** dev 默认值常 plausible-but-wrong(`wowstream.cc` vs 真实 `wowstream2.cloud`),部署即回归。
**Why:** lead grep 出默认域不匹配真实下载域,拦下部署级 BLOCKER;另一次诊断 agent 看错 F5 前的旧 worktree、把"GeoBlockedException 类不存在"当前提,被 lead `git grep <master-sha> -- file` 实证仲裁(agent 的 worktree 基线/文件路径会错,锚定 commit sha grep 才权威)。
**How to apply:** 收 agent 代码先 `git grep` 关键符号/默认值,且断言里钉**日志里的真实生产 host/URL**(如 `cache-xx11.wowstream2.cloud`)做防回归锚,别用构造样例;agent 报"X 不存在/机制是 Y"与你已知事实冲突时,先 `git grep <sha>` 核它看的是不是错文件/旧 worktree。

**铁律四:修复上线后必观察真实运行数据——isolated-test-pass ≠ production-scale-pass。** 单条/突发/并发 curl 全 200,不代表生产规模零失败;反之生产残留失败也未必是修的东西没用(可能是同类的另一处漏网)。
**Why:** wowstream 代理 ACL 修好后,单测全 200 但生产仍 ~200/小时失败;观察运行数据才发现 F5 的 host 白名单门控把无法枚举的轮换 CDN(.store/.space/.site)+ validate 首段步骤漏在代理外(F5"改进"自身引入的覆盖收窄回归)。
**How to apply:** 部署后开 watcher 对比 before/after 关键业务指标(如最终失败率)而非只看健康 UP;善用埋点反推(F4"代理兜底也失败=0"直接证明"走到代理的都成功,失败的全是没走到代理的"→定位到路由门控而非代理本身);改"收窄触发条件"类优化要警惕漏掉无法枚举的长尾(轮换域名→宁可放宽触发也别逐一枚举白名单)。
