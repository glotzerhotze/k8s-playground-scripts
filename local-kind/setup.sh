#!/bin/sh
# This script was tested on Ubuntu 20.04.5

set -e

########################################################################################################################
## TODO: Adjust Variables to your environment - updated to latest versions on 30.09.2024 by tkl
########################################################################################################################
export HELM_VERSION="3.16.1"
export K9S_VERSION="0.32.5"
export KIND_VERSION="0.24.0" ## check kubernetes version - 0.24.0 --> 1.31.0 / 0.23.0 --> 1.30.0 / 0.22.0 --> 1.29.2
export CILIUM_VERSION="1.16.2"
export K8S_VERSION="1.31.0" ## make sure K8S_VERSION is in sync with the k8s version being used by kind

DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

echo "get current IP address to use for controlplane access"
###
export CURRENT_INTERFACE=$(ip -br l | awk '$1 !~ "lo|vir|wl|br|docker|veth|tailscale|enp0s3" { print $1}')
export CURRENT_IP=$(ip a | grep ${CURRENT_INTERFACE} | grep inet | tr -s " " | cut -d' ' -f3 | cut -d'/' -f1)

echo "Install some packages that are needed"
###
DEBIAN_FRONTEND=noninteractive apt-get -y install net-tools ca-certificates curl gnupg lsb-release jq

echo "Setup ulimits so subsequent container-processes won't have problem (aka. ES dbs)"
###
grep -qF "fs.inotify.max_user_watches = 524288" /etc/sysctl.d/99-sysctl.conf || echo "fs.inotify.max_user_watches = 524288" >> /etc/sysctl.d/99-sysctl.conf
grep -qF "fs.inotify.max_user_instances = 512" /etc/sysctl.d/99-sysctl.conf || echo "fs.inotify.max_user_instances = 512" >> /etc/sysctl.d/99-sysctl.conf
grep -qF "fs.file-max = 65535" /etc/sysctl.d/99-sysctl.conf || echo "fs.file-max = 65535" >> /etc/sysctl.d/99-sysctl.conf
grep -qF "nproc" /etc/security/limits.conf | grep -qxF "65535" || cat << EOF >> /etc/security/limits.conf
* soft     nproc          65535
* hard     nproc          65535
* soft     nofile         65535
* hard     nofile         65535
root soft     nproc          65535
root hard     nproc          65535
root soft     nofile         65535
root hard     nofile         65535
EOF
grep -qF "session required pam_limits.so" /etc/pam.d/common-session || echo "session required pam_limits.so" >> /etc/pam.d/common-session
grep -qF "session required pam_limits.so" /etc/pam.d/common-session-noninteractive || echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
sysctl -p

## echo "Creating /etc/resolve.conf.k8s for the cluster"
## ###
## cp ./resolv.conf /etc/resolv.conf.k8s

## echo "Disable local resolver with systemd-resolved DNS configuration"
## ###
## systemctl mask systemd-resolved
## mv /etc/resolv.conf /etc/resolv.conf.kind-backup
## ln -s /etc/resolv.conf.k8s /etc/resolv.conf

echo "Creating docker setup files"
###
mkdir -p /etc/docker
cat docker/daemon.json | tee /etc/docker/daemon.json

echo "installing and configuring FRR for BGP routing"
###
DEBIAN_FRONTEND=noninteractive apt-get -y install frr
cp frr.conf /etc/frr/frr.conf
cp daemons /etc/frr/daemons
systemctl restart frr

echo "Installing and configuring docker"
###
mkdir -p /etc/apt/keyrings
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
DEBIAN_FRONTEND=noninteractive apt-get -y clean

echo "Installing kubectl"
###
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/bin

echo "Installing k9s for convinience and cluster browsability"
###
curl -LO https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz
tar xvf k9s_Linux_amd64.tar.gz -C /usr/bin

echo "Installing helm and configuring repositories for templating initial workloads"
curl -LO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
tar xvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
mv ./linux-amd64/helm /usr/bin/helm
helm repo add cilium https://helm.cilium.io/
helm repo update

echo "Templating cilium-1.14.4-direct-routing for CNI requirements"
###
bash cilium-template.sh
kubectl apply -f cilium-direct-routing.yaml

echo "deploy echoserver workload to test the cluster with a quick and dirty smoke test"
###
kubectl apply -f echoserver.wl.yaml

echo "local DNS override for demonstration purposes (as ingress routes on DNS, not IP)"
###
echo "172.18.0.155 echoserver.kind.example.com" >> /etc/hosts

echo "install cilium CLI"
###
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

echo "install hubble CLI"
###
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin

echo "installing KIND with latest version"
###
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/bin

echo "creating KIND cluster local and applying CNI configuration"
###
kind create cluster --config /root/kind-cluster.yaml
mkdir -p /root/.kube
kind export kubeconfig --kubeconfig /root/.kube/config --name local
kubectl apply -f /root/cilium-1.14.4-direct-routing.yaml
while ! kubectl apply -f /root/bgp-peering-policy.yaml -f /root/bgp-ippool.yaml -f /root/echoserver.yaml; do echo "Retrying to apply resources"; sleep 10; done

echo "installing kubectl krew plugin manager"
###
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
KREW="krew-${OS}_${ARCH}"
curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
tar zxvf "${KREW}.tar.gz"
./"${KREW}" install krew
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> /root/.bashrc

echo "installing github CLI tool"
###
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y install gh
DEBIAN_FRONTEND=noninteractive apt-get -y clean

echo "installing flux latest version to manage the local cluster in a next step"
###
curl -s https://fluxcd.io/install.sh | bash

echo "testing the cluster via echoserver curl"
echo "but first let's wait for the echoserver-deployment to be available"
echo "curl -L http://echoserver.kind.example.com | jq"
kubectl wait --for=condition=ready pod -l app=echoserver -n echoserver
curl -L http://echoserver.kind.example.com | jq