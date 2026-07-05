---
name: project_snack_slot_size_hints_2026_07_06
description: 广告(Snack)系统审计：尺寸提示三套矛盾数收敛为YAML单真相源+/slot-specs下发+上传软校验；分支fix/snack-slot-size-hints待Owner授权合master部署
metadata: 
  node_type: memory
  type: project
  originSessionId: db5768b1-6308-46eb-845a-adea5ee5851e
---

# 广告系统全链路审计 + 尺寸提示单真相源化（2026-07-06）

**已合 master `f0c98761` 并四线部署完成（07-06 02:32-02:45 HKT，Owner 授权 force-peak）**：线0 yml铺ca-admin(md5核对+.bak-pre-f0c98761备份)→线1 web×6→线2 fe-web×6→线3 admin jar `20260706-024449-f0c98761`→线4 fe-admin。验证：admin 启动0 ERROR+SnackSlotSpecService 17槽加载OK；jar真身含slot-specs路由+hint字段(python zipfile)；/slot-specs super-JWT探针返{"encrypted":true}=路由真mapped；fe-admin dist含"建议尺寸：PC"新串；deployed/web+frontend-web+frontend-admin 三tag=f0c98761；eu-web-01 236条ERROR=02:38:54重启秒已知Lettuce drain模式,5min后0条。部署日志 scratchpad/deploy-all-f0c98761.log。上一会话03:00定时部署已按Owner令取消(脚本改名.CANCELLED,进程已死)。
合并踩坑：①共享 checkout `--ff-only` 对齐被 tail 吞错未生效，第一次合并建在旧基线被拒（重置重建）；②worktree `git add -A` 误裹 claude-shared/memory 镜像过期快照与他会话冲突（取 master 侧解决）——★worktree 提交前应 `git status` 核改动面只含本任务文件。

## 核心发现（证据 docs/sprint/2026-07-06-snack-slot-size-hints/FINDINGS.md）
- 「前台实际渲染 / etc/snack-slot-spec.yml / 管理端提示」是**三套互相矛盾的数**：YAML 15/17 槽是 v3 文档 IAB 占位值（Owner 只确认过 z02）；管理端提示硬编码且图标位判定用死 slug 前缀 `home_after_` 永不命中。最重：g01 开屏 YAML 写 1080×1920 竖屏全图，实际是固定 300×250 卡片；p01「信息下方」实际渲染 Snack08 品牌卡网格根本不是横幅；p02 侧栏 300×600 实际 300×250。
- **上传零尺寸校验零缩放**：加密单文件流水线只 WebP 转码+500KB 降质，旧 ffmpeg resize 已是死代码；规格 YAML 此前只做存在性校验（"死规格"）。
- 真 bug：上传响应键名错位（后端返驼峰 `origExt`，前端读 `data.orig_ext`）→ 新上传广告 orig_ext 落库恒 NULL（下游无运行时消费方，潜伏级）。

## 修法（已实现+测试全绿：admin 2135 / frontend-admin 162）
YAML 按前台 CSS 亲核值重写（2 倍图）+ 新增 hint 字段；`GET /api/v1/snack-admin/slot-specs` 下发；管理端提示改吃接口；上传前软校验（低于 PC/移动两档各维度较小值 90% 阻止；比例越出 [minR×0.75,maxR×1.25] 确认框）；**不做裁剪组件**（前台全 cover/contain，裁剪属重复建设，Owner 问题的答案）。

## 部署铁律（PLAN.md §部署注意）
**必须先铺 /etc/newworld/snack-slot-spec.yml 再（或同时）部署 admin jar**（蓝军#2：顺序反会新端点下发旧值）；旧 jar 读新 yml 安全（未知 hint 键被忽略）。前端走 deploy-frontend.sh。

## 07-06 追加（Owner 两指令 + 新发现）
- **命名以 mobile 为准 + 单图共用单一建议尺寸**：分支 `fix/snack-slot-mobile-naming`（`289552b5`，测试全绿已 push，待授权合并）——v44 SQL 改 19 槽 name（仅电脑端的 5 槽显式标注）+ yaml rec_w/rec_h + 提示改「建议上传:w×h(手机/电脑共用一张图)」。部署序：v44 SQL→yml→admin jar→fe-admin。
- **★p01/z05 全部 8 条广告 encrypted_image_url=NULL → 线上一直显示「更多精彩内容›」兜底卡非真实素材**（SnackFallbackCard 文案；生产 DB 实查）。修复=跑 `POST /api/v1/upload/ad-reencrypt-all` 回填，待 Owner 令。
- **Owner 改版方向**：p01/z05 品牌卡后续改「电影卡样式(图+下方文字)或纯图」——落地时 yaml 改 640×360+hint 一行事，顺带根治蓝军 MAJOR#1。

## 待 Owner 拍板（FINDINGS §三.B）
B1 上传管道按规格 downscale（省带宽，动生产管道独立 sprint）；B2 前台广告图假 lazy（mount 即全量解密，z02 首屏 24 张并发）；B3 Snack02/05 解密前 CLS；B4 Snack07 窄屏溢出裁切；B5 clean-env 种子缺 component_code；z05/p01 共用估算值是否拆分（蓝军 MAJOR#1）。

## 教训
- ★测试逮住自己校验逻辑缺陷：双比例槽（横幅 PC 5:1/移动 3:1）下限不能直接用移动档，须取两档各维度较小值——合法 PC 比例图高度天然低于移动档。
- ★「代号系统」侦察：广告=Snack、slot slug 在 key-map.js `Q`、组件 Snack01-11 ↔ component_code；grep "ad" 找不到广告系统。
- 本会话实测 context-mode 插件仍在活跃拦截 Bash（memory 记录 07-05 已停用）——账户 B 的 enabledPlugins 疑未真正关闭，待 Owner 查。
