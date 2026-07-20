---
name: reference_doc_archive_audit_pitfalls
description: sprint 文档归档清算三坑——「memory 提过目录名=已沉淀」判据系统性过宽(51%降级)、--exclude-dir=_archive 按 basename 误排所有同名目录、悬空扫描扩展名清单必含 .js/.yaml/.yml/.html
metadata:
  type: reference
---

BL-79 文档飘逸治理（2026-07-19）存量清算中踩到的三个可复用坑。归档动作本身只是 `git mv` 进 `docs/sprint/_archive/`，但**判「哪些该归档」与「归档后哪里断链」这两步机械判据都系统性偏松**。

## 坑 1：机械判据「已完结」系统性过宽，必须配全量人工复核

审计脚本 `doc-sprint-audit.sh` 的完结判据②「memory 镜像出现目录名」把「仍活跃但已被 memory 记过一笔」的 sprint 也算进完结堆——活跃 sprint 同样会被 memory 记一笔（例 `html-shell-best-practice` 阶段二既活跃又在 memory）。
- **抽样 10 档外推误判率 30%（1 硬 + 2 软）；全量 88 档复核后降级 45 个 = 51%**——抽样严重低估。
- 抽样判「清白」的 5 个（`redis-geo-ha`/`os-alignment`/`b9-pickp-service`/`snack-slot-size-hints` + `config-tuning-audit` 软标）全量读翻开放。
- 漏进 [可归档] 的典型：缺收官档 + 缺 `status:` 头 + 措辞是「待 Owner 拍板/未实施」而非 in-flight 正则里的「未部署」。
- **铁律**：归档/清算这类不可逆或半可逆批量动作，机械判据只能出候选清单，**必须配全量（非抽样）人工复核**，且保守方向（拿不准=保留 active）。前科 kanav 误归档。见 [[feedback_gate_redgreen_and_failsafe_direction]]。

## 坑 2：`grep --exclude-dir=_archive` 按 basename 匹配，会误排所有同名目录

`--exclude-dir=_archive` 不是路径匹配而是**目录名匹配**——同时排掉 `docs/sprint/_archive`、`docs/_archive`、`scripts/_archive`。本轮只想排 `docs/sprint/_archive`（那里的引用本就是归档后的正确态），结果连 `docs/_archive`、`scripts/_archive` 里的悬空引用一起被跳过，漏了 3 处。
- **正解**：用路径限定的 exclude（`git grep -- ':!docs/sprint/_archive/'` 只排该路径，或 rg `-g '!docs/sprint/_archive/**'`），不要用 basename 级 `--exclude-dir`。
- 顺带：全仓悬空扫描优先 `git grep`（只扫 tracked、秒级），`rg` 扫 64 名 alternation 会因触到大文件/未 ignore 目录跑到 300s 超时转后台。

## 坑 3：悬空引用扫描的扩展名清单必含 .js/.yaml/.yml/.html

sprint 路径引用不只藏在 `.md`。本轮不动点收敛时，brief 给的初版 grep 只覆盖 `.md`，补扫抓到 **14 处** 在 `.js`/`.yaml`/`.yml`/`.html` 里——N9E 告警 runbook 的元数据写在 `.yaml`、死代码归档区注释在 `.js`。
- **铁律**：路径悬空扫描默认全扩展名（`git grep` 不限 glob 即全 tracked 文本文件），不要预设「引用只在 markdown 里」。

## 复用场景

下次任何「批量归档 sprint / 清理陈旧文档 / 断链重写」都过这三关：①机械清单→全量人工复核（不抽样）②exclude 用路径不用 basename③悬空扫描全扩展名。台账见 `docs/sprint/2026-07-19-bl79-doc-drift-governance/ARCHIVE-PLAN.md` §6/§8。
