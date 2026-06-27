---
name: 生产 DB / Redis 凭证位置
description: aws-data:/etc/newworld/secrets.env 存所有生产凭证（需 sudo 读）
type: reference
originSessionId: a1281538-3ef1-45f9-abfb-2b6348aec877
---
凭证位置：`ssh aws-data 'sudo cat /etc/newworld/secrets.env'`

主要键：
- DB_PASSWORD（用 `mysql -uroot -p"<pwd>" newworld`，注意单引号 + 双引号嵌套避免 ! 转义）
- REDIS_PASSWORD（aws-db 上 redis-cli 用）
- JWT_SECRET / R2_SECRET_KEY

CF API tokens 在 DB system_config 表里：`CF_API_TOKEN_{A,B,C,P}`。但**这些 token 没有 Cache:Purge 权限**，purge 缓存只能靠 cache-bust query 或加新 token。

DB 直连：`ssh aws-db 'mysql -uroot -p"..." newworld -e "..." 2>&1' | grep -v Warning`

**How to apply:** 任何需要查 DB 数据/Redis 状态的诊断都从这里取凭证。
