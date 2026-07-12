---
name: feedback_one_wait_mechanism_per_bg_task
description: "后台任务每个只配一个等待机制,且退出条件必须匹配真实输出——别叠 poller 造孤儿空转\"假死\""
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0c702d85-0a7b-4ef3-80d7-6a327a21bab6
---

后台任务(`run_in_background`)完成时 harness **本来就自动通知**,不要再额外起 `until ... grep` 轮询进程去等它——多余,且一旦退出条件写错就无限空转,看着像"挂住/假死",还占进程和 context。

**Why:** 2026-07-11 html-shell 部署时,一个前端部署任务我叠了三层等待(任务自动通知 + `until grep` poller + Monitor)。poller 的退出条件拿 OpenResty 日志的 `[OK]`/`部署完成` 去 grep **前端**日志 `fe-deploy2.log`(真实完成标志是 `PASS:`/`DONE: 部署 web 全部成功`),grep 永不匹配 → `until false; do sleep 10` 空转到被手杀。这是**重复犯**的错(Owner 已两次点名"老出假死")。

**How to apply:**
1. 单个后台任务要等它结束 → 直接靠 `run_in_background` 的自动完成通知,**不叠 poller/Monitor**。
2. 确实要自己写等待循环 → 退出条件必须 grep 目标文件里**真实存在**的完成标志(先 Read 确认那个字符串真会出现),别凭印象拼词;跨脚本别混日志文件(OpenResty=fe-deploy.log vs 前端=fe-deploy2.log)。
3. `echo "EXIT=$?"` 跟在 `cmd > file` 之后,EXIT 进的是终端/task-output,**不进** file——别用它当 file 里的哨兵。
4. 一个活最多一个等待机制。

关联 [[feedback_long_task_no_stall_sop]]。
