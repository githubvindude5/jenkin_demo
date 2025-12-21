
#!/bin/bash
# Simple script to show CPU, IP, DNS, and Storage info

echo "==== CPU Info ==="
lscpu | grep -E 'Model name|Architecture|CPU\(s\)'

echo
echo "==== IP Address ===="
hostname -I

echo
echo "==== DNS Lookup (example.com) ===="
nslookup example.com 2>/dev/null || echo "nslookup not available"

echo
echo "==== Storage Info ===="
df -h
