---
name: project-gfw-groupa-dark-deploy-2026-06-26
description: GFW组A暗部署2026-06-26完成全程(真S入口LIVE+探测管道硬化+A5验收)；组B B1是下一步(需先搞懂S入口迁移模型)
metadata: 
  node_type: memory
  type: project
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**2026-06-26 GFW 组A 暗部署一个超长会话从零干完 + A5 验收通过 + Owner 授权 G。分支 `gfw-breakthrough-arch`,未合 master。**

## 组A 交付(全实证)
- **A0** s_entry_instance 表建生产 master；**A1** web×6(CA×4+EU×2)GFW jar+前端(pick-p=401/:80=200/种子保留)；**A2** admin 探测管道;**A3** runner;**A4** 真 execute-api S 入口 LIVE。
- **A4 真机**:`qm001.silvernest26.com → 302 → {channel}.{P域}`(CF DNS→execute-api us-west-1→S-Lambda nw-s-entry 挂ca-web同VPC→pick-p :7777+secret→302)。silvernest26.com=standby暗装(零用户),s_entry_instance id=1,api_id=mwzb77c47a,cert *.silvernest26.com,custom domain dualstack。
- **探测管道五项硬化**(踩五个真bug):①bean歧义(saas-provider候选标@Primary,补GfwProbeClientWiringTest)②批量写3.5h→逐域增量③runner抢锁(DomainHealthService probe钩子Option2停用+每域aliyun/tcptest并行+runner MAX_CONCURRENT=2)④TTL固定10min→跟轮挂钩⑤skip-fresh重启断点续。**+一个假警报**:reach:grid"看似没数据"=ca-admin没装redis-cli+密码在/proc非secrets.env([[reference_redis_cli_caadmin_proc_password]])。
- **探测定时(最终)**:fixedRate **3h一轮** + reach:grid TTL=**6h**(2×重探间隔) + skip-fresh阈值3h。一轮141域实测**90min**(~39s/域,aliyun~39s/tcptest~36s差不多,都被CN节点扇出时间bound)。
- **②归一表**:ISP仅telecom/unicom/mobile/overseas,**0数据中心污染**(亚马逊/微软/谷歌/阿里巴巴过滤);港澳台、海外→overseas;省份raw交reachGridProvince唯一canonical(民族省广西/宁夏/新疆防漂移)。
- **A5 A-F全实证✅ + G Owner授权✅** → 组A收口(docs/sprint/2026-06-21-reachhint-tri-probe/A5-ACCEPTANCE-CHECKLIST.md)。

## 组B B1(下一步,动真流量,开新会话专做)
- ★**我会话尾部暴露真缺口**:连查3次渠道-S域 entry/迁移数据模型(promotion_channel_domain/channel_domain_daily_stats)全空/列名猜错——**没真正搞懂"渠道怎么从S域入口进、怎么把一个S域从edge迁到execute-api"**。组B B1前**必先精读** `docs/S_P_ARCH_V3_3.md`/`SHORT_LINK_PLAYBOOK.md`/`S_ENTRY_LUA.md` 搞懂模型。
- 组B需:①最低流量S域候选 ②高峰窗00:00-02:00采样 ③Owner每步gate ④门禁:CN可达≥老edge/302成功≥99%/pick-p命中/自愈<8min。
- 回退弹药全在(web/admin jar备份+前端dist.backup+live S域没动edge可秒回+execute-api删CNAME即下线)。

## 遗留(非阻断)
- **RUM融合**:Owner定probe-only上线(src全=probe),贝叶斯加权(w_probe0.7)+RUM留后续批次。
- **WEB_PICKP_URL单点**:S-Lambda现指单一ca-web节点172.34.1.168,组B前评估HA(内网NLB)。
- provision/rotate脚本log()改stderr已修(ARN污染bug,commit 6beb803d)。
关联 [[project_gfw_s_entry_execapi_poc_2026_06_22]] / [[feedback_feature_branch_deploy_test_then_merge]]。
