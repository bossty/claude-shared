---
name: newworld-cf-tunnel-edge-region-placement
description: 多 region origin 放哪、是否值得跨 region/跨 AZ 的实证方法论。触发：region 选址 / origin placement / CF 边缘 / cloudflared tunnel colo / 同 AZ vs 跨 AZ / us-west-1 vs us-west-2 / cf_ray 分布 / region HA 升级
---

> **执行机制**：靠判断力（region 选址实证方法论）

# newworld-cf-tunnel-edge-region-placement SOP

**来源**：2026-06-08 region HA 拓扑分析（fullcut-5xx 后续）。专家团队凭 anycast 理论判"跨 AZ 边缘多样性=伪收益"，owner 坚持实测——实测推翻了双方的简单结论。

> ⚠️ **2026-06-10 终态架构 B 部分推翻本 skill 的结论（非方法论）**：§1/§2 的"US 需俄勒冈+加州双 region"**未被采纳**——终态采**单加州 us-west-1×3 + 法兰克福 EU**，砍俄勒冈（perf 仅 SEA−7.6ms 软值 + edge≈0 撑不起 ~$280/月，见 memory `project_terminal_arch_B_single_california`）。**§0/§3/§4 的方法论（tunnel edge≠anycast 必实测 tunnel 层 / 确认轮 / cf_ray colo 罗盘 / colo-probe 实验法 / owner 直觉先当设计提案）仍全有效**；§1/§2 的具体选址结论已是历史，勿照搬。

## 0. 三条铁律（都来自踩坑）

1. **cloudflared tunnel 的 edge colo ≠ HTTP anycast colo（cdn-cgi/trace）**。`curl cdn-cgi/trace` 看到的 colo（HTTP anycast）粒度粗、按 region 出口固定（us-west-2 全 →PDX）；但 **cloudflared tunnel 的实连 edge 粒度更细、在都会区邻近 colo 间浮动**（实测 us-west-2 节点的 tunnel edge 在 PDX(pdx02/pdx03) 和 SEA(sea01) 间跳）。**判 tunnel 边缘行为必须实测 tunnel 层（quick tunnel 抓 `location=`），不能用 trace/anycast 理论推断。**

2. **tunnel edge 浮动 ≠ AZ 可定向**。单次实验（run-2）见 2b/2d→SEA、2a/2c→PDX，差点结论"按 AZ 锁 SEA edge"；**确认轮（run-3）同样 2b/2d 全→PDX——edge 是 per-连接/时间的 anycast 浮动，不是 AZ 的确定函数**。→ ① **单次实验必跑确认轮再下结论**（我 run-2 过度解读、run-3 自纠）；② 不能靠选 AZ 来定向 CF edge。**跨 region（不同都会区）才给确定的、可决策的 edge 差异**（俄勒冈 PDX/SEA vs 加州 SJC/LAX）。

3. **cf_ray colo 后缀 = origin 选址罗盘**。web.log 的 `cf_ray="...-XXX"` 后缀就是服务该请求的 CF colo。统计目标国流量的 cf_ray colo 分布 → 知道用户实际从哪些 CF 入口进来 → origin 就近放那些 colo 旁边。**这是 origin 放哪的硬数据，比理论/直觉可靠。**

## 1. 实证发现（2026-06）：CN-via-CF 入口分布 → US 需多 region、EU 不需

`cf_country="CN"` 流量的 cf_ray colo 分布（实测）：
- **US region**：SEA 45%（贴俄勒冈 us-west-2）/ LAX+SJC 53%（贴加州 us-west-1）/ 混合 → **US 是唯一值得多 region 的地区**（俄勒冈 + 加州，CF 按 PoP 把两段流量各 steer 到近源）。
- **EU region**：AMS 主导（+少量 LHR）= 单都会区 → **EU 不需多 region**，单点 FRA/AMS 够。

## 2. region HA：单节点 region 升级必降级 → 每 region ≥2 节点滚动

单节点 region 升级（重启换 jar）时，OpenResty 本地 primary 短暂 down → failover 到 HK backup（跨洋慢）+ **非幂等 POST 不 failover 落 5xx**（见 newworld-multiregion-crossocean-hotpath）。即"升级时该区流量打不开/降级"。**每 region 至少 2 节点**才能像 HK 那样滚动重启（一台一台、另一台兜）零降级。
- **US**：第 2 节点放 **us-west-1（加州）**——同时拿 CN 近源(53% LAX/SJC) + 跨 region HA + 真 edge 多样性。优于同区第 2 AZ。
- **EU**：第 2 节点同 region 即可（AMS 单都会区，无多 region 价值）；同 AZ 已满足"滚动升级不降级"，跨 AZ ~零成本可顺带（防 AZ outage）。AZ 选择只为 HA，别指望定向 edge。

## 3. colo-probe 实验方法（可复用）
测某 AZ/region 的 CF tunnel edge：
1. 该 AZ/region default-VPC 子网起 t3.nano（AL2023），`--instance-initiated-shutdown-behavior terminate`（自清理零残留）。
2. user-data：`curl cdn-cgi/trace` 取 HTTP colo + 下载 cloudflared 跑 `tunnel --url http://localhost --no-autoupdate`（quick tunnel 无需账号）抓 `location=` 实连 edge。
3. **结果回传**：probe `curl https://<我们CF前置域>/__MARKER__/az/.../tunedge/...`（经 CF Tunnel 落 origin weblog，绕过"源站 80 对外关闭"）；lead `grep __MARKER__` origin web.log 取回。**比 get-console-output 可靠**（console 有 flush 延迟 + 自终止会清）。
4. **必跑 ≥2-3 轮**判稳定性（edge 浮动，单轮会骗人）。
5. 凭据：本地 `AWS_PROFILE=nw-dev`（IAM user nw-dev，账号 748579767645）有 EC2 RunInstances/Terminate/describe；ssm:GetParameter 被拒（AMI 走 describe-images 不走 SSM param）。region 节点无 IAM role。

## 4. 方法论铁律（元教训）
owner 反诘"为什么不能 X"先当严肃设计提案 + **做实验论证、不拿理论拍**（多次实证 owner 直觉 > 技术抽象）；但**实验单样本也会骗人，确认轮是对自己的同等纪律**——本轮我 run-2 过度解读被 run-3 自纠，与我纠别人"测试绿≠正确"是同一条。
