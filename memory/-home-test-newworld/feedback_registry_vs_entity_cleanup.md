---
name: feedback_registry_vs_entity_cleanup
description: "清理/关闭类操作必验\"实体\"不能只看\"登记/计数\"——TeamDelete 不杀 agent 进程是典型；同型模式贯穿 chunk 孤儿/Redis 旧 key/DB auth 假阳性"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5af436db-ae9f-44c6-bf7a-db0bc88f7f41
---

**「清了登记没清实体」是反复栽的同型疏漏**——清理/关闭/验证类操作，只看 config/目录/计数/返回码就裸报"已完成"会假阳性；**必须实证"实体"本身**。2026-06-02 snack 会话一晚栽 4 次同型。

**Why**：登记层（config 目录 / 计数 / `||echo ✅` 兜底 / 返回码）与实体层（OS 进程 / 磁盘文件 / DB 真数据 / 真日志行）解耦，前者"干净"≠后者干净。owner 多次一句话戳破（"右侧团队成员还在""DB 真查了吗""应该只保留几个版本"）。

**How to apply（清理类操作收尾必跑实体实证）**：
- **关团队 SOP**：`shutdown_request` → `TeamDelete` → **`ps aux | grep -E '--team-name|--agent-name'` 实证进程=0** → 清残留 tmux pane。**TeamDelete 只清 config 目录不杀 agent OS 进程**，裸信会留僵尸 agent（owner tmux 右侧可见）。
- **杀 tmux pane 防自杀**：先 `echo $TMUX_PANE` + `pstree -ps $$` 确认自己所在 pane（本 Bash 工具就在主会话 pane %0），再 `tmux kill-pane -a -t %0`（保留目标杀其余）；**别逐个 index 杀**（tmux 杀后重索引致错杀/漏杀）。
- **DB/服务查询**：先连通性自检（行数>0），否则 mysql auth 失败被 `2>/dev/null + ||echo ✅` 兜底成假"clean"（root vs app 用户 `newworld` 教训）。
- **grep 计数**：必看实际命中行非裸信数字（`itdog_probe_error_total` metric 名含 "error" 被 `grep -ci ERROR` 误计）。
- **磁盘/缓存残留**：active vs 孤儿要分（index.html 引用的活跃 chunk 干净=live 安全；旧 token 只在孤儿 chunk=磁盘垃圾）；删前 tar/HGETALL 备份可逆。
- **杀进程必外科手术、禁 bulk-by-heuristic**：只杀**逐个确认过身份的 PID**，禁用"etime>5min 就杀"这类时间/模式启发式批量杀——会误伤 harness 按需管理的基础设施（2026-06-02 用 etime 过滤误杀 **chrome-devtools/playwright/context7 三个 MCP server + lua/typescript 两个 LSP**，导致本会话 54 个 MCP 工具断连，只能重启会话恢复）。**harness 管理的 MCP/LSP 进程绝不碰**（它管 stdio 连接，mid-session 杀了无法干净重连）。杀前必 `ps -o cmd -p <pid>` 核实是不是真目标。
- **别手写 until-loop 轮询后台任务**：`run_in_background` + `until grep -q EXIT; do sleep` 条件不满足会**死循环空转累积成僵尸后台任务**（一个 `until ! ssh pgrep deploy-frontend` 空转 10 小时）。**治本=用 harness 自带 task-completion 通知**（后台任务完成会自动回调），别自己轮询；少开 `run_in_background`。

**同型实例（一晚 ≥6 次，「清登记/裸信 ≠ 清实体/实证」+「bulk 越界」两大家族）**：① TeamDelete 不杀进程→4 僵尸 agent ② chunk carry-forward 孤儿残留 ③ Redis 286 个 ad:stats 永久 key ④ DB"clean"实为 root auth 静默失败 ⑤ 时间启发式 bulk kill 误杀 5 个 MCP/LSP 基础设施 ⑥ until-loop 轮询僵尸空转 10h。**bulk 越界家族**还含整晚 sed 改名漏大小写变体 / grep 滤掉关键行(PEAK GUARD/真因)。相关：[[project_snack_rename_sprint_2026_05_31]]。
