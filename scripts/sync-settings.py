#!/usr/bin/env python3
"""sync-settings — 把 ~/claude-shared/settings/shared.json 的"共享 key"merge 进一个账户的 settings.json,
保留账户私有 key(theme/effortLevel/hooks/statusLine/tui/notif/skipDangerousMode/账户私有 env)不动。
用法: python3 sync-settings.py <account-settings.json>   (动前自动 .bak)
共享 key: env(merge)/permissions.allow(union)/enabledPlugins(account 优先,缺则补)/
          extraKnownMarketplaces(union)/skillOverrides(merge)/disabledMcpjsonServers(union)
红线: 绝不碰 .credentials.json,只改 settings.json。"""
import json, sys, os, time

SHARED = os.path.join(os.path.dirname(__file__), '..', 'settings', 'shared.json')

def main(target):
    shared = json.load(open(SHARED))
    tgt = json.load(open(target))
    # backup
    bak = f"{target}.bak-sync-{time.strftime('%Y%m%d-%H%M%S')}"
    json.dump(json.load(open(target)), open(bak, 'w'), ensure_ascii=False, indent=2)

    # env: merge(共享 env key 设上,账户私有 env 保留)
    tgt.setdefault('env', {}).update(shared.get('env', {}))
    # permissions.allow: union(保序:账户现有 + 共享新增)
    cur = tgt.setdefault('permissions', {}).setdefault('allow', [])
    for p in shared.get('permissions', {}).get('allow', []):
        if p not in cur:
            cur.append(p)
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

    json.dump(tgt, open(target, 'w'), ensure_ascii=False, indent=2)
    print(f"  ✓ synced {target} (bak: {os.path.basename(bak)})")
    print(f"    permissions.allow: {len(tgt['permissions']['allow'])} 条 | env keys: {sorted(tgt['env'])} | plugins: {len(tgt['enabledPlugins'])}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("用法: python3 sync-settings.py <account-settings.json>"); sys.exit(2)
    main(sys.argv[1])
