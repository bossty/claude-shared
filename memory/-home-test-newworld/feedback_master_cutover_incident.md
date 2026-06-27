---
name: feedback-master-cutover-incident
description: master cutover(HK→CA)事故教训——502/503先查SG/network非DB只读、cutover回滚必undo fence、dry-run测不出执行期连通失败
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-12 Phase D(MySQL master HK→CA cutover via cutover-ws1.sh)失败事故，lead 连犯诊断+回滚错误。跨会话可复用教训：

**1. region web 批量 502/503 → 先查"被挡在 DB 外"(SG/network 层)，不是 DB 只读。**
- 真因:cutover fence revoke 了 HK master SG `0.0.0.0/0:3306` → region web 在 172.34(CA)网段连不上 HK DB(DB_HOST=HK) → 新建/重连 DB 连接全失败 → 502/503。已有连接还撑着 → 部分 200 误导。
- **DB super_read_only=ON 不挂用户读路径**:region web 读接口纯 SELECT 在只读 DB 照常 200;它的 stats 写是 @Async DiscardOldest(静默丢);只 admin 调度任务(RedirectTraceConsumer)的同步写撞 1290 只读错=非用户面。
- **Why**:lead 第一时间凭 owner"全挂"想当然怪 DB 只读、没分层验证(region web vs admin)、没查 SG/network 连通。owner 反诘"纯读为啥挂"才查对。
- **How to apply**:502/503 诊断顺序=① ssh 该层节点真测到上游(DB/origin)的 TCP 连通 ② 看是 5xx(gateway/连不上)还是 app 异常 ③ 分层(哪类节点/哪个域)。别凭一句"挂了"定因。[[feedback_verify_not_recall]]

**2. cutover 中止/回滚 必须 undo fence(SG re-authorize)，只解冻 master 不够。**
- fence=`aws ec2 revoke-security-group-ingress ... 0.0.0.0/0:3306`。回滚只做了 `SET GLOBAL super_read_only=OFF` → app 仍连不上(SG 还挡着) → 502 拖长 + 过早宣称"恢复"。
- **How to apply**:cutover 脚本 abort/回滚路径必含 `authorize-security-group-ingress` 把 fence 的 CIDR 加回。手动回滚 checklist:解冻 master + re-authorize SG + 重启被停服务 + 验真连通(非只看首页 200)。

**3. dry-run 测不出执行期连通/工具缺失失败。**
- 本次卡死 S5:Redis 主机(Dragonfly)没装 redis-cli + 脚本本地跑 redis-cli 够不到内网 Redis IP → S5 死循环 → S6 从没跑。dry-run 只打印不执行,测不出。
- **How to apply**:PONR 脚本重试前,对每个"调外部工具/连内网资源"的步骤单独真测(redis 连通+REPLICAOF、DB CHANGE SOURCE、SG 改、ssh 各 DB 主机)。Redis 无 cli 时用 `ssh <redis主机> python3` raw-socket 发 RESP(AUTH+REPLICAOF,已验可行)。

**4. "恢复了"必须验真功能、多次、多域,别只看首页/单接口 200。** 首页是静态 SPA、缓存连接撑着的接口都会给 200 假象。owner"只看首页当然 200 了"是对的。
