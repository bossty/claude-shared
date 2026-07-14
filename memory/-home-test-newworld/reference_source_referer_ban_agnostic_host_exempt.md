---
name: reference_source_referer_ban_agnostic_host_exempt
description: 爬虫下载段被套盗链 referer 致签名 CDN(Google Drive 等)大面积 429 断流；修法=referer-agnostic host 段豁免走默认 referer，换 IP/UA 无效唯一判别量是 referer
metadata:
  type: reference
---

# 源站段请求按 referer 限流 → referer-agnostic host 段豁免

IP 维度的姊妹坑，判别量与修法都不同，见 [[reference_source_ip_ban_dual_whitelist_flaresolverr]]（那是换出口 IP 修；本条换 IP 无效）。

## 症状（可快速识别）
某源上线后**突然从某时刻起零出片**，data 日志大量 `HttpRequestRetryExec ... responded with status 429`（重试也 429）+ `SupjavCrawlerService status 429`，请求目标是**签名 CDN 域**（如 Google Drive `lh3.googleusercontent.com/d/`）。**注意与 IP 封区分**：IP 封是 `403 + cf-mitigated: challenge`，本坑是 **429**（限流不是挑战）。

## 根因：段请求被无差别套了「播放页盗链 referer」
播放器 m3u8 的 refererOverride（如 supjav 边车传 `https://turbovidhls.com/`）在 `HlsDownloadService.effectiveReferer` 里被**无条件优先**套到每一个段请求，而 ts 段真实 CDN 是签名 URL 图床（Google Drive），对该盗链 referer 大面积 429。作者 pickReferer 注释早知"签名段落默认 referer 即可"，但 override 覆盖了正确默认。

## 决定性判别实验（区别于 IP 封的关键）
ca-admin 直连同一个 Google Drive 段，**只变 Referer 头**：
- `Referer: turbovidhls.com` → **12/12 429**
- `Referer: mmsi01.com`（pickReferer 默认）→ **12/12 200**
- 无 Referer → 200
- **换出口 IP（BuyVM proxy）/ 换 UA 均无效**（同样 429）→ **referer 是唯一判别量**。凡"换 IP 不解、换 referer 就解"= 本坑，别往 IP 封方向查。

## 修法：referer-agnostic-hosts 段豁免（分层自动）
`@Value hls.referer-agnostic-hosts`（照 geo-block/throttle 同款 lazy-set），命中 host 的请求**忽略 override、走 pickReferer 默认**。分层是自动的——逐 `url host` 判定：m3u8(播放器 host)保留 turbovidhls referer，只有段(googleusercontent host)豁免，调用方无感。默认值**窄化到只 `googleusercontent`**（未实测的 host 不写进生产默认，蓝军改进：删了抄注释的 tiktokcdn）。红绿双验：RED 禁用豁免逻辑复现 `expected mmsi01.com but was turbovidhls`。

## 治本 vs 治标
段限流（并发 4 + delay 300ms，见 BL-51 `isThrottledHost`）**压不住** Google 近期收紧的 referer 限流（BL-51 金标当天 688 段 0×429、次日 9 小时全 429）→ **referer 治本、限流治标**，两者可叠加但别指望限流单独救。

## 已知缺口（当前 supjav 不触发，未来同型源要补）
① fMP4 转码 `transcodeFmp4ToMpegTs` 用 ffmpeg 单进程单 header，无法逐段区分 referer（supjav 走标准 MPEG-TS）；② AES key 下载 `downloadEncryptionKey` 不设 Referer（supjav 正片零加密）。若未来有源同时 refererOverride + fMP4/加密 + 签名图床段，会绕过豁免复现 429。

## 同型第 5 次（新增 CF 保护/签名 CDN 源的 checklist）
"源站按某特征限流→分层豁免"已第 5 次：IP 维度 4 次（javxx/123av BL-44 ×2、hanime1 BL-50）+ referer 维度本次（supjav BL-55，merge `e3dc68ca3`，18:00 cron 真出片 118485 验证 429=0）。**新增受保护源时两个维度都要评估**：可能按机房 IP 封（→ 双白名单换出口 IP）还是按 referer 限流（→ 段豁免默认 referer），症状分别是 403/challenge 与 429。
