---
name: reference_crawler_dryrun_id_collision_mock_llm
description: 爬虫 dry-run 三铁律 — AUTO_INCREMENT 高置防 R2 撞键 / mock LLM 破非确定性门 / buyvm-db 备份 schema 漂移
metadata: 
  node_type: memory
  type: reference
  originSessionId: b41396b9-50bd-45e1-90ca-888b7867fe62
---

**爬虫行为保持 dry-run（before/after 双 jar 打真 R2 diff）三铁律**（2026-07-03 pilot Task9 实证）：

1. **★隔离库 `movie.AUTO_INCREMENT` 必设远超生产的高值(如 90000000)**。否则继承生产备份烘焙的 AUTO_INCREMENT，测试影片拿到**生产区间 id**，而 R2 中 **id 键控对象会撞生产键**：cover `{PATH_COVER}/{movieId}.js`、preview/thumb 同理、**m3u8 `{PATH_SEGMENTS}/playlist_{movieId}.m3u8`**(最狠：覆盖=生产影片播错视频)。R2 无版本→原对象丢失不可回滚。mysqldump 默认把 `AUTO_INCREMENT=N` 烘进 CREATE TABLE。判撞键:HEAD 对象看 lastmod(当日=我写)+ 同 id 是否有旧命名构件(旧=生产真存在)。

2. **采集链路有强制非确定性 LLM 富化门 → 用确定性本地 mock**。`ContentAnalysisService` 现行:LLM 返 null 抛 `LlmAnalysisFailedException` 跳过入库(旧"兜底原文仍 INSERT"路径已删)。`OPENAI_API_KEY` 在生产 system_config(隔离拿不到)。解:mock OpenAI 服务(`OPENAI_ENDPOINT` env 覆盖，`callOpenAI`/`translateTitle` 都优先读该 env)——translate 请求(无 `response_format`)回显标题；analyze 请求(有 `response_format`)回 `{"results":[{title,categories:[],tags:[]}]}` 每编号行一条。两 jar 打同 mock→富化一致→diff 纯反映编排重构。system_config 需种子 `OPENAI_API_KEY='mock'`。

3. **buyvm-db 离线备份 schema 漂移**(约 4 月版)：`movie` 表当前，但缺 `movie_tag.aliases/description`、`movie_category.aliases`、`movie_actor.region`、`movie_tag_category.sort_order`、整个 `source_tag_mapping` 表。爬虫读 tag 字典(prompt 构建)会 `Unknown column 'aliases'` 硬失败。补丁列/表按当前 entity 加。爬虫 v3 架构**不写 movie_segment 表**(m3u8 静态文件)，故备份缺该表无碍。

**运维坑**：SSH 里 `pkill -f "xxx"` 会匹配到 ssh 自身 shell 命令行(含 xxx)→自杀→命令截断；改 `ps|grep xxx|grep -v grep|awk '{print $2}'|xargs kill`。判服务停用端口(`ss -ltn|grep :port`)非 pgrep(会自匹配)。

详见 [[project_crawler_pilot_task9_dryrun_2026_07_03]]。爬虫节点/R2 桶见 [[reference_buyvm_crawler_assignment]] / VideoConstants(PATH_COVER=dba8c29b…/PATH_SEGMENTS=f0583267…/BUCKET_IMAGE=bucket-image/BUCKET_VIDEO=bucket-video)。
