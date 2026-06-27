---
name: feedback_cgroup_oom_diagnosis
description: "服务 OOM-kill 重启循环必先 dmesg 看 constraint=MEMCG + 真正被杀进程,别信转述的\"堆撑爆\"理论"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: df06f417-fb3f-4c81-8486-085852426538
---

服务 `Failed with result 'oom-kill'` 反复重启时，**先 dmesg 实证，别接受转述的根因**。

**Why**：2026-06-14 newworld-data(aws-ca-admin) ~每小时 OOM 重启，交接档判"HLS 把 .ts 切片加载进内存撑爆 Java 堆"。dmesg 实测**推翻**：
- `oom-kill:constraint=CONSTRAINT_MEMCG, oom_memcg=/system.slice/newworld-data.service` → **cgroup 级**(撞 systemd MemoryMax)，非 Java 堆级(无 heap dump、`-XX:+ExitOnOutOfMemoryError` 没触发=堆没满)。
- 被 OOM killer 杀的真凶是 **`chrome-headless`(Playwright 爬虫子进程)**，不是 HLS 的 java 线程；OOM 那刻 `java rss≈600MB` 远没到 -Xmx2g。
- 日志里的 "Connection pool shut down" 是**重启的后果**(在途请求被打断)，不是病因——别把后果当根因追。
- 真根因=一个 cgroup(2.44G) 装不下 `java(-Xmx2g≈2.5G footprint) + chromium(峰值1G+)` 共址；box 15G/可用8.3G 完全不缺,纯 cgroup 欠配(迁移默认值)。

**How to apply**：
1. `sudo dmesg -T | grep -iE "oom|killed process|cgroup"` → 看 `constraint=`(MEMCG=cgroup限/其他=box满) + `Killed process N (真凶名)` + 各进程 rss 行(谁吃内存)。
2. cgroup v2 利器：`/sys/fs/cgroup/system.slice/<unit>/memory.{current,max,peak}` —— **memory.peak 是高水位**，能即时判断进程是否已逼近上限，不必干等下一次 OOM。
3. 区分 OOM 层级：有 heap dump / ExitOnOutOfMemoryError 触发 = Java 堆级(调 -Xmx 或修代码内存)；`CONSTRAINT_MEMCG` + java rss 远低于 -Xmx = cgroup 欠配(提 MemoryMax)。
4. 修法热生效：drop-in 写 MemoryMax/MemoryHigh → `daemon-reload` 即推到运行中 cgroup，**无需重启**(验 `cat memory.max` 真值)。
5. 验收别只看"限额改了"：要等真实重峰让 memory.peak 冲过旧上限、仍稳在新限内且无新 oom-kill(owner 口径=不再OOM+业务指标增长)。

关联 [[feedback_verify_metric_source]]（指标/转述先 fact-check 再下结论）、[[project_phase_f_admin_data_california_2026_06_13]]（crossocean-hotpath 也是先实证后改）。
