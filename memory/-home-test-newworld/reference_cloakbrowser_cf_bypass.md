---
name: reference_cloakbrowser_cf_bypass
description: "CloakBrowser(隐身Chromium过CF)评估结论=暂不上,留作FlareSolverr顶不住时的升级后备"
metadata: 
  node_type: memory
  type: reference
  originSessionId: ce27c9bf-720e-4350-ba00-8892b604bf34
---

**CloakBrowser** (github.com/CloakHQ/CloakBrowser,26k★):源码级 58 处 C++ 指纹补丁的隐身 Chromium,drop-in Playwright/Puppeteer 替代,过 CF Turnstile/FingerprintJS/reCAPTCHA v3(0.9)。`pip/npm install cloakbrowser` 二进制自动下载。

**2026-06-15 评估结论:当前不上,留作后备。**
- ❌ **仅 Python+JS,无 Java 绑定**——我们爬虫是 Java(PlaywrightUtil),不能 drop-in。
- ❌ 当前 CF 挑战(hanime1/jable)**FlareSolverr 已解决**(实测 200/106KB+86KB),CloakBrowser 不增量。
- ⚠️ 自承"some sites detect headless even with C++ patches",演示是 headed——我们无头 Linux 要 Xvfb;README 还推荐配住宅 IP(我们是数据中心 IP)。
- ⚠️ 许可证:wrapper MIT;binary "免费商用、不可再分发、厂商自动更新"(供应链/可用性依赖);商用免费(无 fee)。

**★2026-06-15 实跑 POC（aws-ca-admin docker,用完已删）+ owner 定:不替 FlareSolverr,CloakBrowser 留后备。**
- POC 实测隐身**真强**:cloakbrowser 0.3.31/Chromium146,bot.sannysoft 56/56、reCAPTCHA v3 0.9、jable.tv CF JS 挑战 **1.6s 突破返 24 卡真内容**(vanilla Playwright/camoufox 做不到,PlaywrightUtil:200 实证);**headless 直接可用无需 Xvfb**。
- 服务化:`cloakhq/cloakbrowser-manager`(:8080)有 REST+CDP,但**无 FlareSolverr 那种一步式 POST→HTML**,Java 要自写 CDP 客户端(launch profile→cdp_url→CDP WS navigate)——集成比 FlareSolverr 重。
- **关键限制:浏览器只解指纹/JS 层,解不了 IP 层**。POC 里 hanime1(CA IP fresh session)返 403、cableav 老封面返 "region denied"——都是 IP/地域维度,CloakBrowser 同样过不去(需代理/换出口 IP)。
- **不替 FlareSolverr 的依据**:FlareSolverr 现状健康(172MB/15h/0 重启);当年 data OOM 是内置 Playwright chromium(cgroup 欠配已修),非 FlareSolverr;CloakBrowser 也是 Chromium **不省内存**(每实例~200-400MB)、集成更重。→ 不为不存在的内存问题动正在工作的基建。
- **后备触发条件**:FlareSolverr 遭 FingerprintJS 级深度指纹检测顶不住时,上 CloakBrowser-Manager(docker:8080)Java 走 CDP 调。**注意它替不了代理(IP-geo)。**
- ★**2026-06-26 Owner 点名第二用例 = GFW 拨测 runner**:`aliyun-probe-runner`(headful Playwright 驱动 boce.aliyun.com 过 baxia / tcptest.cn 带 sec+sign 反爬签名头)若被反爬升级顶不住,**拿 CloakBrowser drop-in 替 runner 里的 chromium**。当前 headful+Xvfb 够用未上,留备用。Owner 定 aliyun+tcptest **都走此 runner(不拆 tcptest 直连)**——直连要复刻 sec/sign 签名脆,浏览器天然生成稳。

关联 [[project_data_hourly_collection_fix_2026_06_15]] / [[feedback_cn_probe_aliyun_realbrowser]]。
