---
name: newworld-mybatis-plus-camel-mapping
description: MyBatis-Plus SELECT * + resultType=POJO 不做驼峰映射坑（B-01 同款 + W3 OrphanDetector 同款）
triggers:
  - mybatis
  - mybatis-plus
  - SELECT *
  - resultType
  - 字段为 null
  - 驼峰映射
---

# 铁律

`SELECT *` + `resultType="org.earth.Channel"` 在 prod 模式下**不做 snake_case → camelCase 字段映射**：
- `channel_code` 列 → POJO `channelCode` 字段 = NULL
- 测试环境（H2）可能不重现，prod MySQL 必踩
- 历史踩过：B-01（W2 sprint）+ W3 OrphanChannelDetectorTask（commit 0c4f9b62）

## 修复

### 方案 A：mapper XML 显式列名 + AS 别名（推荐，最稳）

```xml
<select id="findChannels" resultType="...Channel">
  SELECT id,
         channel_code AS channelCode,
         channel_name AS channelName,
         status,
         created_at  AS createdAt
    FROM promotion_channel
   WHERE ...
</select>
```

### 方案 B：全局 application.yml 开启 map-underscore-to-camel-case

```yaml
mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true
```

**注意**：必须验证 `application-prod.yml` 已设；如无 → 加。MyBatis-Plus 默认 `true`，但**裸 MyBatis** 默认 `false`，混用项目易踩坑。

### 方案 C（兜底）：resultMap

```xml
<resultMap id="ChannelMap" type="...Channel">
  <id     column="id"           property="id"/>
  <result column="channel_code" property="channelCode"/>
  <result column="channel_name" property="channelName"/>
</resultMap>
<select id="findChannels" resultMap="ChannelMap">SELECT * FROM ...</select>
```

## 自检命令

```bash
# 1. grep 所有 mapper XML 中的 SELECT *
grep -rn 'SELECT \*' newworld-*/src/main/resources/mapper/

# 2. prod 启动 log 查 null 字段警告（启动 30s 内）
ssh aws-data 'sudo journalctl -u newworld-admin --since "5 min ago" | grep -iE "null.*field|unknown column"'

# 3. 验证 application-prod.yml 配置
grep -A2 'mybatis-plus' newworld-*/src/main/resources/application-prod.yml
```

## 反例（已踩过）

- B-01（W2）：Channel POJO `channelCode` 全是 NULL，前端显示空白渠道码
- W3 OrphanChannelDetectorTask（0c4f9b62）：`channel_id` → `channelId` 未映射，task 全跑空集，无任何告警

## 关联 skill

- `newworld-sql-safety` — DBA benchmark + PageHelper LIMIT
- `newworld-backend-design` — Result<T> + 配置三层
