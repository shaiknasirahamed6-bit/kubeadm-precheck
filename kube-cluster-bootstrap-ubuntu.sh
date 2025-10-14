#!/bin/bash
# =======================================
# Kubernetes Cluster Deployment Script
# Works on Ubuntu 22.04/24.04 LTS
# For single-node or multi-node kubeadm cluster
# =======================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== KUBERNETES DEPLOYMENT SCRIPT ===${NC}"

# 1️⃣ Update system & install prerequisites
echo -e "${YELLOW}Step 1: Installing prerequisites...${NC}"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# 2️⃣ Disable Swap
echo -e "${YELLOW}Step 2: Disabling swap...${NC}"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3️⃣ Install Container Runtime (Docker)
echo -e "${YELLOW}Step 3: Installing Docker...${NC}"
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Optional: Containerd installation (if prefer containerd over Docker)
# sudo apt-get install -y containerd
# sudo systemctl enable containerd
# sudo systemctl start containerd

# 4️⃣ Add Kubernetes apt repository
echo -e "${YELLOW}Step 4: Installing Kubernetes components...${NC}"
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 5️⃣ Initialize Kubernetes cluster (for control plane)
echo -e "${YELLOW}Step 5: Initializing kubeadm cluster...${NC}"
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# 6️⃣ Set up kubectl for the current user
echo -e "${YELLOW}Step 6: Configuring kubectl...${NC}"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 7️⃣ Deploy Calico CNI
echo -e "${YELLOW}Step 7: Deploying Calico CNI...${NC}"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 8️⃣ Show node status
echo -e "${GREEN}Step 8: Cluster setup complete!${NC}"
kubectl get nodes
kubectl get pods -A

echo -e "${GREEN}✅ KUBERNETES CLUSTER IS READY ✅${NC}"

