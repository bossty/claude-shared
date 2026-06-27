---
name: newworld-secrets
description: 生产凭证不入 git，application-prod.yml 用 ${XXX:changeme} 占位符，真值在 /etc/newworld/secrets.env (0600) 通过 systemd EnvironmentFile 注入。Triggers on 密码, secret, application-prod.yml, secrets.env, 凭证, ${XXX:changeme}, EnvironmentFile, 密钥占位符, hardcoded password.
---

# Newworld 凭证管理铁律（2026-04-13 起）

## 触发场景
- 修改 `application-prod.yml` / `application.yml`
- 新增任何密码、token、API key、签名密钥、AES key、JWT secret
- 在 Java 代码 / .yml / .properties / SQL seed 中看到看似硬编码的凭证

## 铁律
1. **生产凭证不入 git**：`application-prod.yml` 中所有密码 / 密钥用 `${XXX:changeme}` 占位符。占位符默认值必须是 `changeme`（让生产忘注入时直接 fail-fast，不要给"看起来正常"的默认）。
2. **真值在各服务器 `/etc/newworld/secrets.env`**：权限 `0600`，owner `root` 或 `root:newworld` `0640`。
3. **注入方式**：systemd unit 的 `EnvironmentFile=/etc/newworld/secrets.env`，进程启动时由 systemd 读入并 export。
4. **新增 secret 必须遵循同一模式**：
   - yml 加占位符 `${NEW_SECRET:changeme}`
   - 在所有部署服务器的 `/etc/newworld/secrets.env` 加真值
   - 禁止硬编码到 Java 常量或 .properties
5. **三档分类**（详见 `docs/SECURITY_POSTURE.md`）：强 secret（DB / R2 / JWT）/ 弱签名（探针 salt 一类）/ 探针 salt（可暴露但不能丢）。新 secret 必须分档。

## 检查清单
- [ ] grep `password:|secret:|key:` in application-prod.yml → 全部 `${XXX:changeme}` 形式
- [ ] 服务器 `/etc/newworld/secrets.env` 权限 = `0600` 或 `0640`
- [ ] systemd unit 含 `EnvironmentFile=/etc/newworld/secrets.env`
- [ ] 新 secret 同步加到所有 prod 服务器 secrets.env

## 违反后果
凭证入 git → 必须 rotate（CF token revoke / DB 密码改 / R2 key 轮换），不能"反正没人看到"打发。

## 源
- CLAUDE.md L16-L21
- 配套文档 `docs/SECURITY_POSTURE.md`
