---
name: feedback_cn_probe_aliyun_realbrowser
description: CN可达拨测必用aliyun真浏览器(headful Playwright via Xvfb过baxia);boce server-side游客是垃圾数据
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

CN(中国大陆)可达性拨测**必用 aliyun boce.aliyun.com 真浏览器**驱动,**禁用 boce.com server-side 游客脚本**。

**Why**: 2026-06-22 实测 boce.com 游客 server-side 脚本测 s-poc HK 得 **3%**(假),aliyun 真浏览器同域得 **99%**(真)。boce 游客 server-side 探测路径**降级**(占坑 httpCode=0 不真测);baidu 控制组 100% 掩盖了降级(baidu 全球可达不暴露)。我据 boce 3% 误判"AWS HK 被封",被 Owner 浏览器实证推翻。

**How to apply**:
- aliyun 拨测:headful Chromium via `xvfb-run`(本机无 X server;`NODE_PATH=frontend-web/node_modules` 用其 playwright)→ 导航 `boce.aliyun.com/detect/http` → 填 `#url1` → 点"立即检测" → 抓 `DescribeSiteMonitorLog` 响应(153节点,`data`需二次JSON.parse;字段 ispCN/provinceCN/HTTPResponseCode/targetIp/sslSuccess/TotalTime)。**headful via Xvfb 过 baxia 实证可行**(纯headless未验)。
- IPv6:aliyun有IPV6 radio但隐藏,`page.evaluate(()=>document.querySelector('#IPV6').click())` JS-click设表单态(baxia只护提交fetch真手势,radio态不受影响)+真点提交;验 targetIp 含`:`确认真测v6。
- 脚本骨架 `/tmp/aliyun_probe.js`(本会话);死源 itdog(application-prod.yml saas-provider)+ boce server-side 都不可信。**2026-06-26 复验(POC-FINDINGS §15-CORRECTION,纠正)**:★方法教训——验证拨测源**禁用"待测/可能坏"的域当测试目标**(我先用本会话自己搞坏的 s-poc=503 测 tcptest/boce,误判它俩垃圾);**必用已知真相域**(baidu=CN通/google=CN封)看源能否正确区分。复验结果:**tcptest.cn /http 可靠**(baidu 真延迟 0.032s 成功/google 失败97超时,111节点,无验证码)→ **可建 TcptestProbeClient**;**boce.com 游客**能出真数据但~10节点+slider_check+三档弹窗(点"游客"过)+结果DOM难抓=marginal脆;**itdog 被攻击数据极不准弃**(Owner 2026-06-26)。多源:aliyun(153主)+tcptest(111可靠二)+boce(弱三可选)+RUM真用户(金标融合)。
- 关联 [[project_gfw_s_entry_execapi_poc_2026_06_22]] / [[feedback_verify_not_recall]](Owner手动实证>我的工具,矛盾以Owner为准)。
