---
name: feedback_categraf_config_dir_globs_all
description: "categraf 读 input.*/ 目录下所有文件(非只*.toml),配置目录里禁留备份;改配置在目录外备份"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: df06f417-fb3f-4c81-8486-085852426538
---

**categraf 加载 `input.<plugin>/` 目录下的所有文件(不只 `*.toml`)并合并**——配置目录里**绝不能留备份文件**。

**Why**：2026-06-14 修 aws-ca-monitor 的 disk 假告警(squashfs/snap 挂载被报 100% 触发"硬盘<200G"假警)。改 `/etc/categraf/input.disk/disk.toml` 加 `ignore_mount_points`/`ignore_fs` 顶层过滤(对齐 web 节点 canonical 配置)后**仍不生效**:实测 squashfs 时间戳持续前进=还在采。md5 比对 disk.toml 与 web **完全相同**、同版本 v0.5.6,唯一差异=目录里多个我自己留的 `disk.toml.bak-2026-06-14`(旧 [[instances]] 版)。**移走 .bak + 重启 → squashfs 立即停采**(时间戳冻结,近40s只剩 ext4+efivarfs),6 个假告警 recover_duration=0 一周期内全恢复。

**How to apply**：
1. 改 categraf input 配置,备份**必须放到目录外**(如 `/root/`),`mv` 出 `input.*/` 目录,别用 `cp file file.bak` 留在原地。
2. categraf disk 过滤项 `ignore_fs`(类型)/`ignore_mount_points`(路径,如 `/snap`)要在**顶层**,不能嵌 `[[instances]]`(嵌进去不生效)。canonical 配置(web/db 节点 deploy-categraf.sh)是顶层写法。
3. squashfs/snap 挂载天生 100% used(只读压缩镜像),"硬盘<200G"类规则必须靠 categraf 侧 ignore_fs+ignore_mount_points 过滤;每台 Ubuntu 都有 amazon-ssm-agent/core22/snapd 三个 snap,不是某机独有——某机独报=它的 categraf 过滤漂移。
4. **验证 categraf 是否停采某指标:取同一 series 时间戳间隔 20s 看是否前进**(前进=还在采),别信 instant query 的 age(被 5min lookback 的陈旧样本骗,本轮连踩两次)。

关联 [[reference_dragonfly_iowait_cosmetic]]、[[feedback_cgroup_oom_diagnosis]](都是"验证再宣布"+窗口计数判活)。N9E 活跃告警查 `alert_cur_event` 表(已恢复进 `alert_his_event`);死主机僵尸告警(host停报永不恢复)直接 `DELETE FROM alert_cur_event WHERE target_ident=...`。
