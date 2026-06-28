#!/usr/bin/env bash
#
# cf-img-diag.sh — Cloudflare-fronted image/asset slowness diagnostic
# ------------------------------------------------------------------------------
# For a given URL, measures and summarises:
#   (1) DNS resolution + resolution time
#   (2) TLS handshake time
#   (3) Whether the resource is HIT on the Cloudflare edge  (cf-cache-status + age)
#   (4) Origin first-byte response time (TTFB)
#   (5) Two-PoP comparison (pin edge IPs with --resolve, read the colo from cf-ray)
#
# ----------------------------------------------------------------------------
#  PROJECT IRON RULE (newworld-cf-cache-verify, 2026-05-22 ad-image-encrypt sprint)
#  ----------------------------------------------------------------------------
#  NEVER verify CF cache state with `curl -I` (HEAD). On Cloudflare's default
#  config (and on this project's R2/CF setup) HEAD is NOT served from cache and
#  NOT stored, so it ALWAYS returns `cf-cache-status: DYNAMIC` with no `age:` —
#  even when a GET is HITTING the edge with age=4319s. Verifying cache with HEAD
#  sent us chasing Cache Rule / Origin headers / Cache Reserve for nothing.
#  => This script checks cache state ONLY with a real GET:
#         curl -s -o /dev/null -D -    (body discarded, headers dumped)
#  Every cache read below goes through one_get(); HEAD is never used for cache.
# ------------------------------------------------------------------------------
set -u

# ---------------------------- defaults / CLI ----------------------------------
SAMPLES=3
CONNECT_TIMEOUT=10
MAX_TIME=30
POP_B_IP=""                 # -r : explicit edge IP for "PoP B"
ORIGIN_PROBE=0              # -o : also force a MISS to measure true origin TTFB
INSECURE=0                 # -k
IPFLAG=""                   # -4 / -6
UA="Mozilla/5.0 (cf-img-diag) AppleWebKit/537.36 Chrome/124 Safari/537.36"
EXTRA_HEADERS=()            # -H 'Name: value' (repeatable)
URL=""

usage() {
  cat <<'USAGE'
Usage: cf-img-diag.sh [options] <URL>

  -n N        samples per PoP                         (default 3)
  -r IP       pin a 2nd edge IP as "PoP B" for the comparison
              (default: 2nd A-record; anycast may still land same colo)
  -o          also force a cache MISS (cache-buster) to measure true origin TTFB
  -4 | -6     force IPv4 / IPv6
  -k          allow insecure TLS (self-signed origin)
  -A UA       custom User-Agent                       (default: browser-like)
  -H 'H: v'   extra request header (repeatable) e.g. -H 'Referer: https://17.rip/'
  -t SEC      curl --max-time                          (default 30)
  -h          this help

Notes:
  * Cache state is ALWAYS read with GET, never HEAD (project iron rule).
  * Hotlink-protected image domains may need -H 'Referer: https://<allowed>/'
    (newworld 防盗链 = CF WAF Referer whitelist).
  * Two distinct edge IPs from ONE host usually hit the SAME colo (anycast).
    The cf-ray colo is printed so you can SEE whether PoPs actually differ.
USAGE
}

while getopts ":n:r:o46kA:H:t:h" opt; do
  case "$opt" in
    n) SAMPLES="$OPTARG" ;;
    r) POP_B_IP="$OPTARG" ;;
    o) ORIGIN_PROBE=1 ;;
    4) IPFLAG="-4" ;;
    6) IPFLAG="-6" ;;
    k) INSECURE=1 ;;
    A) UA="$OPTARG" ;;
    H) EXTRA_HEADERS+=("$OPTARG") ;;
    t) MAX_TIME="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo "ERROR: -$OPTARG needs an argument" >&2; exit 2 ;;
    \?) echo "ERROR: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
URL="${1:-}"
[[ -z "$URL" ]] && { echo "ERROR: <URL> required" >&2; usage >&2; exit 2; }
[[ "$SAMPLES" =~ ^[0-9]+$ && "$SAMPLES" -ge 1 ]] || { echo "ERROR: -n must be a positive integer" >&2; exit 2; }

# ------------------------------- helpers --------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# ms with 1 decimal from seconds
ms()    { awk -v s="$1" 'BEGIN{ printf "%.1f", s*1000 }'; }
# non-negative delta (a-b) in ms
dms()   { awk -v a="$1" -v b="$2" 'BEGIN{ d=(a-b)*1000; if(d<0)d=0; printf "%.1f", d }'; }
# min avg max (ms) over space-separated seconds
stats() {
  awk '{ for(i=1;i<=NF;i++){v=$i*1000; if(n==0||v<mn)mn=v; if(n==0||v>mx)mx=v; s+=v; n++} }
        END{ if(n==0) print "NA NA NA"; else printf "%.1f %.1f %.1f", mn, s/n, mx }' <<<"$1"
}

# Pull a header value from a dumped header file (last occurrence, CRLF-stripped, trimmed).
hdr_get() {  # <name> <file>
  local line
  line="$(grep -i "^$1:" "$2" 2>/dev/null | tail -n1)" || true
  [[ -z "$line" ]] && return 0
  line="${line#*:}"; line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"   # ltrim
  printf '%s' "$line"
}

# Parse scheme/host/port out of the URL (handles :port and [v6]).
url_scheme=""; url_host=""; url_port=""
parse_url() {
  local u="$1" rest hostport p
  url_scheme="${u%%://*}"
  rest="${u#*://}"; hostport="${rest%%/*}"; hostport="${hostport##*@}"
  if [[ "$hostport" == \[*\]* ]]; then
    url_host="${hostport%%]*}"; url_host="${url_host#\[}"
    p="${hostport##*]}"; url_port="${p#:}"
  else
    url_host="${hostport%%:*}"
    [[ "$hostport" == *:* ]] && url_port="${hostport##*:}" || url_port=""
  fi
  [[ -z "$url_port" ]] && { [[ "$url_scheme" == https ]] && url_port=443 || url_port=80; }
}
parse_url "$URL"

# ------------------------------------------------------------------------------
# one_get: a SINGLE real GET. Discards body (-o /dev/null), dumps response
# headers (-D), and emits the curl timing waterfall via -w. One round trip
# yields DNS + TLS + TTFB + cache headers together. GET-only => cache-safe.
# Sets globals: g_dns g_conn g_tls g_pre g_ttfb g_total g_code g_ip g_size g_nconn g_rc
# ------------------------------------------------------------------------------
g_dns=0; g_conn=0; g_tls=0; g_pre=0; g_ttfb=0; g_total=0; g_code=0; g_ip=""; g_size=0; g_nconn=0; g_rc=0
one_get() {  # <url> <resolve-or-empty> <hdrfile>
  local url="$1" resolve="$2" hdrfile="$3" out
  local args=(-sS -A "$UA" --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME"
              -o /dev/null -D "$hdrfile")
  [[ -n "$IPFLAG" ]] && args+=("$IPFLAG")
  [[ "$INSECURE" == 1 ]] && args+=(-k)
  if ((${#EXTRA_HEADERS[@]})); then local h; for h in "${EXTRA_HEADERS[@]}"; do args+=(-H "$h"); done; fi
  [[ -n "$resolve" ]] && args+=(--resolve "$resolve")
  args+=(-w '%{time_namelookup} %{time_connect} %{time_appconnect} %{time_pretransfer} %{time_starttransfer} %{time_total} %{http_code} %{remote_ip} %{size_download} %{num_connects}')

  out="$(curl "${args[@]}" "$url" 2>/dev/null)"; g_rc=$?
  read -r g_dns g_conn g_tls g_pre g_ttfb g_total g_code g_ip g_size g_nconn <<<"$out"
  : "${g_dns:=0}" "${g_conn:=0}" "${g_tls:=0}" "${g_pre:=0}" "${g_ttfb:=0}" "${g_total:=0}" "${g_code:=0}" "${g_size:=0}" "${g_nconn:=0}"
}

# Plain-English read of a cf-cache-status value.
explain_cache() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    HIT)         echo "served from edge cache (fast path, origin NOT touched)";;
    MISS)        echo "not in this PoP's cache -> edge fetched from ORIGIN (TTFB includes origin RTT)";;
    EXPIRED)     echo "was cached but stale -> revalidated against ORIGIN";;
    REVALIDATED) echo "stale-while-revalidate served, refreshed from origin";;
    UPDATING)    echo "stale served while another req refreshes (high load)";;
    STALE)       echo "stale served (origin unreachable)";;
    DYNAMIC)     echo "NOT cacheable as configured -> always to ORIGIN (check Cache-Control / Cache Rule / query string / cookies)";;
    BYPASS)      echo "cache explicitly bypassed (Cache Rule / no-cache)";;
    "")          echo "no cf-cache-status header (not a Cloudflare response? wrong host? error page?)";;
    *)           echo "see Cloudflare cache-status docs";;
  esac
}

# ==============================================================================
echo "================================================================================"
echo " Cloudflare image/asset slowness diagnostic"
echo " URL    : $URL"
echo " Host   : $url_host    Port: $url_port    Scheme: $url_scheme"
echo " Samples: $SAMPLES per PoP    $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================================"

# ------------------------------ (1) DNS ---------------------------------------
echo
echo "== (1) DNS resolution =========================================================="
IPS=()
if have dig; then
  # A records + authoritative resolver round-trip time
  qtime="$(dig +tries=1 +time=3 A "$url_host" 2>/dev/null | awk -F': *' '/Query time/{print $2}')"
  while read -r ip; do [[ -n "$ip" ]] && IPS+=("$ip"); done < <(dig +short A "$url_host" 2>/dev/null | grep -E '^[0-9]+\.')
  if ((${#IPS[@]} == 0)); then
    while read -r ip; do [[ -n "$ip" ]] && IPS+=("$ip"); done < <(dig +short AAAA "$url_host" 2>/dev/null | grep -E ':')
  fi
  echo "  A/AAAA records : ${IPS[*]:-<none>}"
  echo "  resolver round-trip (dig Query time) : ${qtime:-NA}"
elif have getent; then
  while read -r ip _; do [[ -n "$ip" ]] && IPS+=("$ip"); done < <(getent ahosts "$url_host")
  echo "  resolved (getent): ${IPS[*]:-<none>}   (install dig for resolver timing)"
else
  echo "  (no dig/getent) — relying on curl in-band namelookup below"
fi
# in-band namelookup (one warm GET) — note: may be ~0 if cached by nscd/systemd-resolved
tmp_hdr="$(mktemp)"; trap 'rm -f "$tmp_hdr" "$tmp_hdr".*' EXIT
one_get "$URL" "" "$tmp_hdr"
echo "  curl in-band namelookup            : $(ms "$g_dns") ms  (may be ~0 if locally cached)"
if [[ "$g_code" == 000 || "$g_rc" != 0 ]]; then
  echo
  echo "  !! curl could not complete (rc=$g_rc, http=$g_code). Host unreachable / blocked /"
  echo "     wrong name. Fix connectivity before reading cache numbers below."
fi

# ----------------------- (2) TLS + (4) TTFB waterfall -------------------------
echo
echo "== (2) TLS handshake + (4) TTFB — connection waterfall (1 warm GET) ============"
printf "  %-22s %8s ms\n" "DNS lookup"            "$(ms  "$g_dns")"
printf "  %-22s %8s ms\n" "TCP connect"           "$(dms "$g_conn" "$g_dns")"
if [[ "$url_scheme" == https ]]; then
  printf "  %-22s %8s ms   <-- (2) TLS handshake\n" "TLS handshake" "$(dms "$g_tls" "$g_conn")"
else
  printf "  %-22s %8s\n" "TLS handshake" "n/a (http)"
fi
printf "  %-22s %8s ms\n" "server wait (req->1B)" "$(dms "$g_ttfb" "$g_pre")"
printf "  %-22s %8s ms   <-- (4) TTFB (time to first byte)\n" "TTFB total" "$(ms "$g_ttfb")"
printf "  %-22s %8s ms\n" "content download"      "$(dms "$g_total" "$g_ttfb")"
printf "  %-22s %8s ms\n" "TOTAL"                 "$(ms "$g_total")"
printf "  %-22s %8s\n"    "edge IP / size / conns" "$g_ip / ${g_size}B / ${g_nconn}"

# ----------------------------- (3) CF cache -----------------------------------
echo
echo "== (3) Cloudflare cache state (GET, never HEAD — iron rule) ===================="
cc="$(hdr_get cf-cache-status "$tmp_hdr")"
age="$(hdr_get age "$tmp_hdr")"
ray="$(hdr_get cf-ray "$tmp_hdr")"
ccontrol="$(hdr_get cache-control "$tmp_hdr")"
srv="$(hdr_get server "$tmp_hdr")"
colo="${ray##*-}"
printf "  %-18s %s\n" "cf-cache-status :" "${cc:-<missing>}"
printf "  %-18s %s\n" "age             :" "${age:-<none>}${age:+ s}"
printf "  %-18s %s\n" "cf-ray / colo   :" "${ray:-<none>}   (PoP: ${colo:-?})"
printf "  %-18s %s\n" "cache-control   :" "${ccontrol:-<none>}"
printf "  %-18s %s\n" "server          :" "${srv:-<none>}"
echo "  -> $(explain_cache "$cc")"
if [[ "$cc" =~ ^[Hh][Ii][Tt]$ && ( -z "$age" || "$age" == 0 ) ]]; then
  echo "  -> HIT but age=0/none: object was JUST (re)populated; the PREVIOUS request paid the origin cost."
fi
[[ -z "$srv" ]] && echo "  -> WARNING: no 'server: cloudflare' — this response may not be coming through CF at all."

# --------------------- (4b) optional true origin TTFB -------------------------
if [[ "$ORIGIN_PROBE" == 1 ]]; then
  echo
  echo "== (4b) True ORIGIN TTFB (cache-buster forces MISS) ============================"
  if [[ "$URL" == *\?* ]]; then ourl="${URL}&cfdiag=$RANDOM$RANDOM"; else ourl="${URL}?cfdiag=$RANDOM$RANDOM"; fi
  ohdr="$(mktemp)"; one_get "$ourl" "" "$ohdr"
  occ="$(hdr_get cf-cache-status "$ohdr")"
  echo "  buster URL : $ourl"
  printf "  %-18s %s\n" "cf-cache-status :" "${occ:-<missing>} ($(explain_cache "$occ"))"
  if [[ "$occ" =~ ^[Hh][Ii][Tt]$ ]]; then
    printf "  %-18s %s ms   (still a HIT — NOT origin)\n" "TTFB :" "$(ms "$g_ttfb")"
    echo "  -> Cache-buster did NOT force a MISS: this zone's cache KEY ignores the query"
    echo "     string (cache by path only). To measure true origin TTFB, purge this exact"
    echo "     URL (see newworld-cf-purge-multi-zone) or hit a genuinely uncached path."
  else
    printf "  %-18s %s ms   <-- origin-path TTFB\n" "origin TTFB :" "$(ms "$g_ttfb")"
    echo "  (Compare with the cached TTFB in section 2: the gap ~= origin fetch cost the"
    echo "   edge pays on every MISS. 'Occasionally slow' images usually = intermittent MISS.)"
  fi
  rm -f "$ohdr"
fi

# --------------------- (5) two-PoP comparison ---------------------------------
echo
echo "== (5) Two-PoP comparison (--resolve pin + cf-ray colo) ========================"
ipA="${IPS[0]:-}"
ipB="$POP_B_IP"
[[ -z "$ipB" && ${#IPS[@]} -ge 2 ]] && ipB="${IPS[1]}"

# run_pop <label> <resolve-or-empty> : samples N times, prints per-sample + summary
run_pop() {
  local label="$1" resolve="$2" i ttfbs="" totals="" colo_seen="" cache_seen="" rep_ip="-"
  echo
  echo "  --- $label ${resolve:+(--resolve $resolve)} ---"
  for ((i=1; i<=SAMPLES; i++)); do
    local ph; ph="$(mktemp)"
    one_get "$URL" "$resolve" "$ph"
    local pcc page pray pcolo
    pcc="$(hdr_get cf-cache-status "$ph")"; page="$(hdr_get age "$ph")"
    pray="$(hdr_get cf-ray "$ph")"; pcolo="${pray##*-}"
    rep_ip="$g_ip"
    ttfbs+="$g_ttfb "; totals+="$g_total "
    [[ -n "$pcolo" && " $colo_seen " != *" $pcolo "* ]] && colo_seen+="$pcolo "
    cache_seen+="${pcc:-NA} "
    printf "   #%d ip=%-15s colo=%-4s http=%s cache=%-8s age=%-5s TLS=%6sms TTFB=%7sms total=%7sms\n" \
      "$i" "${g_ip:-?}" "${pcolo:-?}" "${g_code}" "${pcc:-NA}" "${page:-0}" \
      "$(dms "$g_tls" "$g_conn")" "$(ms "$g_ttfb")" "$(ms "$g_total")"
    rm -f "$ph"
  done
  read -r tmn tav tmx < <(stats "$ttfbs")
  read -r omn oav omx < <(stats "$totals")
  printf "   summary: ip=%s colo(s)=[%s] cache=[%s]\n" "$rep_ip" "${colo_seen%% }" "${cache_seen%% }"
  printf "   summary: TTFB  min/avg/max = %s / %s / %s ms\n" "$tmn" "$tav" "$tmx"
  printf "   summary: TOTAL min/avg/max = %s / %s / %s ms\n" "$omn" "$oav" "$omx"
  # export representative colo for the verdict
  RUN_COLO="${colo_seen%% }"; RUN_TTFB_AVG="$tav"
}

if [[ -z "$ipA" ]]; then
  echo "  (no resolvable edge IP found — running default routing only)"
  run_pop "PoP default (system DNS)" ""
else
  RUN_COLO=""; RUN_TTFB_AVG=""
  run_pop "PoP A" "$url_host:$url_port:$ipA"; coloA="$RUN_COLO"; ttfbA="$RUN_TTFB_AVG"
  if [[ -n "$ipB" && "$ipB" != "$ipA" ]]; then
    run_pop "PoP B" "$url_host:$url_port:$ipB"; coloB="$RUN_COLO"; ttfbB="$RUN_TTFB_AVG"
    echo
    echo "  --- verdict ---"
    if [[ -n "$coloA" && "$coloA" == "$coloB" ]]; then
      echo "  Same colo [$coloA] for both IPs: anycast routed you to ONE PoP — not a true"
      echo "  cross-PoP test. To compare real PoPs, supply an edge IP announced from another"
      echo "  region via -r, or run this from a different network vantage point."
    else
      echo "  Different PoPs: A=[${coloA:-?}] vs B=[${coloB:-?}]  (TTFB avg ${ttfbA} vs ${ttfbB} ms)"
      echo "  If one colo is consistently slower, that PoP's cache is cold or its origin"
      echo "  pull is slow for your region."
    fi
  else
    echo
    echo "  (only one edge IP available — supply a 2nd with -r IP for a real comparison;"
    echo "   note anycast often still lands the same colo from one host.)"
  fi
fi

# ------------------------------- diagnosis ------------------------------------
echo
echo "== Diagnosis hints ============================================================="
case "$(printf '%s' "$cc" | tr '[:lower:]' '[:upper:]')" in
  HIT)
    echo "  * Cache is HIT. If still slow, suspect: large object (see content download &"
    echo "    size above), distant/cold PoP, TLS handshake cost, or client/last-mile."
    ;;
  MISS|EXPIRED|REVALIDATED|UPDATING|STALE)
    echo "  * $cc = edge went to ORIGIN. 'Occasionally slow' is classic intermittent MISS."
    echo "    Re-run with -n 10 to see the HIT/MISS ratio; rising TTFB on MISS = slow origin."
    echo "    Fixes: raise Edge Cache TTL, Cache Reserve, or pre-warm; check origin latency."
    ;;
  DYNAMIC|BYPASS|"")
    echo "  * $cc => this asset is effectively UNCACHED. Every request hits origin."
    echo "    Check: Cache-Control on origin, a Cache Rule matching this path, a query string"
    echo "    or Set-Cookie defeating cache, and that 'server: cloudflare' is present."
    ;;
esac
echo "  * Reminder: cache state above came from GET. NEVER trust 'curl -I' for CF cache —"
echo "    HEAD reports DYNAMIC even on a hot HIT (newworld-cf-cache-verify iron rule)."
echo "================================================================================"
