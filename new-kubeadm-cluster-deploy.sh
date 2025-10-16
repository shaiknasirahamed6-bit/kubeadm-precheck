#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Kubernetes Single-Node Deployment Script ===${NC}"

# 1️⃣ Update system & install prerequisites
echo -e "${YELLOW}Step 1: Installing prerequisites...${NC}"
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# 2️⃣ Disable Swap
echo -e "${YELLOW}Step 2: Disabling swap...${NC}"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3️⃣ Install container runtime (containerd)
echo -e "${YELLOW}Step 3: Installing containerd...${NC}"
sudo apt-get install -y containerd
sudo systemctl enable containerd
sudo systemctl start containerd

# 4️⃣ Add Kubernetes apt repository
echo -e "${YELLOW}Step 4: Adding Kubernetes repository...${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y

# 5️⃣ Install kubeadm, kubelet, kubectl
echo -e "${YELLOW}Step 5: Installing kubeadm, kubelet, kubectl...${NC}"
sudo apt-get install -y kubeadm kubelet kubectl kubernetes-cni conntrack cri-tools
sudo apt-mark hold kubeadm kubelet kubectl

# 6️⃣ Enable kubelet
echo -e "${YELLOW}Step 6: Enabling kubelet service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet

# 7️⃣ Initialize Kubernetes cluster
echo -e "${YELLOW}Step 7: Initializing Kubernetes cluster...${NC}"
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU

# 8️⃣ Configure kubectl for root
echo -e "${YELLOW}Step 8: Configuring kubectl...${NC}"
export KUBECONFIG=/etc/kubernetes/admin.conf

# 9️⃣ Deploy Calico CNI
echo -e "${YELLOW}Step 9: Deploying Calico network plugin...${NC}"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 1️⃣0️⃣ Verify cluster status
echo -e "${GREEN}Step 10: Verifying cluster status...${NC}"
kubectl get nodes -o wide
kubectl get pods -A -o wide

echo -e "${GREEN}✅ Kubernetes cluster deployment completed successfully!${NC}"
export KUBECONFIG=/etc/kubernetes/admin.conf
