---
name: BuyVM 3 机爬虫分工（2026-04-19 起）
description: 哪台 BuyVM 跑哪个源，systemd drop-in 配置位置
type: reference
originSessionId: f4505e91-c990-4d2b-9f8a-0e74e2ca4ce8
---
## 分工

| 服务器 | profile | 资源 | 负责源 |
|---|---|---|---|
| **BuyVM web-01** | prod (2C8G buyvm-small) | 小 | avjiali Python `/tmp/avj_bulk.py`（Java 爬虫不启） |
| **BuyVM web-02** | prod (4C16G buyvm-large) | 大 | **beeg + hanime** |
| **BuyVM data** | prod (4C16G) | 大 | **jable + pornhub + xvgay + xvtrans + porcore** |

## systemd 配置位置
每台 `/etc/systemd/system/newworld-data.service.d/crawler-assignment.conf`：

```ini
[Service]
# 源开关（@ConditionalOnProperty 要求）
Environment=APP_CRAWLER_BEEG_ENABLED=true
Environment=APP_CRAWLER_HANIME_ENABLED=true
# 调度开关（让 @Scheduled 定时任务生效）
Environment=APP_SCHEDULING_ENABLED=true
```

改完 `sudo systemctl daemon-reload && sudo systemctl restart newworld-data`。

## 手工触发 bulk endpoint（验证/灰度）
- `POST /crawler/beeg/crawl-pages?startOffset=0&endOffset=1600`
- `POST /crawler/hanime/crawl-pages?startPage=1&endPage=10`
- `POST /crawler/movie/crawl-range?startPage=1&endPage=3` (jable)
- `POST /crawler/pornhub/crawl-pages?startPage=1&endPage=5`
- `POST /crawler/porcore/crawl-pages?startPage=0&endPage=5`
- `POST /crawler/xvgay/crawl-tag?tag=gay-asian&page=0&maxItems=100`
- `POST /crawler/xvtrans/crawl-tag?tag=crossdresser&page=0&maxItems=100`

## 注意事项
- sudo 会报 `unable to resolve host web-02` —— **不影响**，命令照常执行（web-02 `/etc/hosts` 没加自指映射）
- 爬虫内部同步 HTTP 触发，curl 会一直等待 → 用 `nohup ... &` 后台
- aws-data 有 geo 限制，OpenAI 403；BuyVM 美国 IP 可调 LLM，所以爬虫必须在 BuyVM 跑
