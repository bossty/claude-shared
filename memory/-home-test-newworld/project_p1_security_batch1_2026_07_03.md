---
name: project_p1_security_batch1_2026_07_03
description: full-code-audit(docs/sprint/2026-07-02)批次1 P1安全5项修复→部署ca-admin验证→合master 16fdec6c;含fail-closed(内部secret)/fail-open(探针基础设施)/ffmpeg去file防LFI/CF请求超时/DoH群体误封防护5个可复用安全pattern+CI headless修复+ca-admin部署布局实测;批次0(feat/recently-watched最近观看)未部署
metadata: 
  node_type: memory
  type: project
  originSessionId: d76fb9cf-1666-4b34-af62-e043512db8b3
---

# 全代码审计批次1 P1安全 sprint（2026-07-03）

真相源清单 `docs/sprint/2026-07-02-full-code-audit/FINDINGS.md`（~113条=2P0+24P1+87P2）。审计规范：先分析后修、`finder`项逐条亲证真伪、误报不改、修前Owner复核每项。抑制清单 `docs/audit-suppressions.md` 审计前必读。

## 批次1：5项P1安全（合master `16fdec6c` --no-ff，各带测试，已部署ca-admin验证）
每项修法都是**可复用安全pattern**：
- **P1-7 内部端点 fail-closed**：3个`@PermitAll`内部CDN端点(provision-rotate真实NameSilo买域扣费/cdn-pool rotate CF改绑/cdn-prefix expand)仅靠`X-Internal-Secret`,`@Value(":changeme")`默认。原`!secret.equals(provided)`在未配(=changeme)时发changeme即过=fail-open。修=每控制器加`unauthorized(provided)`helper:secret为null/空/changeme一律拒(对齐`OpsController.checkSecret` line139的`expected.isEmpty()`fail-closed)。**★prod实测INTERNAL_API_SECRET已配强值(len=25)→fail-closed不误伤合法调用**。
- **P1-11 ffmpeg去file防LFI**：`HlsDownloadService.transcodeFmp4ToMpegTs`用`ffmpeg -i <远程爬取m3u8>`,`-protocol_whitelist`含`file`→恶意`#EXT-X-KEY:URI="file:///etc/passwd"`读本地文件(buyvm-data有R2密钥/secrets.env)。修=提取`HLS_INPUT_PROTOCOL_WHITELIST="http,https,tcp,tls,crypto"`(去file)。**★输出写本地文件由输出muxer管、不受`-i`前input whitelist约束,去file不影响写出**。残留:http/https SSRF(拉内网/云元数据)是远程HLS固有,需egress过滤另修。
- **P1-6 禁UI设/改super防提权**：`UserManageController(@RequireMenu USER_MANAGE"超管专属")`调的`createUser/updateUser`接受任意role含super、无operatorRole硬校验(带校验的`changeRole`/`deleteUser(Long,String)`存在却**零调用方**)。Owner定=super走SQL带外(同SystemConfig新增走SQL)。修=create/update拒role=super + updateUser拒改动现有super(含重置super密码/降级)。零auth管线改动即封死"提权到super"。
- **P1-9 CF API响应超时**：`CloudflareApiService.httpClient`只设`connectTimeout(10s)`(仅管建连),8处`HttpRequest.newBuilder()`无per-request`.timeout()`→CF半开连接使`send()`在@Scheduled线程**永久park**冻结域名池自动化。修=加`cfRequestBuilder()`helper带`CF_REQUEST_TIMEOUT=20s`,replace-all 8处走它。**★`HttpTimeoutException`是`IOException`子类→被`executeWithRetry`的catch(IOException)当transient重试→耗尽抛CfTransientException,总时长有界**。
- **P1-10 DoH fail-open防群体误封**：`DohHealthCheckTask.checkDomain`某域名4个DoH商全失败→连续3轮→标blocked+onDomainBlocked(摘除/改配)。若DoH探针基础设施故障(admin出网被封/4商全不可达)则**每个**B/dns-config域名全失败→群体误封。修=重构check()为**探测→fail-open守卫→记录/封锁**:★本轮零域名健康=探针故障,判定作废(不记历史/不标blocked);仅探针确认工作(≥1域名可达)才封持续失败域名。对齐GfwProbeClient fail-open。残留:仅1个dns-config域且真被封时无法与探针故障区分→保守不误封。

## ca-admin 部署布局（实测，扩展 [[reference_ca_admin_deploy_model_2026_06_21]]）
- **两service**:`newworld-admin.service`+`newworld-data.service`(单实例都在ca-admin=.34,SSH user=ubuntu免密sudo,宿主无mvn)。
- **jar布局**:ExecStart用`/newworld/newworld-{admin,data}/deploys/current.jar`(symlink→dated jar `日期-label-sha.jar`);上传暂存`/newworld/disktmp/`;dated jar root属主→写需sudo。
- **部署SOP**:本地`mvn package -pl newworld-admin,newworld-data -am`→scp到disktmp→`sudo cp`进deploys+`sudo ln -sfn`存`current.jar.bak-pre-<label>`回滚指针+原子换current.jar→`sudo systemctl restart`。回滚=repoint bak+restart。
- **验证**:admin有actuator`:18080`(`/actuator/health`→`{"status":"UP"}`);**★data是爬虫无HTTP actuator**,看`systemctl is-active`+`NRestarts=0`(无crash-loop)+journalctl`Started DataApplication`banner。data重启期间旧进程优雅关闭会抛InterruptedException中断在途LLM/爬取任务(benign,非部署故障)+爬虫常规噪声(源站抽取/LLM分析失败)与部署无关。
- 「unit file changed on disk, run daemon-reload」是pre-existing警告(有人改unit没reload)。

## CI headless 修复（合master `4217fb98`）
- 根因:全局`DISPLAY=:99`(/etc/environment+.bashrc)但**无Xvfb**;surefire fork测试JVM**不继承MAVEN_OPTS**,根pom `argLine`缺headless→`R2UploadServiceV5Test`等做AWT图像处理的测试抛`java.awt.AWTError: Can't connect to X11`(7 errors)。
- 修=根pom(唯一surefire配置)`<argLine>`加`-Djava.awt.headless=true`→纯软件渲染不连X11→11 tests全绿(DISPLAY=:99仍在证明真修)。
- **★附带:根pom `<skipTests>false</skipTests>`硬编码=之前"-DskipTests被pom无视"之因;要跳测试用`-Dmaven.test.skip=true`(跳编译+运行)**。

## 未做（backlog）
- **批次0**在`feat/recently-watched`(最近观看async best-effort+monitor bucketInfix+死代码删+附录7/9抑制,已提交`b7839755`+`627c6ab2`)**未部署**,可另议部署批次。
- 剩余P1:P1-1~5/8(web/common:ConfigController请求线程写/StatsCoalescingBuffer/feed游标/afterCommit/渠道双计)、P1-14~20(前端泄漏/openresty SNI)、P1-21/22(MySQL密码进git+root==app,**运维级**:轮换/scrub git史非纯代码)、P1-23(import-all.sh缺迁移)。
- P2~87条。
