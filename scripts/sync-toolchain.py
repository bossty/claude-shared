#!/usr/bin/env python3
"""sync-toolchain — 双向自动同步两账户的共享配置(settings 层)。

机制(harvest → apply):
  1. harvest: 从 A/B 两账户 settings.json 采集"共享域"的新增项进 shared.json
     (只加缺失 key,绝不改已有值 —— 账户已声明的值永远优先,与 sync-settings 语义一致)
  2. apply : 把 shared.json 灌回两账户(同样 setdefault 语义,私有 key 不动)

共享域(harvest+apply): settings.json 全部顶层键(2026-07-08 Owner 定"除账户ID全共享";
                        账户身份在 .credentials.json/.claude.json,不在 settings,红线不碰)
2026-07-08 起 enabledPlugins / env 移交 /etc/claude-code/managed-settings.json 托管
(对所有账户强制生效、优先级最高),本脚本不再同步这两键。改 plugin 启停/共享 env
一律 sudo 改 managed-settings.json。

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
    new_raw = json.dumps(new, ensure_ascii=False, indent=2, sort_keys=True)
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

def main():
    shared_raw = json.dumps(load(SHARED), ensure_ascii=False, indent=2, sort_keys=True)
    shared = json.loads(shared_raw)
    accts = {}
    for p in ACCOUNTS:
        raw = json.dumps(load(p), ensure_ascii=False, indent=2, sort_keys=True)
        accts[p] = (json.loads(raw), raw)

    # ---- 0. 清理: enabledPlugins/env 已移交 managed-settings 托管,擦掉残留防混淆 ----
    for s in [shared] + [s for s, _ in accts.values()]:
        s.pop('enabledPlugins', None)
        s.pop('env', None)

    # ---- 1. harvest: 账户 → shared(只加缺失;2026-07-08 起全键同步,Owner 定"除账户ID全共享") ----
    #      账户身份不在 settings.json(在 .credentials.json/.claude.json,红线不碰),故可全键。
    #      语义不变:标量 setdefault、dict 补缺失 key、list 并集;已声明的值永远优先,不覆盖。
    def merge_into(dst, src):
        for k, v in (src or {}).items():
            if k in ('enabledPlugins', 'env'):
                continue  # managed-settings 托管
            if isinstance(v, dict):
                dict_add_missing(dst.setdefault(k, {}), v)
            elif isinstance(v, list):
                list_union(dst.setdefault(k, []), v)
            elif v is not None:
                dst.setdefault(k, v)

    for p, (s, _) in accts.items():
        merge_into(shared, s)
        # permissions 二层特判:allow/deny 列表并集(merge_into 一层 dict 补缺失不够)
        for lk in ('allow', 'deny', 'ask'):
            list_union(shared.setdefault('permissions', {}).setdefault(lk, []),
                       (s.get('permissions') or {}).get(lk))

    changed = save_if_changed(SHARED, shared, shared_raw)
    if changed: log(f'✓ harvest → {SHARED}')

    # ---- 2. apply: shared → 各账户(已声明标量不动;list/嵌套 list 直接采用 shared 规范序,
    #      保证两账户字节级一致——harvest 已并集,赋值无损) ----
    def apply_canonical(dst, src):
        for k, v in (src or {}).items():
            if k in ('enabledPlugins', 'env'):
                continue
            if isinstance(v, dict):
                apply_canonical(dst.setdefault(k, {}), v)
            elif isinstance(v, list):
                dst[k] = list(v)
            elif v is not None:
                dst.setdefault(k, v)

    for p, (s, raw) in accts.items():
        apply_canonical(s, shared)
        if save_if_changed(p, s, raw):
            log(f'✓ apply → {p}')

    log('sync-toolchain 完成')

if __name__ == '__main__':
    main()
