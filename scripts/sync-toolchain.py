#!/usr/bin/env python3
"""sync-toolchain — 双向自动同步两账户的共享配置(settings 层)。

机制(harvest → apply):
  1. harvest: 从 A/B 两账户 settings.json 采集"共享域"的新增项进 shared.json
     (只加缺失 key,绝不改已有值 —— 账户已声明的值永远优先,与 sync-settings 语义一致)
  2. apply : 把 shared.json 灌回两账户(同样 setdefault 语义,私有 key 不动)

共享域(harvest+apply): enabledPlugins / permissions.allow / extraKnownMarketplaces /
                        skillOverrides / disabledMcpjsonServers
只 apply 不 harvest: env(shared.json 里人工 curated,防账户私有 env 互串)

私有 key 永不碰: model / effortLevel / hooks / theme / tui / statusLine / notif 类 /
                skipDangerousModePermissionPrompt 等一切不在共享域列表里的顶层 key。

触发: 两账户 SessionStart hook + 每日 backup cron。幂等;无变更不写盘不留 bak。
红线: 绝不碰 .credentials.json / .claude.json。
用法: python3 sync-toolchain.py [--quiet] [--dry-run]
"""
import json, os, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, 'settings', 'shared.json')
ACCOUNTS = ['/home/test/.claude/settings.json', '/home/test/.claude-work/settings.json']
QUIET = '--quiet' in sys.argv
DRY = '--dry-run' in sys.argv

def log(*a):
    if not QUIET: print(*a)

def load(p): return json.load(open(p))

def save_if_changed(path, new, old_raw):
    new_raw = json.dumps(new, ensure_ascii=False, indent=2)
    if new_raw == old_raw:
        return False
    if DRY:
        log(f'  [dry-run] 将写 {path}'); return True
    bak = f"{path}.bak-sync-{time.strftime('%Y%m%d-%H%M%S')}"
    open(bak, 'w').write(old_raw)
    open(path, 'w').write(new_raw)
    # 每账户只留最近 3 份 sync bak
    d, base = os.path.dirname(path), os.path.basename(path) + '.bak-sync-'
    baks = sorted(f for f in os.listdir(d) if f.startswith(base))
    for f in baks[:-3]: os.remove(os.path.join(d, f))
    return True

def dict_add_missing(dst, src):
    """src 里有而 dst 没有的 key 补进 dst(不覆盖已有值)。"""
    for k, v in (src or {}).items():
        dst.setdefault(k, v)

def list_union(dst, src):
    for x in (src or []):
        if x not in dst: dst.append(x)

REGISTRY = '/home/test/.claude-work/plugins/installed_plugins.json'  # 两账户共享(A 的 plugins 目录 symlink 到 B)

def installed_set():
    """已安装 plugin 集合;登记文件读不到/为空时返回 None(此时跳过修剪,fail-open)。"""
    try:
        keys = set(load(REGISTRY).get('plugins', {}).keys())
        return keys or None
    except Exception:
        return None

def main():
    shared_raw = json.dumps(load(SHARED), ensure_ascii=False, indent=2)
    shared = json.loads(shared_raw)
    accts = {}
    for p in ACCOUNTS:
        raw = json.dumps(load(p), ensure_ascii=False, indent=2)
        accts[p] = (json.loads(raw), raw)

    # ---- 0. prune: 以共享安装登记为准,清掉"已卸载但残留"的 enabledPlugins key ----
    #        (让卸载也能双向传播;登记读不到时 fail-open 不修剪)
    inst = installed_set()
    if inst:
        for s in [shared] + [s for s, _ in accts.values()]:
            ep = s.get('enabledPlugins') or {}
            for k in [k for k in ep if k not in inst]:
                del ep[k]

    # ---- 1. harvest: 账户 → shared(只加缺失) ----
    for p, (s, _) in accts.items():
        dict_add_missing(shared.setdefault('enabledPlugins', {}), s.get('enabledPlugins'))
        list_union(shared.setdefault('permissions', {}).setdefault('allow', []),
                   (s.get('permissions') or {}).get('allow'))
        dict_add_missing(shared.setdefault('extraKnownMarketplaces', {}), s.get('extraKnownMarketplaces'))
        dict_add_missing(shared.setdefault('skillOverrides', {}), s.get('skillOverrides'))
        list_union(shared.setdefault('disabledMcpjsonServers', []), s.get('disabledMcpjsonServers'))

    changed = save_if_changed(SHARED, shared, shared_raw)
    if changed: log(f'✓ harvest → {SHARED}')

    # ---- 2. apply: shared → 各账户(setdefault,私有值不动) ----
    for p, (s, raw) in accts.items():
        s.setdefault('env', {}).update(shared.get('env', {}))
        dict_add_missing(s.setdefault('enabledPlugins', {}), shared.get('enabledPlugins'))
        list_union(s.setdefault('permissions', {}).setdefault('allow', []),
                   shared.get('permissions', {}).get('allow'))
        dict_add_missing(s.setdefault('extraKnownMarketplaces', {}), shared.get('extraKnownMarketplaces'))
        dict_add_missing(s.setdefault('skillOverrides', {}), shared.get('skillOverrides'))
        list_union(s.setdefault('disabledMcpjsonServers', []), shared.get('disabledMcpjsonServers'))
        if save_if_changed(p, s, raw):
            log(f'✓ apply → {p}')

    log('sync-toolchain 完成')

if __name__ == '__main__':
    main()
