---
name: project_snack_gif_upload_and_slot_fixes_2026_07_06
description: "广告上传报错Data is not in GIF format根治(上传路径按真实magic bytes判定转码格式)+编辑下拉隐藏退役槽+l03横幅收敛1条+11槽建议尺寸复核全对(object-fit审计);合master 39f551fc全部署"
metadata:
  node_type: memory
  type: project
  originSessionId: db5768b1-6308-46eb-845a-adea5ee5851e
---

# 广告上传gif报错根治 + 编辑下拉/横幅数据/尺寸复核（2026-07-06）

**合 master `39f551fc`（--no-ff，detached worktree 在 origin/master 合，不碰共享本地 master）+ 全部署验证。** subagent-driven 流程（systematic-debugging 定根因→implementer→蓝军 review→fix→部署）。

## ① gif 上传报错「Data is not in GIF format」（真 P1）
- **报错源**：`gif2webp` 二进制拒绝非 GIF 数据。Owner 复核确认=上传的图 ext 是 gif、真实字节不是 gif。
- **根因**：`SnackImageEncryptService.uploadEncrypted(imageBytes, ext, ...)` 直接用传入 `ext`(来自 `UploadController.guessExtension`=文件名/content-type)决定转码工具路由(`transcodeToWebP`:gif/apng→gif2webp、avif/webp→ffmpeg、png→cwebp lossless、其余→cwebp)。改名成 .gif/伪装 content-type 的非 GIF 文件 → ext=gif → gif2webp 炸。**重加密路径 `reencryptFromR2` 早已先 `sniffExtFromMagicBytes` 再转码，直接上传路径漏了这步。**
- **修法**：在 `uploadEncrypted` 内部 `String realExt = sniffExtFromMagicBytes(imageBytes, ext);` 用 realExt 决定临时文件名+转码工具(单一咽喉点，两个调用方都受益)。ext 降级为 sniff 失败回落 hint。签名不变、不改 Controller。`transcodeToWebP` private→package-private 供同包单测 spy。
- **蓝军 MAJOR 判真伪**：sniff 失败回落 `resolveExtForTranscode`(非gif一律→avif→`runFfmpegAvifToWebP`=`ffmpeg -i`按真实内容自动探测)——这是**最宽容兜底非 bug**，唯一严格工具 gif2webp 只在 magic bytes 真是 GIF8 才走。缺陷只是注释/commit 把兜底写成「回落 origExt 字面」与实现不符→据实修文档+补 characterization test，**不改路由逻辑**。
- 测试:admin 27/27(新增 PNG伪装gif→路由png、真JPEG伪装gif→jpg、未识别→avif兜底、真GIF→gif 对照)。commit `7af7c080`+`f166e8ca`。

## ② 编辑广告下拉仍显示退役槽
- `frontend-admin/SnackList.vue` `formSlotList` 编辑态 `return slotList.value`(全部含 status=0)。改为**启用槽 + 当前记录所在槽**(隐藏其他退役槽、又保当前值不显示成裸ID)。新增态维持仅启用。测试 3 例(fe-admin 166 绿)。commit `74518c1c`。

## ③ l03「全站-底部横幅」应只有一条
- 前端 `MainLayout.bottomBannerQ = slotData.snacks[0]`(无轮播,单条)；后端 `findActiveBySlotId` `ORDER BY sort_order DESC, id DESC` 无空图过滤。l03 两条(id12空图/id37有图 都 sort=1)→snacks[0]=id37(有图)实际展示,id12 死重从不渲染。
- Owner 选**留 id37(有图) 禁 id12**(空图「美色Live」)。直接改生产库 `UPDATE snack SET status=0 WHERE id=12`(可逆非删)。绕 admin API,web 缓存未失效但展示的一直是 id37、可见输出不变无需 purge。

## ④ 各广告位建议尺寸复核 = 全部正确，无需改动
- 11 图片槽 rec 尺寸全与渲染容器比例吻合，且**每个图片元素都 object-fit cover/contain(或背景cover)、无一用默认 `fill`** → 对应尺寸图永远等比缩放不拉伸变形。唯一裁切=l03/p08 电脑端(3:1图→5:1框居中裁,设计,hint写明主体置中)。
- 容器实测:z02 tile padding-top:100%(1:1)cover / l03·p08 Snack01 背景cover 手机padding-top:33.3%(3:1)电脑20%(5:1) / g01 Snack07 300×250(6:5)cover / g02 Snack05 250×150(5:3)cover / l02·p01·p07·p03 `.cover-md` aspect-ratio:16/9 cover / p05 Snack03 padding-top:56.25% object-fit:**contain** / p06 Snack06 56.25% cover。
- **★证据法=正圆环测试图**:按各槽 rec 尺寸生成 SVG(正圆+对角+网格),用各容器精确 CSS 渲染→拉伸则圆变椭圆。截图全保持正圆=零失真(harness+shoot脚本在 scratchpad)。未往生产塞测试图(会让真实用户看到)。

## 部署（feature 分支产物→验证→合 master）
- admin jar:worktree 全量 build(BUILD_EXIT=0)→scp ca-admin /tmp→`sudo install -o newworld` deploys→备份 current.jar.bak-pre-snackfix→切 symlink→`sudo systemctl restart`→actuator :18080 UP(启动~50s)+90s 0 ERROR+jar 含 sniffExtFromMagicBytes 符号。
- frontend-admin:`deploy-frontend.sh admin`(git-preflight Gate A OWNER_DEPLOY_APPROVED+Gate M锁)。**★Gate 1 拦停:HEAD 未 push→必先 `git push` 线上代码对所有会话可见**(手动 jar 部署绕过了此闸,fe 闸补上)。push 后 ci-local 绿→vite build→dist 原子 mv→smoke index.html PASS→deployed/frontend-admin=74518c1c。

## 教训
- ★gif2webp「Data is not in GIF format」= 文件 ext/content-type 伪装成 gif、真身非 gif;修在转码前按 magic bytes 判定的**单一咽喉点**(uploadEncrypted),别在多个调用方各修。
- ★object-fit 审计:cover只等比裁/contain只留边/都不失真,唯 `fill`(默认)拉伸;查「图会不会变形」= grep 每个 img 有没有 object-fit。正圆测试图是可视化铁证。
- ★admin jar 手动部署也应先 push(与前端 git-preflight 一致),否则线上 jar 对别会话不可见。
