---
name: claude-context MCP Zilliz Serverless patch
description: 本地 patch 绕过 checkCollectionLimit 的 create+drop 探测，Zilliz Serverless drop_collection 偶发 >15s 会撞 node SDK 默认 gRPC deadline 导致 index_codebase 永不启动
type: reference
originSessionId: 37118f45-66fd-4fbd-b625-54b1d732177e
---
# claude-context MCP × Zilliz Serverless DEADLINE_EXCEEDED 规避

## 症状

`mcp__claude-context__index_codebase` 返回：
```
Error validating collection creation: 4 DEADLINE_EXCEEDED: Deadline exceeded after 15.001s,remote_addr=34.111.198.99:443
```

从不进入真实建索引阶段。直连 pymilvus 验证过：`create_collection` 2s 正常，但 `drop_collection` 偶发 >30s（Zilliz Serverless control plane 抖动）。

## 根因

`@zilliz/claude-context-core` 的 `checkCollectionLimit()` 用 **create dummy → has → drop dummy** 的副作用路径做容量探测。node SDK `@zilliz/milvus2-sdk-node` 默认 gRPC deadline 15s，drop 超时就抛 DEADLINE_EXCEEDED → MCP 判定"collection 创建失败" → 直接退出。

## 本地 Patch

**文件**：`~/.npm/_npx/<npx-hash>/node_modules/@zilliz/claude-context-core/dist/vectordb/milvus-vectordb.js`

**具体 hash 路径随 npx 缓存变化**，用 `find ~/.npm/_npx -name milvus-vectordb.js -path '*claude-context-core*'` 定位。

**Patch**：在 `checkCollectionLimit()` 函数体开头（if client check 之后）插 `return true;` 短路整个 create+drop 探测：

```js
async checkCollectionLimit() {
    if (!this.client) {
        throw new Error('MilvusClient is not initialized. Call ensureInitialized() first.');
    }
    // LOCAL PATCH: bypass create+drop probe on Zilliz Serverless where drop_collection
    // routinely exceeds the node SDK 15s gRPC deadline. Capacity check deferred to real create.
    return true;
    // ... 原代码保留作为 dead code
}
```

## 操作步骤

1. Patch 上述文件
2. `kill $(pgrep -f claude-context-mcp)` 让 harness 重启 MCP
3. 在 Claude Code 里 `/mcp` → Reconnect claude-context
4. 重跑 `index_codebase`

## 何时需要重打

- 升级 `@zilliz/claude-context-mcp@latest` → npx 会拉新版本覆盖 node_modules
- 清 npx 缓存（`rm -rf ~/.npm/_npx`）
- 换机器 / 换用户

## Why 捷径安全

- n=0 collections 时（裸索引）远没到 Serverless collection 数限额
- 真实 limit 超了，`context.indexCodebase()` 内部 `create_collection` 会报 "exceeded the limit number of collections"，错误会透传到用户
- 唯一损失：原本的 friendly limit message 变成技术错误字符串

## 上游 Issue 建议

- `checkCollectionLimit` 改用 `listCollections` + 硬编码 Zilliz Serverless limit（10）判断，不做写状态机的 create+drop
- 或给 `dropCollection` 显式传 `timeout: 60000`
