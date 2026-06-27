---
name: reference_zerodowntime_peak_validation_3source
description: 零停机滚动部署的三源金标验证法（峰窗实测真零停机，2026-06-16 实战）
metadata: 
  node_type: memory
  type: reference
  originSessionId: c180f4de-418c-4673-8b1e-24d8e011d4e9
---

**零停机滚动部署「是否真零停机」的三源独立金标验证法**（2026-06-16 web 6 节点峰窗 --force-peak 实战，全程 BAD=0 实测通过）。

## 机制（v4 零停机，被验证有效）
每节点：`cloudflared 全程不停 + 仅 JVM systemctl restart + nginx 同区 backup failover(127 primary max_fails=2 + 同区 backup max_fails=0) + peer-ready gate(重启前验同区≥1 backup :7777 200) + warm gate(重启后预热+p50<50ms+业务端点 streak 才放量)`。消掉了「停 cloudflared 的 CF 检测窗口」+「冷 JVM→死 backup→no-live 502」两个 Phase-1 黑窗。

## 三源金标（缺一不可，单源会骗）
1. **端到端公网探针全窗连续**：`curl https://<内容域>/api/v1/settings?cb=<nonce>` 每 1s 打、记任何非 2xx/3xx。= 用户可见 5xx 实时信号（含跨午夜进峰窗）。**必全窗非子窗**（fullcut-5xx 教训）。
2. **逐节点 nginx error.log `no live upstreams` 计数**（= Phase-1 那个 502 签名）：部署窗口内全 0 = failover 真兜住。
3. **新 jar md5 逐节点比对**：证改动真上线（非只「服务活」）。

实战值：探针 780 样本 BAD=0、6/6 节点 no-live=0、6/6 jar md5 一致。EU 2 节点薄池最吃紧一跳（唯一 backup 刚重启完接棒）也零 5xx。

## 监控法
用 Monitor tail 部署日志 + 探针日志，filter 节点完成/peer-gate/warm p50/FATAL/★BAD/DONE。EU JVM 启动 ~38s（>CA 16s），warm gate liveness 轮询会多等几十秒=正常非卡死（直接 ssh 查 readiness 阶段实证，别凭 Monitor 静默猜卡住）。

## off-peak guard
deploy-web.sh 默认拒 20:00-03:00 HKT（Phase-1 反面教材），--force-peak 需 owner 授权。owner 可主动选峰窗部署来「实战检验零停机」——但前提是机制已被 canary 证过，否则别赌。

关联 [[project_perf_rca_zerodowntime_2026_06_16]] [[project_zero_downtime_hostid_2026_06_16]]。
