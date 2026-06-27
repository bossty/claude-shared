---
name: fe-perf-phase1-2026-05-29
description: fe-perf solo recon + peak window re-baseline (HKT 20-03). 87-92% traffic to non-Asia POPs incl. 0% CN→HKG. Peak vs off-peak nearly identical (universally slow). 7d trend stable.
metadata: 
  node_type: memory
  type: project
  originSessionId: 26157e24-1a76-48ce-a57b-521c36980c46
---

# fe-perf Phase 1 — 2026-05-29 Peak Hour Recon (HKT 20-03 window)

## Peak window re-baseline (Owner pinned HKT 20-03 = UTC 12-19)

7-day daily peak LCP P75 (stable, not deteriorating):
- 5/27: 4235ms  (vol 34,550/h)
- 5/26: 3896ms  (vol 34,397/h)
- 5/25: 4198ms  (vol 32,430/h)
- 5/24: 4128ms  (vol 30,044/h)
- 5/23: 4668ms  (vol 36,650/h)
- 5/22: 4793ms  (vol 35,971/h)
- 5/21: 4949ms  (vol 16,063/h ← post-anti-adblock low day)

Peak vs off-peak deltas (5/27 yesterday):
- LCP P95 peak=9192ms, off=8739ms (Δ +453ms = +5%)
- TTFB P95 peak=2382ms, off=2371ms (Δ +11ms)
- FCP P95 peak=4034ms, off=4158ms (Δ -125ms)
- INP P95 peak=600ms, off=643ms (Δ -43ms)
- CLS P95 peak=0.677, off=0.661 (Δ +0.016)

**Performance is uniformly poor across the day, peak adds almost nothing.**

## Smoking gun: country × POP routing (peak HKT 20-03, 5/27)

| country | volume/h | top POPs | reality |
|---|---|---|---|
| **CN** | 32,584/h | SEA 32.7% + LAX 29.7% + AMS 28.0% + SJC 4.4% + LHR 2.8% | **0% to HKG** |
| MO | 313/h | SEA 97.2% | Macau to Seattle! |
| MY | 244/h | SIN 87% | OK |
| TW | 236/h | TPE 52% + SIN 45% | OK |
| HK | 235/h | HKG 98.5% | OK |
| US | 171/h | LAX 54% + OTHER 16% | OK |
| JP | 146/h | NRT 87% | OK |

## POP performance comparison (peak HKT 20-03 5/27)

| metric | HKG (Asia baseline) | LAX (CN reality) | Delta |
|---|---|---|---|
| LCP P50 | 1481ms | 2190ms | +709ms |
| LCP P75 | 2626ms | 4488ms | **+1862ms (+71%)** |
| LCP P90 | 4795ms | 7451ms | +2656ms |
| LCP P95 | 6582ms | 10082ms | +3500ms |
| TTFB P75 | 750ms | 1484ms | +734ms (~2x) |
| FCP P75 | 1579ms | 2351ms | +772ms (+49%) |

**If CN routed to HKG instead of US POPs, expected LCP P75 improvement: 4400→2600ms (-1.8s = -41%).**

## Top finding #1: CF anycast routes 0% CN traffic to HKG

CN (~95% of traffic) anycast-routed to SEA/LAX/AMS/SJC/LHR — never HKG. This is **the** root cause. Not load related (peak vs off-peak nearly identical), not deployment related (7d trend stable). Pure CDN topology.

## Top finding #2: Web Vitals globally "poor" across all POPs

Even healthy HKG users see P95 6.6s LCP — only ~1k samples/h so signal noisy, but P75 2.6s is borderline. Universal slowness means underlying app may also be heavy (JS bundle, dynamic imports).

## Top finding #3: R2 cdn-failover wrong-POP routing

r2Pop P95 SJC=35.5s, ICN=34.9s — R2 custom domains via cdn-failover are routed to wrong POPs more often than main domain.

## Verified non-issues

- 7-day LCP trend stable (no deployment regression)
- dist deploy fresh (5/28 21:35, past 24h heal window)
- sw.js BUILD_HASH=5bde4d6f, CACHE_NAME=sw-5bde4d6f, PRECACHE minimal (only /, index.html, manifest, /s.dat — no JS chunks)
- RUM ingestion working (backend MonitorService:194-198 tags cfPop/r2Pop)
- newworld_dns_switch_total = 0 (no automatic DNS removal events)
- itdog_probe_total active (synthetic probes running)

## Hypotheses → ranking

1. **CN anycast NOT routing to HKG** (HIGHEST). Action items for edge-perf:
   - Verify CF China Network / Premium tier
   - Argo Smart Routing per-zone enabled?
   - China network IP prefixes? Edge POP delegation?
   - Could be CF business reality: Free tier de-prioritizes CN regions
2. **R2 zones independent anycast** — each R2 custom domain zone routes differently. cdn-failover HRW selection may consistently pick a domain whose zone routes worse for given user's BGP.
3. **No JS chunk precache** — first cold load = main+lazy+vue+vendor from CDN. SW precache only / + index.html + manifest.
4. **TTFB tail = transcontinental tunnel** — user→SEA POP→cloudflared→HK (~150ms) instead of HKG POP→tunnel (~5ms).
5. **No POP-specific load issue** — peak vs off-peak almost identical, so backend/origin not crashing under load. Confirms app-perf likely "innocent."

## Recommended actions (for team-lead synthesis)

- **PRIORITY 1**: Edge-perf investigates why CN traffic 0% to HKG. May need:
  - Cloudflare China Network paid tier
  - Cloudflare Premium plan
  - Argo Smart Routing
- **PRIORITY 2**: R2 cdn-failover weight by user's likely cfPop, not just HRW
- **PRIORITY 3**: SW precache top 5 JS chunks (main entry + Home + Player + Vue+Vendor)
- **PRIORITY 4**: Cache Reserve for /assets/*.js on main zone

## Data sources / commands

- ssh aws-monitor → http://127.0.0.1:8428 (VictoriaMetrics)
- Metrics: nw_vitals_lcp_ms_by_pop_bucket, nw_vitals_ttfb_ms_by_pop_bucket, nw_vitals_lcp_ms_by_r2pop_bucket
- Labels: `cfPop`, `cfCountry`, `r2Pop` (camelCase!)
- Peak window: UTC 12-19 (HKT 20-03)
- frontend-web/src/utils/monitor.js:357-422 (cfRay probe)
- newworld-web/.../MonitorService.java:194-198 (tag emission)
