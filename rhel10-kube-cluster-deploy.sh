#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Kubernetes Single-Node Deployment Script for RHEL 9 / CentOS Stream 9 ===${NC}"

# 1️⃣ Update system & install prerequisites
echo -e "${YELLOW}Step 1: Installing prerequisites...${NC}"
sudo dnf update -y
sudo dnf install -y curl wget vim git bash-completion iproute-tc yum-utils device-mapper-persistent-data lvm2

# 2️⃣ Disable Swap
echo -e "${YELLOW}Step 2: Disabling swap...${NC}"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3️⃣ Enable required kernel modules
echo -e "${YELLOW}Step 3: Enabling kernel modules...${NC}"
sudo modprobe overlay
#sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 4️⃣ Set required sysctl params
echo -e "${YELLOW}Step 4: Setting sysctl params...${NC}"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

# 5️⃣ Install containerd
echo -e "${YELLOW}Step 5: Installing containerd...${NC}"
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl enable --now containerd

# 6️⃣ Add Kubernetes yum repo
echo -e "${YELLOW}Step 6: Adding Kubernetes repository...${NC}"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# 7️⃣ Initialize Kubernetes cluster
echo -e "${YELLOW}Step 7: Initializing Kubernetes cluster...${NC}"
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU

# 8️⃣ Configure kubectl for root
echo -e "${YELLOW}Step 8: Configuring kubectl...${NC}"
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 9️⃣ Deploy Calico CNI
echo -e "${YELLOW}Step 9: Deploying Calico network plugin...${NC}"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 🔟 Verify cluster status
echo -e "${GREEN}Step 10: Verifying cluster status...${NC}"
kubectl get nodes -o wide
kubectl get pods -A -o wide

echo -e "${GREEN}✅ Kubernetes cluster deployment completed successfully on RHEL 9 / CentOS Stream 9!${NC}"

