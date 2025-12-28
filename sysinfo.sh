
#!/usr/bin/env bash
# Internet Health Check - Simple Bash Script (no arguments)
# Checks: gateway reachability, DNS resolution, ping to public IPs, HTTP(S) GET latency.
# Works on most Linux systems.

set -euo pipefail

# ---- Config (you can tweak these) ----
PING_TARGETS=("1.1.1.1" "8.8.4.4")
HTTP_TARGETS=("https://www.cloudflare.com" "https://www.google.com" "https://example.com")
TEST_DOMAIN="www.abc.com"
PING_COUNT=4
PING_TIMEOUT=3
CURL_TIMEOUT=5
LATENCY_WARN_MS=800   # Warn if HTTP TTFB > 800ms
LATENCY_FAIL_MS=2000  # Fail if HTTP TTFB > 2000ms

# ---- Colors ----
RED="$(tput setaf 1 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
BLUE="$(tput setaf 4 2>/dev/null || true)"
BOLD="$(tput bold 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

# ---- Helpers ----
command_exists() { command -v "$1" >/dev/null 2>&1; }

status_line() {
  local status="$1"; shift
  case "$status" in
    OK)    echo -e "${GREEN}[OK]${RESET} $*";;
    WARN)  echo -e "${YELLOW}[WARN]${RESET} $*";;
    FAIL)  echo -e "${RED}[FAIL]${RESET} $*";;
    INFO)  echo -e "${BLUE}[INFO]${RESET} $*";;
    *)     echo "[*] $*";;
  esac
}

to_ms() { # seconds (float) -> milliseconds (int)
  python3 - <<'PY' "$1" 2>/dev/null || awk "BEGIN {print int($1*1000)}"
import sys
print(int(float(sys.argv[1]) * 1000))
PY
}

# ---- Checks ----

check_gateway() {
  echo -e "\n${BOLD}== Default Gateway Reachability ==${RESET}"
  if ! command_exists ip; then
    status_line WARN "Command 'ip' not found; skipping gateway check."
    return 0
  fi
  local gw
  gw="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"
  if [[ -z "${gw:-}" ]]; then
    status_line FAIL "No default route found."
    return 1
  fi
  status_line INFO "Default gateway: $gw"
  if ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$gw" >/dev/null 2>&1; then
    status_line OK "Gateway reachable."
  else
    status_line FAIL "Cannot reach gateway $gw."
    return 1
  fi
}

check_dns() {
  echo -e "\n${BOLD}== DNS Resolution ==${RESET}"
  local resolvers
  resolvers=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | xargs)
  [[ -n "$resolvers" ]] && status_line INFO "Resolvers: $resolvers" || status_line WARN "No nameservers in /etc/resolv.conf."

  if command_exists nslookup; then
    if nslookup "$TEST_DOMAIN" >/dev/null 2>&1; then
      status_line OK "Resolved $TEST_DOMAIN via nslookup."
    else
      status_line FAIL "DNS resolution failed for $TEST_DOMAIN (nslookup)."
      return 1
    fi
  elif command_exists dig; then
    if dig +short "$TEST_DOMAIN" A >/dev/null 2>&1; then
      status_line OK "Resolved $TEST_DOMAIN via dig."
    else
      status_line FAIL "DNS resolution failed for $TEST_DOMAIN (dig)."
      return 1
    fi
  else
    status_line WARN "Neither nslookup nor dig available. Skipping DNS test."
  fi
}

check_ping_public() {
  echo -e "\n${BOLD}== Public Ping Connectivity ==${RESET}"
  local any_ok=0
  for t in "${PING_TARGETS[@]}"; do
    if ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$t" >/dev/null 2>&1; then
      status_line OK "Ping to $t succeeded."
      any_ok=1
    else
      status_line FAIL "Ping to $t failed."
    fi
  done
  [[ $any_ok -eq 1 ]] || return 1
}

check_http_latency() {
  echo -e "\n${BOLD}== HTTP(S) Reachability & Latency (TTFB) ==${RESET}"
  if ! command_exists curl; then
    status_line WARN "curl not installed; skipping HTTP checks."
    return 0
  fi
  local all_ok=0
  for url in "${HTTP_TARGETS[@]}"; do
    # Measure time to first byte
    local ttfb
    ttfb=$(curl -sS -o /dev/null --max-time "$CURL_TIMEOUT" -w "%{time_starttransfer}" "$url" 2>/dev/null || echo "")
    if [[ -z "$ttfb" ]]; then
      status_line FAIL "HTTP request failed: $url"
      continue
    fi
    local ms
    ms=$(to_ms "$ttfb")
    if (( ms >= LATENCY_FAIL_MS )); then
      status_line FAIL "High latency (TTFB=${ms} ms) $url"
    elif (( ms >= LATENCY_WARN_MS )); then
      status_line WARN "Elevated latency (TTFB=${ms} ms) $url"
      all_ok=1
    else
      status_line OK "TTFB=${ms} ms $url"
      all_ok=1
    fi
  done
  [[ $all_ok -eq 1 ]] || return 1
}

summary() {
  echo -e "\n${BOLD}== Summary ==${RESET}"
  local failures=0

  check_gateway || failures=$((failures+1))
  check_dns || failures=$((failures+1))
  check_ping_public || failures=$((failures+1))
  check_http_latency || failures=$((failures+1))

  echo
  if (( failures == 0 )); then
    status_line OK "Internet looks healthy."
    exit 0
  else
    status_line FAIL "Internet health issues detected ($failures checks failed)."
    exit 1
  fi
}

# ---- Run ----
echo -e "${BOLD}Internet Health Check${RESET}"
echo "Host: $(hostname) | Time: $(date '+%Y-%m-%d %H:%M:%S')"
summary
