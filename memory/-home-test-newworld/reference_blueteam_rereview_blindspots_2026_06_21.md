---
name: reference_blueteam_rereview_blindspots_2026_06_21
description: 蓝军二轮复核（已部署代码）四盲点 + lead二查裁决法：reviewer只有git视野盲于会话内live ops/机制描述可能错/回归vs漏网必git溯源定severity/odd-one-out vs已确立决策=真bug
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 85dc3fe1-5403-474d-941b-c0f0f36ee859
---

2026-06-21 redis-cleanup sprint 对**已 commit+已部署**代码做第二轮蓝军复核（独立 reviewer agent，独立 context），lead 二查 5 条 findings 时反复出现的盲点与裁决法。延伸 [[feedback_multiagent_prod_ops_auth_backstop]] 的"lead二查抓虚报"通则到 re-review 场景。

**Why**：reviewer agent 工具集只有 Read/Bash/Grep + git，**看不到 main session 已做的 live ops 动作、也不带 main session 的判断**——这是它独立性的来源（避 groupthink），也是它系统性盲点的来源。lead 不二查直接采信 → 要么误修已解决项、要么按错误 severity 行动。

**How to apply**（每条 finding 落地前 lead 必核）：

1. **"X 未执行/未确认" 类 finding → 先对账本会话已做动作**。本轮 FINDING-4「UNLINK 未执行、3.24GB 没回收」是**部分误报**：UNLINK 我本会话早执行过（2016→0 master + EU replica 0 都验过），reviewer 的 git+code 视野根本看不到运行时 ops。凡 reviewer 报"某 ops 步骤没做"，先查会话历史是否已做，别盲目重做。

2. **reviewer 的机制描述可能不准 → lead 读真代码精炼**。FINDING-2 reviewer 暗示"compute() 纯 Redis 写"，实际 L94 有 DB 读（`movieActorMapper.findEnabledActorsForPagination`）→ `@Transactional(readOnly=true)` 不是无意义，真正违规点是**Redis 写被包进 readOnly DB 事务**。finding 方向对、机制错；lead 读码后 severity/修法才准。

3. **回归 vs pre-existing 漏网 → 必 `git log -S` / `git show <sprint-base>` 溯源定 severity**。FINDING-2 看着像本 sprint 引入，实为 hotfix `9c5265b3` 引入、sprint base `5bd649c6` 就有 → 是 pre-existing 漏网项不是本 sprint 回归。这直接决定：要不要紧急回滚（回归才回滚）、改动算不算 scope creep（pre-existing 修它需 owner 拍板，本轮 owner 选"现在一起修"）。

4. **"odd-one-out vs 已确立决策" = 高价值真 bug 信号**。FINDING-2 之所以是真 bug：grep 两个兄弟服务发现 GlobalFeedPoolService L109-111 有明确注释记录 **5/26 P0-2 就因同一条铁律删了 `@Transactional(readOnly=true)`**，TagCategoryPool 从来没有 → ActorPool 是唯一漏网。对照已 documented 的同类决策找落单者，比抽象推理更能锁定真问题（即便运行时当前无害——admin 单实例无读写分离）。

**配套技术 gotcha（同 sprint，高复用）**：
- **Dragonfly EVAL 比 Redis 严格——脚本内 `redis.call('KEYS',...)` 拿到的 key 必须预先声明，否则报 `script tried accessing undeclared key`**。批量删 key 别用 `EVAL "KEYS+UNLINK" 0`，改**客户端 SCAN + 分批 UNLINK**（本轮 2016 key 分 500/批 5 批清空）。ca-admin 无 redis-cli/redis-py/pip → 用原生 socket RESP 解析器（AUTH→SCAN cursor 循环→UNLINK），读密码 `sudo cat /etc/newworld/secrets.env`（注意 `source` 在 ssh 非交互 shell 读不到，必 sudo cat）。
- 主从清理只需动 master：Dragonfly 复制自动把 UNLINK 传到 replica（EU .184 验证 0），**不要手动清 replica**。
- `mvn -q` 会把 `Tests run:`/`BUILD SUCCESS` 汇总行也吞掉 → 拿明确计数必去掉 `-q`（exit 0 已是 surefire 全过的权威信号，但铁律"验完确认非空输出"要可见计数）。
