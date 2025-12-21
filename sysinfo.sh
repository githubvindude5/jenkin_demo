
#!/usr/bin/env bash
# =========================================
# System Info (No arguments required)
# Collects CPU info, DNS (nslookup), IP addresses, and storage usage.
# =========================================

set -euo pipefail

# Helper: check if command exists
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ---------- CPU Info ----------
cpu_info() {
  echo "==== CPU Information ===="
  if command_exists lscpu; then
    lscpu
  else
    echo "Model: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
    echo "Architecture: $(uname -m)"
    echo "Logical CPUs: $(grep -c '^processor' /proc/cpuinfo)"
  fi
  echo
  echo "Load Average (1m, 5m, 15m):"
  awk '{print "  " $1, $2, $3}' /proc/loadavg
  echo
}

# ---------- IP / Network Info ----------
ip_info() {
  echo "==== IP Address & Network Information ===="
  if command_exists ip; then
    echo "-- Interfaces & Addresses --"
    ip -brief address show

    echo
    echo "-- Default Route --"
    ip route show default || true
  elif command_exists ifconfig; then
    echo "-- Interfaces & Addresses (ifconfig) --"
    ifconfig -a
  else
    echo "Neither 'ip' nor 'ifconfig' found. Please install 'iproute2' or 'net-tools'."
  fi

  echo
  echo "-- DNS Resolvers (from resolv.conf) --"
  awk '/^nameserver/ {print "  " $2}' /etc/resolv.conf || true
  echo
}

# ---------- DNS Lookup ----------
dns_lookup() {
  echo "==== DNS Lookup ===="
  # Try nslookup on local hostname (FQDN if available)
  FQDN="$(hostname -f 2>/dev/null || hostname)"
  echo "-- nslookup for hostname: $FQDN --"
  if command_exists nslookup; then
    nslookup "$FQDN" || echo "nslookup failed for $FQDN"
  elif command_exists dig; then
    echo "nslookup not found, using dig:"
    dig +short "$FQDN" A; dig +short "$FQDN" AAAA
  else
    echo "Neither 'nslookup' nor 'dig' available. Install 'dnsutils' (Debian/Ubuntu) or 'bind-utils' (RHEL/CentOS)."
  fi

  echo
  # Optional: also check a known domain for baseline (example.com)
  DEFAULT_DOMAIN="example.com"
  echo "-- nslookup for default domain: $DEFAULT_DOMAIN --"
  if command_exists nslookup; then
    nslookup "$DEFAULT_DOMAIN" || echo "nslookup failed for $DEFAULT_DOMAIN"
  elif command_exists dig; then
    dig +short "$DEFAULT_DOMAIN" A; dig +short "$DEFAULT_DOMAIN" AAAA
  fi
  echo
}

# ---------- Storage / Disk ----------
storage_info() {
  echo "==== Storage / Disk Usage ===="
  echo "-- Filesystem Usage (df -hT) --"
  if command_exists df; then
    df -hT | awk 'NR==1 || $2!="tmpfs" {print}'
  else
    echo "'df' not found."
  fi

  echo
  if command_exists lsblk; then
    echo "-- Block Devices (lsblk) --"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  fi

  echo
  if command_exists du; then
    echo "-- Top 10 Largest Directories under / (quick scan) --"
    # Skip virtual filesystems; limit depth to keep it fast
    # Uses sudo if available and non-interactive; otherwise runs without
    sudo -n true >/dev/null 2>&1 && SUDO="sudo" || SUDO=""
    $SUDO du -xh --max-depth=2 / \
      --exclude=/proc --exclude=/sys --exclude=/run --exclude=/dev 2>/dev/null \
      | sort -h -r | head -n 10
  fi
  echo
}

# ---------- Main ----------
main() {
  cpu_info
  ip_info
  dns_lookup
  storage_info
}

main
