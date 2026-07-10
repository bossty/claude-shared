---
name: project-snack-sweetspot-transcode-2026-07-09
description: 广告图500KB cap根治=甜点位方案(2×rec缩放+q80无体积cap)+连锁揪出Snack01浅色主题background简写吃掉cover的线上事故
metadata: 
  node_type: memory
  type: project
  originSessionId: 97fccd13-00e7-4d0e-93f3-eec7e573814f
---

2026-07-09 广告图上传"webp 转码后仍超 500KB 拒绝"根治，分支 `feature/snack-image-sweetspot-transcode`（**已合 master：Owner 授权后 `--no-ff` 合并 `714e2f55`，已推 origin，全流程收口**）。

**后端甜点位方案**（`2a85e4cb`，已部署 ca-admin `20260709-101847-b85f6cac.jar`）：按 snack-slot-spec.yml 2×rec 像素等比缩放（只缩不放大，spec 缺失不缩）+ 统一 q80 转 WebP，**彻底废除 500KB cap 和 q85→q70→q60 降质阶梯（含动图）**。PNG 弃 lossless 首轮（原必超元凶）改有损 q80 保 alpha；GIF 需缩放走 ffmpeg（gif2webp 无 resize）；入口 gate 5MB→20MB、multipart 10→20/25MB。e2e：4000×1500 JPG→17,990B；1600×1000×30帧 GIF（2.2MB）→1.07MB 放行。

**连锁事故**：cap 一放开，运营首传 l03 真图（1500×500 动图 WebP 937KB）→ 移动端只露左上角。根因**不是转码**：`Snack01.vue:131` `[data-theme="light"] .snack-link { background: var(--...) }` **简写重置基础规则的 background-size:cover 为 auto**（scoped 优先级更高），广告图内联 style 只换 backgroundImage → 浅色主题按原始像素渲染。修 `2a248c42`（简写改 background-image 长写），四象限验证 + FORCE_PEAK 部署 web×6 + 线上真机验证恢复（computed cover/50% 50%）。全仓扫过**无其它同款**（其余组件都是 img+object-fit 且无主题覆盖）。教训：cap 拦着 = 该槽从未走过真图路径，放开 cap 前该把"首次真图"当新路径测。

**顺手修**：SwVersionStats.spec.js 时区测试假设机器 TZ=UTC+8，EDT 机器上 master 也红拦 pre-push → 测试顶部钉死 `process.env.TZ='Asia/Hong_Kong'`（`b85f6cac`）。

**尺寸规格对账结论**：11 个图片槽 spec 尺寸/hint/前端真实渲染比例全部吻合，全部等比（cover 居中裁，唯 p05 贴片 contain 露边），无变形路径。两处待订正文案**已修（Owner 拍板，`b5f4add4`，2026-07-09）**：① p08 hint 删"电脑居中裁5:1"（PC 端 d-lg-none 隐藏，PlayerDesktop.vue:269）；② yaml 11 槽注释统一「组件 SnackXX.vue / DB=SnackYY」双写（DB 现值生产实查：l03=Snack23/g01=Snack11/z02=Snack05 等）。已同步 ca-admin `/etc/newworld/snack-slot-spec.yml`（md5 对账一致，5min 缓存自刷新生效）。前端 .vue 文件编号与 DB component_code 是两套体系，slug 经 `src/config/key-map.js` 路由。

**收口（2026-07-09）**：Owner 授权后合 master `714e2f55` 并推送 origin（`0cc709cf..6bc5b093`，ci-local 全绿）；worktree `/home/test/worktree-snack-sweetspot` 已删、分支本地+远端已删（merged+pushed 双验后）。合并不需重部，产物早已在产。**顺带教训**：push 首次被 ci-local 拦（web ArchTest lambda$2 + data 五个测试类 `Unresolved compilation problem`）——真因是 jdtls(LSP/Eclipse 编译器)把脏 class 写进 `target/`，`mvn test` 不带 clean 复用污染产物；`mvn clean test -pl newworld-web,newworld-data -am` 全绿证实，非代码问题。见 `Unresolved compilation problem` 即怀疑 jdtls 污染，先 clean 再判红。相关：[[reference_postdeploy_version_verify_cf_swr_stale]]、[[feedback_owner_approval_all_deploys]]。
