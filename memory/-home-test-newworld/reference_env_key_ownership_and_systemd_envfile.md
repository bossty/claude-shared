---
name: reference_env_key_ownership_and_systemd_envfile
description: "判定\"哪个模块真读某个 env 键\"必须追 @Value/@ConfigurationProperties 所在模块（禁凭类名/yml 占位符推断）；systemd EnvironmentFile= 是累加语义，drop-in 覆盖须先写空赋值重置"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7ab2ead7-743f-4348-bd9f-d306c449736c
---

2026-07-10 secrets 三层拆分实测，两条会反复踩的坑。

## 一、判定「模块是否消费某 env 键」的唯一正确方法

**追到 `@Value("${...}")` / `@ConfigurationProperties(prefix=...)` 所在的模块。** 两种常见推断都会错：

1. **凭类名推断 → 错。** 交接档据「web 里有 `JwtAuthFilter`/`JwtTokenService`」断定 web 读 `jwt.secret`，进而报出 P0「EU web 在用硬编码默认密钥」。实际 web 零个类 `import JwtUtil`（唯一 import 方是 admin 的 `AdminUserServiceImpl`）；web 的 `JwtAuthFilter:107` → `JwtTokenService.verifyToken` → `:245` 从 DB `system_config` 读 `GW_JWT_SECRET`，`:247` 缺失即 `throw IllegalStateException`（fail-fast）。**P0 全盘证伪**，且清理方向相反：CA web 持有 `JWT_SECRET` 才是缺陷。一条 `grep -rl "import.*JwtUtil"` 即可避免。

2. **凭 yml 有无 `${}` 占位符推断 → 错。** Spring relaxed binding 把 env `FOO_BAR_BAZ` 映射到属性 `foo.bar.baz`，**yml 里查无此名的键照样生效**。例：`ANALYTICS_V4_WRITE_SHADOW_ENABLED` 不在 web 任何 yml 里，却被 `newworld-web/…/service/SiteStatsService.java:60` 的 `@Value("${analytics.v4.write-shadow-enabled:false}")` 真实读取——subagent 扫 yml 得出"web 不读"，漏报了一个真实的 CA/EU region 行为分裂（EU=true 在写 shadow HLL，CA 无键=false）。

正确姿势：yml 占位符扫一遍 + 全模块 `@Value`/`@ConfigurationProperties` 扫一遍，两边对账。共享模块（common）被 web/admin/data 全依赖，它的 `@Value` 属于**所有**依赖方的潜在消费面。

## 二、systemd `EnvironmentFile=` 是累加语义

drop-in 里写 `EnvironmentFile=/new/path` **不会替换** base unit 里的旧条目，而是追加到其后（旧的排前、被新的覆盖同名键）——形成新旧并存的半迁移状态，比不迁移更危险。必须先写一行空赋值重置：

```ini
[Service]
EnvironmentFile=                          # ← 重置列表，缺此行则新旧并存
EnvironmentFile=/etc/newworld/secrets.env
EnvironmentFile=-/etc/newworld/node.env   # `-` = 不存在时不报错
```

红绿双验过：不写重置行 → `systemctl show -p EnvironmentFiles` 返回两条；写了 → 只剩新路径。

配套两个无损技巧：

- **零中断迁移**：`EnvironmentFile` 仅在启动时读取。改文件 + 改 drop-in + `daemon-reload` 后运行中进程 env 不变。用 `sudo cat /proc/$(systemctl show <unit> -p MainPID --value)/environ | tr '\0' '\n' | md5sum` 前后对账即可证明零中断。
- **新配置的启动预演**（因未重启，新配置尚未被任何进程加载过，这个缺口要补）：
  `sudo systemd-run --collect --wait --pipe -p EnvironmentFile=/etc/newworld/secrets.env -p EnvironmentFile=-/etc/newworld/node.env /usr/bin/env`
  验证 systemd 能解析全部层且键集正确。只打印键名（`cut -d= -f1`），别打印值。

## 三、脱敏正则按完整键名匹配

`sed -E 's/(SECRET|TOKEN)=.*/\1=<REDACTED>/'` **挡不住 `CF_TOKEN_S=`**（`TOKEN` 后面还有 `_S`），2026-07-10 因此把一个账号级 CF token 明文打进了会话记录。要么锚定完整键名，要么直接不打印值。相关 [[feedback_no_handwritten_numbers_from_tools]]。

另：`grep -cE '^[A-Za-z_]+='` 统计键数会漏掉含数字的键（如 `N9E_CATEGRAF_PASSWORD`），须用 `^[A-Za-z_][A-Za-z0-9_]*=`。以及 `sudo cmd > /file` / `sudo cmd < /file` 的重定向由**非 sudo 的 shell** 打开，会 Permission denied——用 `sudo sh -c '...'` 或 `sudo cat`。

见 `docs/sprint/2026-07-10-jar-layout-unification/SECRETS-UNIFICATION-PLAN.md`，skill [[newworld-secrets]] 已吸收。
