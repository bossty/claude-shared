#!/usr/bin/env python3
"""sync-settings — 把 ~/claude-shared/settings/shared.json 的"共享 key"merge 进一个账户的 settings.json,
保留账户私有 key(theme/effortLevel/hooks/statusLine/tui/notif/skipDangerousMode/账户私有 env)不动。
用法: python3 sync-settings.py <account-settings.json>   (动前自动 .bak)
共享 key: env(merge)/permissions(shared 整段覆盖,2026-07-22 起)/enabledPlugins(account 优先,缺则补)/
          extraKnownMarketplaces(union)/skillOverrides(merge)/disabledMcpjsonServers(union)
红线: 绝不碰 .credentials.json,只改 settings.json。"""
import json, sys, os, time

SHARED = os.path.join(os.path.dirname(__file__), '..', 'settings', 'shared.json')

def main(target):
    shared = json.load(open(SHARED))
    tgt = json.load(open(target))
    orig = json.load(open(target))

    # env: merge(共享 env key 设上,账户私有 env 保留)
    tgt.setdefault('env', {}).update(shared.get('env', {}))
    # permissions: 以 shared 为准整段覆盖(2026-07-22 由"并集只增"改语义)——
    # 手改账户文件会被 cron 纠回,删条目自动传播;"唯一改法=改 shared.json"从纪律变机制。
    # shared 里没定义的 key(如 ask/deny)不动,项目级 settings.local.json 与本机制无关。
    perm = tgt.setdefault('permissions', {})
    for k, v in shared.get('permissions', {}).items():
        perm[k] = v
    # enabledPlugins: 账户已声明的保留(如 B 的 newworld:false),共享里有而账户没有的补上
    ep = tgt.setdefault('enabledPlugins', {})
    for k, v in shared.get('enabledPlugins', {}).items():
        ep.setdefault(k, v)
    # extraKnownMarketplaces: union(账户优先)
    mk = tgt.setdefault('extraKnownMarketplaces', {})
    for k, v in shared.get('extraKnownMarketplaces', {}).items():
        mk.setdefault(k, v)
    # skillOverrides: merge(共享的 ecc-off 设上)
    tgt.setdefault('skillOverrides', {}).update(shared.get('skillOverrides', {}))
    # disabledMcpjsonServers: union
    dm = tgt.setdefault('disabledMcpjsonServers', [])
    for s in shared.get('disabledMcpjsonServers', []):
        if s not in dm:
            dm.append(s)

    # 无变化则不写盘不留 .bak —— 供 cron 高频跑而不攒备份垃圾
    if tgt == orig:
        print(f"  = 无变化 {target}")
        return
    bak = f"{target}.bak-sync-{time.strftime('%Y%m%d-%H%M%S')}"
    json.dump(orig, open(bak, 'w'), ensure_ascii=False, indent=2)
    json.dump(tgt, open(target, 'w'), ensure_ascii=False, indent=2)
    print(f"  ✓ synced {target} (bak: {os.path.basename(bak)})")
    print(f"    permissions.allow: {len(tgt['permissions']['allow'])} 条 | env keys: {sorted(tgt['env'])} | plugins: {len(tgt['enabledPlugins'])}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("用法: python3 sync-settings.py <account-settings.json>"); sys.exit(2)
    main(sys.argv[1])
