---
name: project_gfw_ipdb_rum_fix_2026_06_30
description: "GFW 阶段4前置=修 RUM 地基(真实用户 IP→isp/省解析全 other);根因=地理 IP 库(ip2region/GeoLite2/IP2Location)从未在 CA 落地(HK→CA 迁移漏带)+sync-ipdb.sh ip2region URL 过时404+MaxMind/IP2Location key 不在DB;锁定免key多源=qqwry(metowolf)+ip2region(修URL)+sapics geolite2(替MaxMind),接现有IpDbBuilder多数票融合,新QqwryReader clean-room;★影响3a真实用户inert/阶段2/所有isp分段stats;spec已写feat/gfw-ipdb-rum-fix off master,待plan+实施"
metadata: 
  node_type: memory
  type: project
  originSessionId: a3a5374e-7d40-4b0c-89e2-355bce0c6e0b
---

# GFW IP 库多源 isp/省解析修复 = RUM 信号地基（2026-06-30）

GFW 阶段4（融合）的**前置**：阶段4 要融合 reach:grid(探针)+domain:report(RUM SW探活) 同 P/A 域多源（见 [[project_gfw_domain_error_beacon_phase2_2026_06_30]] 末尾纠正：融合源是探针+SW探活，**不是 domain:err**）。但发现 RUM(domain:report) **isp 100% `other`、省 0** → 无源可融 → 必先修。

## ★根因（systematic-debugging 多层验证，逐个推翻表象后坐实）
**真实用户请求 IP（v4/v6）→ isp=other/province=other，因服务器缺地理 IP 库。**
- `/newworld/iplibs/` 在 ca-admin/ca-web **目录不存在**；ip2region/GeoLite2/IP2Location 文件全无；admin 构建日志全 `not found`。
- 只有云/IDC 源(aws/azure/cloudflare/tor/ipcat/x4bnet)live 拉取 → 能分 IDC/proxy（isIdc 工作、domain:report `_idc` 键 156），但 **运营商(电信/联通/移动)+省份只能从 ip2region/qqwry 来、它们不在**。
- reach:grid(探针)为何正常分 isp？探针用**节点自带 isp 标签 `n.isp()`**，不经 IP 库（独立）。
- **provision 链从未在 CA 落地**(HK→CA 迁移漏)：`scripts/sync-ipdb.sh` 不在服务器、无 iplibs 目录、无 cron、无日志。
- 附带 bug：sync-ipdb.sh ip2region URL 过时404（抓 `ip2region.xdb`，仓库现为 `ip2region_v4.xdb`/`ip2region_v6.xdb`）。
- MaxMind/IP2Location 需 key，key **不在 system_config**（实查全表只有 IPV6_LOOKUP_ENABLED + 其他 API token）。
- **推翻的表象**（别重走）：① domain:report key 格式（Owner 联合 key 提议）—moot，没 isp/省维度可联；② IPv6 flag（IPV6_LOOKUP_ENABLED 在 admin=1、web 经 WebIpDbInitTask hourly-on-pointer-change reload）—不是主因；③ pointer 陈旧(`ipdb:entries:current`=2026-06-29 停滞、Jun30 build 异常未推进)—是 web 不 reload 的二级因，但根在地理库缺。

## ★影响面（不止 RUM，关键）
同一条 IspDetector 链 → **阶段2 domain:err、所有 isp/省分段 stats** 全 other；**★阶段3a pick-p**：真实用户→isp=other→reach:grid 无 `:other:` 格→miss→不降权 → **3a 翻 flag 对真实用户 inert**，直到本修复落地（我之前 3a 验证是手填 isp=telecom/广东 才命中，真实用户落 other 这个 caveat 漏了）。

## 锁定设计（Owner 多轮协同；spec=`docs/superpowers/specs/2026-06-30-gfw-ipdb-multisource-rum-fix-design.md`，commit 93b31f33）
**免 key 多源并集，接现有 `IpDbBuilder` 多数票融合（fuseIsp 信任级+majority / fuseProvince / confidence）：**
- **qqwry(metowolf/qqwry.dat releases/latest/download/qqwry.dat)** → 新 **QqwryReader**(clean-room 纯真解析，v4 only)+QqwryResult → CN isp/省主投票源(Owner：CN 精度好)。
- **ip2region(lionsoul，修 URL→`ip2region_v4.xdb`/`ip2region_v6.xdb`)** → 现有 Ip2RegionReader → CN 互验，v4+v6(CN v6 isp/省靠它，qqwry v4 only)。
- **sapics geolite2-city/asn(MMDB)** → 现有 GeoLite2Reader 直读(MaxMind 同 schema，CC BY-SA sapics 转存免 key) → 全球地理+ASN，替 MaxMind。
- **弃 IP2Location**(无 key + 纯地理无 ISP + 与 sapics 重叠；reader init 找不到→null 优雅降级)。**省掉 sapics vs IP2Location 的纠结：sapics 自动下载免手动 300MB BIN**。
- **不 union 全球地理**(海外对 GFW 短路、价值低、一套够)；**只 CN 并集**(qqwry+ip2region)。
- **GPL 规避**：只下 qqwry 数据 + 自写解析器，不引 GPL 代码。**不 vendoring**，走 sync-ipdb.sh 下载。

## 接口锚点(实现用，已 grep 实证)
- `Ip2RegionReader.lookup(ip)→Ip2RegionResult{country,province,city,isp,countryCode}`；initV4/initV6/Closeable；缺文件优雅降级 → QqwryReader 仿此。
- `IpDbBuilder.merge(entry, ip2r, geo, ip2loc, asnMap)` + `fuseIsp(ip2r,geo,ip2loc,asn,asnMap)`(ip2region=信任级3 主)+`fuseProvince` + `build()`/`buildV6()` → 都要加 QqwryReader 参数；调用方 admin `IpDbBuildTask` + web `WebIpDbInitTask` + 单测同步。
- 配置 `application-prod.yml`(admin+web)：ip2region v4/v6 path 不变；`geolite2.city-path/asn-path`→sapics 文件名；新增 `ipdb.qqwry.path`；ip2location 留空。
- qqwry.dat 格式：头8字节(首/末索引偏移 LE)；索引7字节(4字节起始IP LE+3字节记录偏移)；记录=国家串+区域串，0x01/0x02 重定向，GBK null 结尾，二分查找。区域字段含 isp。

## 状态（2026-06-30 实施完成，未合未部署）
plan(`docs/superpowers/plans/2026-06-30-gfw-ipdb-multisource-rum-fix.md`,e5292c23) → subagent-driven 6 task 全完成 + 全绿 + 9 轮蓝军 + opus 终审 READY TO MERGE(0 Critical/0 Important)。分支 `feat/gfw-ipdb-rum-fix` head=**3f60bce6**(off master 25aadc22，worktree `.claude/worktrees/gfw-ipdb`，本地未 push)。
- Task1 QqwryReader/QqwryResult clean-room(cf9e7239+75db7539，8 test 含 MODE_0/1/2+嵌套 b2==0x02+越界+GBK fixture)；Task2 IpDbBuilder 接 qqwry(4631a322+138efce9，**蓝军逮到 plan 自身 fuseIsp 向后兼容 bug**：原 cnResidentialIsp 让 ip2location 误覆盖具名 ASN→改 cnFineIsp 仅 qqwry/ip2region 参与 ASN 冲突覆盖，qqwry=null 字节等价 master)；Task3 admin 接线+配置(f50fa684)；Task4 web 接线+配置(cfba30e5)；Task5 sync-ipdb.sh(0934a4d1)；Task6 docs(b50a5e08+3f60bce6)。
- 全量回归：`mvn -pl newworld-common,newworld-admin -am test` exit0 + `mvn -pl newworld-web -am test` exit0。
- **两处实现期决策已定**：① sapics 文件名实证=city 仅拆分 `geolite2-city-ipv4.mmdb`(无合并版)+asn 合并双栈 `geolite2-asn.mmdb`(v4+v6 ASN 全覆盖)，下载走 **jsDelivr CDN**(GitHub release tag 404)；ip2region URL=`ip2region_v4.xdb`/`_v6.xdb`(旧名 404)。② 信任级=CN ISP qqwry>ip2region>ip2location，CN 细化源(qqwry/ip2region)冲突时覆盖 GeoLite2-ASN，ip2location 仅 ASN 缺失末位兜底。
- **★Decision A 已被 Owner fact-check 推翻→Task 7 关闭缺口(adc60bac)**：Owner 指 sapics 有 city v6；curl 仲裁=`geolite2-city-ipv4.mmdb`(28MB,200)+`geolite2-city-ipv6.mmdb`(17MB,200) **都真**，但**无合并版** `geolite2-city.mmdb`(404)；asn 才有合并双栈。→ 不接受缺口，`GeoLite2Reader` 加 `cityV6Reader`+3 参 `init(cityV4,cityV6,asn)`+lookup 按 `:` 分派(仿 Ip2RegionReader)，配置 `geolite2.city-v6-path`，sync 下载 city-ipv6，docs 改"已覆盖"。**教训：owner 业务直觉/转述必工具实证(README 转述说有合并 city，curl 实证 404 仅拆分；但 owner "有 v6" 是对的)**。
## ★★已上线并验证（2026-06-30，Owner 授权合 master+部署）—— 目标达成
- **合 master**：feat/gfw-ipdb-rum-fix → master(`d3efc0b7`，两次 --no-ff：`75e4dbf7` 含 Task1-7 + `d3efc0b7` 含 Task8)。
- **部署后实测 BEFORE→AFTER**（ca-redis-master .128 `domain:report:*` 独立重算）：isp `284 other+97 _idc，0 三网` → **telecom 183 / unicom 161 / mobile 219**；province **0 → 广东省139/江苏省115/浙江省109/湖北省66/山东省64/…**；pointer `2026-06-29`(停滞) → **2026-06-30**。7 实例(admin+web×6)全 active、0 ERROR、GeoLite2 WARN 消失、tree 148798 v4+34323 v6。**真实用户 isp/省解析恢复 → 阶段4 融合有源 + 3a pick-p 对真实用户真生效（不再 inert）+ 所有 isp/省分段 stats 恢复**。
- 部署机制：本机(34.227.205.17)maven 构建 jar→scp 7 节点(ca-admin 无 maven)；iplibs 6 文件(ip2region v4/v6 + qqwry + geolite2 city-ipv4/ipv6/asn)scp /newworld/iplibs(ubuntu+sudo，newworld:newworld 属主)；admin symlink 切具体 jar 重启、web 逐节点滚动。回滚 jar 各节点保留。
- **月度 cron 已装(Owner 选 A=ca-admin 常驻 ops)**：`/etc/cron.d/iplib-sync` = `0 2 1 * * root /newworld/scripts/sync-ipdb.sh`(早于 admin 每日 03:30 IpDbBuildTask)。前置修复：① sync-ipdb.sh web 分发改 **sudo-staging**(scp→远端/tmp→ssh sudo cp+chmod 644；因 web ssh 用户 ubuntu 无法直写 newworld 属主 /newworld/iplibs；master 86f81bca)；② ca-admin 生成专用 ed25519 key(/root/.ssh/iplib_sync)授权到 6 web ubuntu authorized_keys + /root/.ssh/config 别名→**内网 IP**(CA 172.34.1.168/.12/.115/.169 同 VPC + EU 172.33.1.58/.14.95 跨区 peering，:22 全通)。端到端真跑验证：下载 skip(fresh)+fan-out 6 web 全 success(mtime 刷新 644)。EU 跨区 ~22s/台正常。

## ★★Task 8 = 部署中发现 spec 致命假设错误（load-bearing 教训）
spec §5.3 "sapics geolite2 MaxMind 同 schema **直读**" **双重错误**，Phase 1 admin 日志 `Failed to init GeoLite2Reader: Invalid attempt to open an unknown database type: city ipv4` 暴露 → 实证(probe 真文件)：
1. **database_type 串不同**：sapics = `"city ipv4"`/`"city ipv6"`/`"asn ipvAll"`（非 MaxMind `GeoLite2-City`/`GeoLite2-ASN`）→ geoip2 **typed** `DatabaseReader.tryCity/tryAsn` 校验拒绝。
2. **city 记录布局不同**：sapics city = **扁平 DB-IP schema** `{country_code,city,state1,state2,latitude,longitude,timezone,postcode}`（无 MaxMind 嵌套 country/subdivision/city 对象、无国家名）→ geoip2 `CityResponse` 根本无法反序列化；state1=英文省名(Zhejiang)，city 常空。
3. **asn 记录一致** `{autonomous_system_organization,autonomous_system_number}`，`AsnResponse` 可直读，asn 文件 `ipVersion=6` 双栈(单 reader 服 v4+v6)。
- **修法（Task 8，bceac72a）**：GeoLite2Reader 三 reader 改 `com.maxmind.db.Reader`(底层，绕 type 校验)；ASN 复用 geoip2 `AsnResponse`；city 用静态 `SapicsCity` `@MaxMindDbConstructor` POJO 映射扁平字段。**★坑：latitude/longitude 是 32-bit `Float`，POJO 用 `Double` 会整条静默 null(无异常)→ 必 Float 再 .doubleValue()**(TDD 用 `reader.get(addr,Map.class)` 看原始类型才逮到)。
- **★可复用教训**：免key GeoIP MMDB(sapics/DB-IP-lite 转存)≠ MaxMind schema——database_type 串 + 记录布局都可能变；geoip2 typed `DatabaseReader` 会拒；改用 `com.maxmind.db.Reader.get(addr, T.class)`(无 type 校验)+ 按真实 schema 自定义 `@MaxMindDbConstructor` POJO；MMDB 数值类型(Float vs Double)不匹配=静默 null 非异常，必 `get(addr,Map.class)` 验真类型。**"同 schema 直读"类假设上线前必跑真文件验证（我栽在没验 reader 真读 sapics 文件）**。
- Owner fact-check 链(本 sprint 两次)：① "sapics 有 city v6"(README 转述)→curl 仲裁=拆分 v4+v6 真有、合并版 404 → Task 7 双 city reader；② 部署实测 GeoLite2 读不了 → Task 8 schema 适配。**owner 直觉 + 部署实测 > 设计期纸面假设**。
- **验证(部署后只读)**：ca-redis-master(.128) `domain:report:*` 出 telecom/unicom/mobile+省非0(修前 290/290 全 other)；3a pick-p 对真实用户命中 reach:grid 格。
**铁律**：worktree 隔离/off master、prod 只读验证用 ca-admin redis-cli(密码 /proc/$(systemctl show newworld-admin -p MainPID --value)/environ 取 REDIS_PASSWORD，连 .128)、DB 查 mysql -h 172.34.1.222 -u newworld -p<DB_PASSWORD from /proc> newworld、部署走 deploy 脚本+sync-ipdb.sh、mvn 绿+蓝军≥5+Owner 授权才合 master。
**其它 GFW 分支均 park**：phase1 reach 读层 / 3a pick-p reach cutover(本修复后才对真实用户生效) / 阶段2 beacon(已部署 live)。
