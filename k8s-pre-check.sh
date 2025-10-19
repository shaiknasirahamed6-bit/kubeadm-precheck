#!/bin/bash
# Kubernetes Cluster Precheck Script (Universal for RHEL/CentOS & Ubuntu)
# Author: Shaik Nasir Ahamed
# Version: 2.1

# 🎨 Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Kubernetes Cluster Precheck Script ===${NC}"

# Detect OS
if [ -f /etc/redhat-release ]; then
    OS="RHEL"
elif [ -f /etc/lsb-release ]; then
    OS="UBUNTU"
else
    OS="UNKNOWN"
fi
echo -e "Detected OS: ${GREEN}${OS}${NC}"
echo

# Declare associative array to store check results
declare -A results

# Function to set results
check() {
    local name="$1"
    local code="$2"
    if [ $code -eq 0 ]; then
        results[$name]="PASS"
        echo -e "$name: ${GREEN}✅ PASS${NC}"
    elif [ $code -eq 2 ]; then
        results[$name]="WARNING"
        echo -e "$name: ${YELLOW}⚠️ WARNING${NC}"
    else
        results[$name]="FAIL"
        echo -e "$name: ${RED}❌ FAIL${NC}"
    fi
}

# CPU check
CPU_CORES=$(nproc)
[ "$CPU_CORES" -ge 2 ]
check "CPU (>=2 cores)" $?

# RAM check
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
[ "$RAM_GB" -ge 2 ]
check "RAM (>=2GB)" $?

# Disk space check
ROOT_GB=$(df -BG / | awk 'NR==2{gsub("G",""); print $4}')
[ "$ROOT_GB" -ge 10 ]
check "Disk Space (>=10GB)" $?

# Network connectivity
ping -c 1 8.8.8.8 &>/dev/null
check "Internet connectivity" $?

# Swap check
if swapon --show | grep -q 'partition'; then
    check "Swap disabled" 1
else
    check "Swap disabled" 0
fi

# fstab swap check
if [ -f /etc/fstab ]; then
    grep -E "swap" /etc/fstab >/dev/null
    if [ $? -eq 0 ]; then
        check "/etc/fstab swap entries" 2
    else
        check "/etc/fstab swap entries" 0
    fi
else
    check "/etc/fstab presence" 2
fi

# Ports check (basic)
for port in 6443 10250 2379 2380 10259 10257; do
  nc -z localhost $port &>/dev/null
  if [ $? -eq 0 ]; then
      results["Port $port"]="WARNING"
      echo -e "Port $port: ${YELLOW}⚠️ In Use${NC}"
  else
      results["Port $port"]="PASS"
      echo -e "Port $port: ${GREEN}✅ Free${NC}"
  fi
done

# Repository check
if [ "$OS" == "RHEL" ]; then
    dnf repolist &>/dev/null
    check "YUM/DNF repo" $?
elif [ "$OS" == "UBUNTU" ]; then
    apt update -y &>/dev/null
    check "APT repo" $?
else
    check "Repo check (unknown OS)" 2
fi

# SELinux status & fix (RHEL)
if [ "$OS" == "RHEL" ]; then
    SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Disabled")
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        echo -e "${YELLOW}Setting SELinux to permissive...${NC}"
        sudo setenforce 0
        if [ -f /etc/selinux/config ]; then
            sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
            sudo sed -i 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
        fi
        sleep 1
        SELINUX_STATUS=$(getenforce)
    fi

    if [[ "$SELINUX_STATUS" == "Disabled" || "$SELINUX_STATUS" == "Permissive" ]]; then
        check "SELinux" 0
    else
        check "SELinux" 1
    fi
fi

# Containerd check & start if inactive
if systemctl is-active --quiet containerd; then
    check "Containerd running" 0
else
    echo -e "${YELLOW}Starting containerd service...${NC}"
    sudo systemctl enable --now containerd
    sleep 2
    if systemctl is-active --quiet containerd; then
        check "Containerd running" 0
    else
        check "Containerd running" 2
    fi
fi

# 🏁 Summary Table
echo -e "\n${YELLOW}=== Kubernetes Precheck Summary ===${NC}"
printf "%-25s %-10s\n" "Check" "Status"
printf "%-25s %-10s\n" "-----" "------"
for key in "${!results[@]}"; do
    status="${results[$key]}"
    case $status in
        PASS)
            printf "%-25s ${GREEN}%-10s${NC}\n" "$key" "$status"
            ;;
        FAIL)
            printf "%-25s ${RED}%-10s${NC}\n" "$key" "$status"
            ;;
        WARNING)
            printf "%-25s ${YELLOW}%-10s${NC}\n" "$key" "$status"
            ;;
    esac
done

echo -e "\n${GREEN}✅ If all critical checks PASS, the system is ready for kubeadm.${NC}"
echo -e "${YELLOW}⚠️ Warnings should be reviewed before deployment.${NC}"
echo -e "${RED}❌ FAIL must be resolved before running kubeadm.${NC}"

