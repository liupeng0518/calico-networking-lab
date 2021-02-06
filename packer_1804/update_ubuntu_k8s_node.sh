#!/usr/bin/env bash

echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
# resolv
rm -rf /etc/resolv.conf
echo "nameserver 114.114.114.114" > /etc/resolv.conf

sed -i 's/us.archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
   "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Latest updates
apt-get update 
apt-get upgrade -y
apt-get install jq wget curl ipset ipvsadm dialog apt-utils -y

# install Docker
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y

apt-get install docker-ce docker-ce-cli containerd.io -y
apt-mark hold docker-ce docker-ce-cli containerd.io

# "registry-mirrors": ["https://uibirsz0.mirror.aliyuncs.com"],
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker


# Kubeadm
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# install kubernetes
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Pull kubeadm images
# registry.aliyuncs.com/k8sxio
docker pull registry.aliyuncs.com/k8sxio/kube-apiserver:v1.20.2
docker tag registry.aliyuncs.com/k8sxio/kube-apiserver:v1.20.2 k8s.gcr.io/kube-apiserver:v1.20.2

docker pull registry.aliyuncs.com/k8sxio/kube-controller-manager:v1.20.2
docker tag registry.aliyuncs.com/k8sxio/kube-controller-manager:v1.20.2 k8s.gcr.io/kube-controller-manager:v1.20.2

docker pull registry.aliyuncs.com/k8sxio/kube-scheduler:v1.20.2
docker tag registry.aliyuncs.com/k8sxio/kube-scheduler:v1.20.2 k8s.gcr.io/kube-scheduler:v1.20.2

docker pull registry.aliyuncs.com/k8sxio/kube-proxy:v1.20.2
docker tag registry.aliyuncs.com/k8sxio/kube-proxy:v1.20.2 k8s.gcr.io/kube-proxy:v1.20.2

docker pull registry.aliyuncs.com/k8sxio/pause:3.2
docker tag registry.aliyuncs.com/k8sxio/pause:3.2 k8s.gcr.io/pause:3.2

docker pull registry.aliyuncs.com/k8sxio/etcd:3.4.13-0
docker tag registry.aliyuncs.com/k8sxio/etcd:3.4.13-0 k8s.gcr.io/etcd:3.4.13-0

docker pull registry.aliyuncs.com/k8sxio/coredns:1.7.0
docker tag registry.aliyuncs.com/k8sxio/coredns:1.7.0 k8s.gcr.io/coredns:1.7.0


# Pull Calico images and yaml's
curl https://docs.projectcalico.org/manifests/calico.yaml -O

docker pull registry.aliyuncs.com/kubeadm-ha/calico_cni:v3.17.2
docker pull registry.aliyuncs.com/kubeadm-ha/calico_pod2daemon-flexvol:v3.17.2
docker pull registry.aliyuncs.com/kubeadm-ha/calico_node:v3.17.2
docker pull registry.aliyuncs.com/kubeadm-ha/calico_kube-controllers:v3.17.2

# Download calicoctl and keep under /usr/local/bin
# wget  https://github.com/projectcalico/calicoctl/releases/download/v3.17.2/calicoctl
# chmod +x calicoctl
# mv calicoctl /usr/local/bin
# docker run --rm -v /usr/local/bin:/systembindir --entrypoint cp registry.cn-hangzhou.aliyuncs.com/kubeadm-ha/calico_ctl:v3.17.2 -f /calicoctl /systembindir/calicoctl
docker run -itd --name ctl registry.cn-hangzhou.aliyuncs.com/kubeadm-ha/calico_ctl:v3.17.2 --entrypoint sleep 3600
docker cp ctl:/calicoctl /usr/local/bin/calicoctl
docker rm -f ctl

cat << EOF >> calicoctl.cfg
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/home/vagrant/.kube/config"
EOF

sudo mkdir -p /etc/calico
mv calicoctl.cfg /etc/calico

# Clean up
sudo apt-get clean -y
sudo apt-get autoremove --purge -y

