---
name: project-admin-menu-sprint-2026-05-24
description: "admin 后台菜单权限 sprint（14 task / 28 commit）— TDD 单元测试 1773 PASS 但线上启动崩 5 大类，沉淀\"单元测试 ≠ 启动期/前后端联调\"5 条 fact-check 铁律"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0718667c-7a39-4ee8-bbea-9dca275d98d5
---

# Admin 菜单权限 sprint（2026-05-24）

## Sprint 整体
- **范围**：admin 后台 26 个菜单叶子粒度权限，super 可实时编辑任意 admin 菜单
- **架构**：menu-keys.yaml 唯一真相源 + 启动期 fail-fast Controller 覆盖 + LoginInterceptor 默认拒绝 + Caffeine 30s 缓存 + menu_version 乐观锁
- **流程**：superpowers brainstorming → spec → writing-plans → 14 task subagent-driven-development（每 task dev-senior + 蓝军 + qa/ops review）→ no-ff merge `f1b03b7b` → push origin master
- **测试金标**：mvn 1773 / 0F / 0E（4 模块）+ npm 12 files / 69 tests + 0 uncovered endpoint
- **蓝军挑刺**：3 BLOCKER + 8 MAJOR + 11 MINOR 全 sprint 内闭环
- **Spec**: `docs/superpowers/specs/2026-05-24-admin-menu-permission-design.md`
- **Plan**: `docs/superpowers/plans/2026-05-24-admin-menu-permission.md`
- **Deploy checklist**: `docs/superpowers/plans/admin-menu-deployment-checklist.md`

## 本 sprint 内已闭环的真 bug
- SQL: ALTER ADD COLUMN IF NOT EXISTS MySQL 8.0 不支持 → information_schema PREPARE guard
- INSERT 重跑 PK 冲突 → INSERT IGNORE
- LoginInterceptor 把 `/api/v1/internal/` 整段豁免 → OpsController 安全旁路（删豁免 + 归 SYSTEM_CONFIG/DOMAIN_LIST）
- AD yaml `/api/v1/ad/**` 幽灵 pattern → 删（真路径是 `/api/v1/q-admin/**`）
- 白名单用 startsWith 过宽 → exact + prefix 双判
- AdminMenuService audit detail 用 List.toString() 拼非法 JSON → Jackson ObjectMapper
- AdminUserService.changeRole/deleteUser TOCTOU 竞态 → countByRoleForUpdate FOR UPDATE 悲观锁
- AdminUserController 越级直调 Mapper → login 返完整 LoginRespVO Controller 不调 Mapper
- 前端 bundle 暴露 controllerPatterns → vite plugin 过滤后端路由字段
- MainLayout cachedKeys 不写回 → onMounted await ensureFresh + cachedKeys.value = keys（本来侧边栏永远空）

## ⚠ Sprint 漏的 5 大类（其他 session 部署后揪 + 修，commit `f1b03b7b..07fec385`）

### 1. 循环依赖 LoginInterceptor → AdminMenuService → ApplicationContext（BLOCKER，7 commit 反复修）
- 修法链：fcb85be0 (@Lazy AdminMenuService) → a13fb1ed (@Lazy MenuKeyRegistry) → 70ab0392 (del final) → bad7207c (private→protected ctor) → 28b1df57 (del @Autowired self field) → **61d697cb（真治本）@PostConstruct→@EventListener(ApplicationReadyEvent)** → 39766b28 (revert 4 hack)
- 漏的原因：mvn test 全 mock，MenuPermissionCoverageTest 用反射扫不拉完整 Spring 容器

### 2. 前端 axios baseURL 双前缀 → `/api/api/v1/...` 404（BLOCKER）
- 修法：462141fa 删 menuStore.js `/api` 前缀（项目 request.js baseURL 已是 `/api`）
- 漏的原因：dev-senior 没 grep 现有 `frontend-admin/src/utils/request.js` baseURL 配置

### 3. 前端 login 没同步改 LoginRespVO（BLOCKER）
- 修法：7028084b login 取 `res.data.token` 而非把 res.data 当 token
- 漏的原因：Task 7 改 backend login 返 String → LoginRespVO，没 grep 前端 `views/login` 调用方同步改

### 4. @MapperScan 路径漏配（BLOCKER）
- 修法：00a0cc38 加 admin.mapper 路径到 @MapperScan
- 漏的原因：新建 `AdminUserMenuMapper` + `AdminAuditLogMapper` 在 `newworld-admin/.../mapper/`，没 grep 现有 @MapperScan 配置

### 5. GlobalExceptionHandler 同名 bean 冲突（MAJOR）
- 修法链：054ed5a1（explicit bean name 临时解）→ 86f18b1f（统一删 admin 重复 GEH 合并到 common）→ 9b390f96（test import 修）
- 漏的原因：Task 7 新建 admin 模块 GEH 没 grep 现有 newworld-common 有没有

## 5 条 fact-check 铁律（建议 sink CLAUDE.md / sub-skill）

| # | 铁律 | 检测命令 |
|---|------|---------|
| 1 | 新增 @Component 链路必跑 `@SpringBootTest(webEnvironment=NONE)` 拉真容器验证无循环依赖（mock 不能替代）| `mvn test -Dtest=ApplicationContextStartupTest` |
| 2 | 前端新增 axios 调用前必 grep `baseURL` 现有配置 | `grep -rn "baseURL" frontend-admin/src/utils/` |
| 3 | 改返回 VO 类型必跨前后端 grep 所有调用方同步改 | `grep -rn "<MethodName>" frontend-admin/src/views/` |
| 4 | 新增 @Mapper 必核 @MapperScan 配置覆盖 | `grep -rn "@MapperScan" newworld-*/src/` |
| 5 | 新增 @ControllerAdvice / @RestControllerAdvice 必 grep 现有同名 bean | `grep -rn "@ControllerAdvice\|@RestControllerAdvice" newworld-*/` |

## 底层逻辑教训
mvn test 1773 PASS + npm 69 PASS + 蓝军 22 项闭环 = **必要不充分条件**。单元/反射/mock 测试覆盖不到：
- 启动期 Spring 容器装配（循环依赖 / @MapperScan / bean name 冲突）
- 前后端真联调（axios baseURL / VO 字段同步）

→ 未来后端 + 前端跨栈 sprint 必加 [[reference-spring-context-startup-test]] 拉真 context + [[feedback-cross-stack-grep-fact-check]] 跨栈 grep checklist。

## 5/25 标准实现重构（owner 揪 hot-patch 反诘）

5/25 sprint 上线后陆续 3 个新 403（system-config/all / analytics/v4/ads / q-admin/slot/all）每次都"yaml 加一条 controllerPatterns"打补丁。owner 反诘"能不能一次性标准实现"。

**根本设计弱点**（重构前）：
1. yml `controllerPatterns` 手工维护 → 加新 Controller / 改 base path 漂移
2. AntPathMatcher 长 pattern 优先抢匹配 → q-admin/** 抢 q-admin/slot/** 之类歧义陷阱
3. WHITELIST_EXACT/PREFIXES + yml + Controller path 三套真相源
4. 删菜单时漏改 yml 留幽灵 pattern

**重构方案（注解驱动）3 commit 上线**：
- `cac384cf` R1: 37 Controller 全标 `@RequireMenu("key")` 类级 / `@PermitAll` 类或方法级（公开端点）
- `a3c15ecb` R2: LoginInterceptor preHandle 改为 HandlerMethod 反射读注解；MenuPermissionConfig @EventListener(ApplicationReadyEvent) 启动期严格校验每个 method 必有注解否则 BeanInitializationException；删 yml controllerPatterns 字段 / 删 WHITELIST_EXACT/PREFIXES / 删 MenuKeyRegistry.matchControllerPath/sortedByPatternSpecificity
- `7928e9c4` ops hotfix: 启动期校验跳过 `org.springframework.boot` 包内置 Controller（BasicErrorController 等无法加注解）

**5/25 logout reset 修法** `12435bb2`：MainLayout handleCommand 'logout' 调 `useMenuStore.reset()` 防上一用户菜单 30s TTL 残留到下一用户

**注解驱动后真相源收口**：
- 权限规则 = `@RequireMenu` + `@PermitAll` 注解 (Java) + `admin_user_menu` 表 (DB)
- yml 只剩**菜单元数据**（title/group/path/routeName/defaultForAdmin/mandatory），**不再是权限规则**

## 5/25 sink 新铁律 4 条

1. **权限管控走注解驱动而非 URL pattern 匹配**：注解直接标 Controller 类/方法，反射读，无 AntPathMatcher 抢匹配歧义；启动期 fail-fast 强制每个 Controller method 必标注解 → 加新 Controller 漏标永远启动失败（feature 不是 bug）
2. **前端 SPA 模块级 state 必在 logout reset**：Vue 模块级 reactive object (如 menuStore) 与用户会话生命周期独立，logout 不显式 reset 则下一用户 30s TTL 内拿前一用户数据；通用模式：login/logout 流程逐一调每个 user-scoped store 的 reset
3. **owner 反诘 "hot-patch vs 标准实现" 是真痛点**：每个 BUG 都"yml 加一条" / "WHITELIST 加一项" 是结构性弱点的累计；遇 3+ 次类似补丁必停下做 1 次顶层重构而非继续打补丁
4. **业务联动绑死菜单组合 ≠ 权限不独立**：AdList.vue 必调 q-admin/slot/all 是前端代码硬编码的业务依赖，权限设计可以"每菜单独立"但实际业务上 AD 菜单**必依赖** AD_SLOT 才能用；owner 要"独立勾"需先决策：合并菜单 or 接受打包勾选 or 改前端业务代码不调跨菜单 endpoint

## 5/25 待办 / 已知风险
- super UI 编辑权限弹窗无 diff 确认 → 5/25 owner 自己误删 17rip 的 AD_SLOT 实证。建议加保存前 diff 弹窗（5 min 单 task，owner 选 A 暂未做）

## 5/25 晚 AD 解耦 AD_SLOT 业务联动（commit `6ec9c619`，owner 真验 OK）

owner 反诘"广告管理和广告位一定要绑定到一起吗" — 实证 AdList.vue mounted 立刻拉 `/q-admin/slot/all` 是**懒人写法**而非业务必须。

**解耦方案 A**：后端 AdController 加 `GET /api/v1/q-admin/slots` 注入 AdSlotService，类级 @RequireMenu("AD") 继承 → AD only admin 调此 endpoint 拿广告位列表无需 AD_SLOT 权限。前端 AdList.vue 改 import + 调新 endpoint。AdSlotController.getAllAdSlots 保留（广告位管理写场景仍走 AD_SLOT 严格权限）。

部署：JAR 1a56ba09 + 0 ERROR + 启动期 fail-fast PASS + /q-admin/slots 401 + frontend dist build。owner 真验 17rip 只勾 AD 不勾 AD_SLOT → 广告管理正常进，每菜单完全独立可任意搭配。

## 5/25 sink 新铁律第 10 条：业务联动绑定不是权限设计问题，是业务/前端代码设计问题

**反例**：AdList.vue mounted 立刻调 `/q-admin/slot/all` 拿广告位列表（用于筛选下拉框/编辑对话框/上传规格判定）。表面"广告管理必须依赖广告位权限"，实际是**前端懒人写法**（一次拉好缓存所有用途），不是业务必须。

**修法**：跨菜单数据依赖时，**后端聚合 endpoint** 是最干净切根（同 controller 同 @RequireMenu 一次返多数据集），优于"前端按需懒加载"（场景多 + 状态难管）或"拆 endpoint @PermitAll"（增加注解管理颗粒度）。

**底层逻辑**：每菜单完全独立可自由搭配是权限设计的目标；前端代码硬编码跨菜单 endpoint 调用是阻碍这目标的真原因。owner 揪"必须绑定吗" = 真业务架构反诘，不接受"前端代码就这样所以必须配权" = owner mindset 最高颗粒度。

## 5/25 SSH 永久修法（与本 sprint 无关但同 session 学习）

main session 突发 git push permission denied：本机 ssh-agent 死了 + ssh 默认 BatchMode=no 时 GitHub 拒绝公钥（疑 ssh 客户端 fall back interactive 触发 GitHub 限流）。永久修法：`~/.ssh/config` 加 `Host github.com\n  IdentityFile ~/.ssh/id_ed25519\n  IdentitiesOnly yes\n  BatchMode yes`，之后直接 `git push` 在 newworld 目录 work。
