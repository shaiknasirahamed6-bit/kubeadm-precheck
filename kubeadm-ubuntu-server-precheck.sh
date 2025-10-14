# Kernel
kernel=$(uname -r)
recommended_kernel=">=3.10"
if [[ "$(echo $kernel | cut -d. -f1)" -ge 3 ]]; then
    results["Kernel"]="PASS (Recommended $recommended_kernel)"
else
    results["Kernel"]="FAIL (Recommended $recommended_kernel)"
fi
echo "Kernel Version: $kernel ... ${results["Kernel"]}"

# CPU
cpu_count=$(nproc)
recommended_cpu=1
if [ "$cpu_count" -ge $recommended_cpu ]; then
    results["CPU"]="PASS (Recommended >=$recommended_cpu)"
else
    results["CPU"]="FAIL (Recommended >=$recommended_cpu)"
fi
echo "CPU Count: $cpu_count ... ${results["CPU"]}"

# Memory
mem_bytes=$(free -b | awk '/Mem:/ {print $2}')
recommended_mem=$((1 * 1024 * 1024 * 1024)) # 1Gi
if [ "$mem_bytes" -ge "$recommended_mem" ]; then
    results["Memory"]="PASS (Recommended >=1Gi)"
else
    results["Memory"]="FAIL (Recommended >=1Gi)"
fi
echo "Memory: $(free -h | awk '/Mem:/ {print $2}') ... ${results["Memory"]}"

# Disk
disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
recommended_disk=80
if [ "$disk_percent" -lt "$recommended_disk" ]; then
    results["Disk"]="PASS (Recommended <$recommended_disk%)"
else
    results["Disk"]="FAIL (Recommended <$recommended_disk%)"
fi
echo "Root Disk Usage: $(df -h / | awk 'NR==2 {print $4}') ... ${results["Disk"]}"

# Port 6443 example
port=6443
netstat -tuln | grep -q ":$port "
if [ $? -eq 0 ]; then
    results["Port_$port"]="OPEN (Required)"
else
    results["Port_$port"]="CLOSED (Required)"
fi

