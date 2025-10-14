#!/bin/bash

# =====================================
# Kubernetes Server Precheck Script
# Checks OS, CPU, Memory, Swap, Network,
# Docker/Containerd, Git, and Ports.
# Displays a summary table at the end.
# =====================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

declare -A results

echo -e "${YELLOW}=== KUBERNETES SERVER PRECHECK SCRIPT ===${NC}\n"

# 1️⃣ Server Info
echo -e "${YELLOW}1️⃣  Checking Server Info...${NC}"

# OS
os_name=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
[ -n "$os_name" ] && results["OS"]="PASS" || results["OS"]="FAIL"
echo "OS: $os_name ... ${results["OS"]}"

# Kernel
kernel=$(uname -r)
[[ "$(echo $kernel | cut -d. -f1)" -ge 3 ]] && results["Kernel"]="PASS" || results["Kernel"]="FAIL (Recommended >=3.10)"
echo "Kernel Version: $kernel ... ${results["Kernel"]}"

# CPU
cpu_count=$(nproc)
[ "$cpu_count" -ge 1 ] && results["CPU"]="PASS" || results["CPU"]="FAIL (Recommended >=1)"
echo "CPU Count: $cpu_count ... ${results["CPU"]}"

# Memory
mem_bytes=$(free -b | awk '/Mem:/ {print $2}')
[ "$mem_bytes" -ge 1073741824 ] && results["Memory"]="PASS" || results["Memory"]="FAIL (Recommended >=1Gi)"
echo "Memory: $(free -h | awk '/Mem:/ {print $2}') ... ${results["Memory"]}"

# Disk
disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
[ "$disk_percent" -lt 80 ] && results["Disk"]="PASS" || results["Disk"]="FAIL (Recommended <80%)"
echo "Root Disk Usage: $(df -h / | awk 'NR==2 {print $4}') ... ${results["Disk"]}"

# 2️⃣ Network
echo -e "\n${YELLOW}2️⃣  Checking Network...${NC}"

ping -c 2 google.com &> /dev/null
[ $? -eq 0 ] && results["Internet"]="PASS" || results["Internet"]="FAIL"
echo "Internet Connectivity ... ${results["Internet"]}"

# Required Ports
ports=(6443 10250 2379 2380 10251 10252)
for port in "${ports[@]}"; do
    netstat -tuln | grep -q ":$port "
    if [ $? -eq 0 ]; then
        results["Port_$port"]="OPEN"
    else
        results["Port_$port"]="CLOSED (Required)"
    fi
done

# Hostname & DNS
hostname=$(hostname)
ip_addr=$(hostname -I | awk '{print $1}')
results["DNS"]="FAIL"
nslookup github.com &> /dev/null
[ $? -eq 0 ] && results["DNS"]="PASS"

# 3️⃣ Swap
swap_status=$(swapon --show)
[ -z "$swap_status" ] && results["Swap"]="DISABLED" || results["Swap"]="ENABLED (Run swapoff -a)"

# 4️⃣ Docker / Container Runtime
docker --version &> /dev/null
[ $? -eq 0 ] && results["Docker"]="INSTALLED" || results["Docker"]="NOT INSTALLED"

containerd --version &> /dev/null
[ $? -eq 0 ] && results["Containerd"]="INSTALLED" || results["Containerd"]="NOT INSTALLED"

# 5️⃣ Git Connectivity
git --version &> /dev/null
[ $? -eq 0 ] && results["Git"]="INSTALLED" || results["Git"]="NOT INSTALLED"

ssh -T git@github.com &> /dev/null
[ $? -eq 1 ] && results["GitHub_SSH"]="SUCCESS" || results["GitHub_SSH"]="FAILED"

# =========================
# SUMMARY TABLE
# =========================
echo -e "\n${YELLOW}=== SUMMARY TABLE ===${NC}"
printf "%-25s | %-10s\n" "CHECK" "STATUS"
printf "%-25s-+-%-10s\n" "------------------------" "----------"

for key in "${!results[@]}"; do
    printf "%-25s | %-10s\n" "$key" "${results[$key]}"
done

echo -e "\n${YELLOW}=== PRECHECK COMPLETE ===${NC}"

