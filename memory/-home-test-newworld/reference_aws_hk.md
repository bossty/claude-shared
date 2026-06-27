---
name: AWS 香港生产环境
description: 2026-04-02 迁移到 AWS ap-east-1，4 台 EC2 + CF Tunnel + API Gateway 降级
type: reference
---

生产环境已从 BuyVM Las Vegas 迁移到 AWS 香港（ap-east-1）。

服务器：aws-web-01 (172.31.27.120), aws-web-02 (172.31.27.121), aws-data (172.31.27.130), aws-db (172.31.27.200)
用户：newworld，项目目录 /newworld
部署文档：docs/AWS_HK_DEPLOYMENT.md
BuyVM 观察期中，暂未释放。
CLAUDE.md 部署命令仍为 BuyVM 格式（web-01/web-02/data/db），AWS 部署参考 docs/AWS_HK_DEPLOYMENT.md。
