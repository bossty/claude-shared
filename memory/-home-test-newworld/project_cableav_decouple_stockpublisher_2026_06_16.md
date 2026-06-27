---
name: project_cableav_decouple_stockpublisher_2026_06_16
description: "2026-06-16 cableav 采集/上线解耦 + StockPublisher 定时上线标准组件;cableav.video 源探明(绕封锁但带水印)最终作废、代码保留;pilot 三关(og-meta/hardCap-env/水印)"
metadata:
  node_type: memory
  type: project
  originSessionId: ce27c9bf-720e-4350-ba00-8892b604bf34
---

2026-06-16 接 [[project_region_hourly_guarantee_2026_06_15]] cableav 老 host 封锁问题,owner 改"采集/上线解耦"架构。最终 cableav 两源皆废、冻结老 402,但产出可复用标准组件。

## 起因链(owner 多轮拍板)
1. cableav.info 老内容 host(picc.sex8sex855 Read超时 / xing.sex8sex833 geo-403连buyvm代理也403)封我方IP→backfill 0入库(非死内容,是拦截;owner直觉纠我"死密钥/fMP4"表面误判)。
2. owner 找到 **cableav.video** 另一入口:新CDN(t0.97img.com/cdn2020.com)data出口直连200+下载1.68MB/s,**绕过封锁**,SSR无CF。
3. owner 定**采集/上线解耦**:buyvm全量采→status=3存量(不上线),cableav移出每小时,新增每小时"从存量上线1部"标准任务。
4. ★**最终 owner 判 cableav.video 与 cableav.info 不是同一视频(带水印)→源作废、代码保留**。cableav 冻结老402(两源皆不可用)。

## 交付的标准组件(merge master bad45c75,mvn 715 绿,**可复用,价值在此**)
- **采集/上线解耦**:movie.status 新增 **3=存量**(已采待上线,用户不可见);采集 finalize→status=3(**不 addToBloom**)、上线由 StockPublisher 负责。状态机 0草稿/1上线/2dead/3存量。
- **StockPublisher 标准**(`StockPublisher.java`+`StockPublishConfig`@ConfigurationProperties prefix=crawler.stock-publish):`publishOne(source,batch)`从 status=3 挑N(默认1,publish_desc=create_time DESC)→ `UPDATE status=1,create_time=NOW() WHERE id=? AND status=3`(乐观锁守卫,affected=0跳过)+CONTENT_VERSION+1+addToBloom。`StockPublishScheduledTask` 每小时(cron :30)对 enabledSources publishOne。**后续源套用:采集置status=3 + 加enabled-sources即可**。
- **去重**:`movie_number="cableav-v{infoid}"`(cableav.video info-id稳定post-id)+findByMovieNumbers;**跨站(老cableav-NNNNN=cableav.info watch-id↔新info-id)无映射、番号被老LLM从title剥(402仅2留)、movie表无番号列→跨站去重不可能,认0.5%重叠**(owner校正:老402视频在R2播放正常,源host死不影响播放→重叠跳过不重采,非替换)。
- migration `sql/2026_06_16_idx_movie_stock_source.sql`(source,status,create_time复合索引)。

## ★pilot 哲学:小量先跑揪出 3 个 prod-scale-only bug(没盲推全量)
owner定"先1-2部跑通再全量"。pilot(aws-ca-admin采1页)连揪:
1. **title占位**:parseDetail整套靠og:meta,但**cableav.video无任何og标签**(实证全空),title在`h1.entry-title`/`<title>去" - CableAV"`→回落movie_number占位、封面og:image空走首帧。修=按真实HTML提取。
2. **12卡片只入1部**:根因=systemd env `CRAWLER_CABLEAV_HARD_CAP_PER_RUN=1`(细水长流时代节流闸),bulk采集误复用→crawlIds capRemain=1采1部就break、剩11个crawlOneItem返skipped()不计数凭空消失。修=crawl-pages加cap参数(默认1000)与hourly hardCapPerRun解耦+skipped计数。
3. **水印**:owner肉眼发现cableav.video带水印≠cableav.info→源作废。**pilot拦住2598部水印片入库**。
- 教训:**isolated-test-pass≠prod-scale-pass;pilot小量先验是对的**。诊断靠runtime实证(curl看og缺失/proc-env挖出cap=1/肉眼看水印),非静态猜。

## 收尾(止血+拆台,全干净)
- 水印污染:pilot+ops误跑(旧jar无parseDetail修)共产18行cableav-v→**全置status=2**(下线+不可上线+不re-crawl);2部曾live的+CONTENT_VERSION bump 1855→1857→用户无感。**老cableav-NNNNN 402 status=1不动**。
- buyvm全量abort:ops拆台(jar停/tunnel关13306/16379),**全程SSH tunnel经aws-ca-admin跳板,AWS SG·ufw·MySQL grant·Redis配置零改动**(owner的"SG开端口给buyvm白名单"方案提了但暂停未执行)。
- ★**git共享仓库坑**:首次merge(acbbc006)后**另一会话把本地master reset到97cb6423(frontend工作)→我的合并被挤出HEAD线**(代码没丢=在branch+commit,但不在master HEAD)。owner要求重并→`git merge sprint分支`进97cb6423=bad45c75,8dd80ad9已在master。**教训:共享本地仓库未push的commit会被别会话reset挤掉,关键工作及时确认在master HEAD/或push**。

## 可复用坑/方法论
- owner业务直觉再次碾压技术抽象(拦截非死内容/cableav.video水印/重叠跳过非替换/编号去重边界)——先当严肃提案fact-check。
- lead二查兜底:dev被context-mode hook拦mvn=结构性盲改,屡交带编译错(Map<Object>用Integer::sum、updateById(any())歧义、assertEquals歧义)+漏改owner关键项(title=raw漏一次、P7测试漏改、蓝军F1-F7漏整批)→lead每轮经ctx跑mvn+grep逐行+直查DB,机械错直接接管修最快,别空转往返。
- 蓝军真BLOCKER:StockPublisher.doPublish @Transactional**自调用失效**(fullcut-5xx同类坑)→@Lazy self代理;lead又把蓝军过度定级的F2(锁不释放"漏采")按代码实证降MINOR(status检查先于锁,成功片被status跳过到不了锁逻辑)。
- 安全红线:status=3绝不泄漏→web取片49处=1精确(grep实证),findStockMoviesBySource仅StockPublisher调;采集禁addToBloom(只上线时add)。
