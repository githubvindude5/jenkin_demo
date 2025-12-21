
#!/bin/bash
# Simple script to show CPU, IP, DNS, and Storage info

echo "==== CPU Info now ==="
lscpu | grep -E 'Model name|Architecture|CPU\(s\)'

echo
echo "==== IP Address ===="
hostname -I

echo "memory"
free -h

echo
echo "==== Storage Info ===="
df -h

echo "Shutting down System"
init 0
