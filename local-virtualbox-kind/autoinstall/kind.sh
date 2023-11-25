#!/bin/sh
# This script was tested on Ubuntu 20.04.5

set -e

DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

echo "set current IP address to use for controlplane access when installing cilium"
CURRENT_IP="192.168.56.10"

echo "Install some packages that are needed"
###
DEBIAN_FRONTEND=noninteractive apt-get -y install net-tools ca-certificates curl gnupg lsb-release jq

echo "Setup ulimits"
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

echo "Creating /files and content"
###
mkdir -p /files
cat << EOF >/files/resolv.conf.k8s
nameserver 8.8.8.8
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
EOF
cp /files/resolv.conf.k8s /etc/resolv.conf.k8s

echo "Creating DNS configuration"
###
systemctl mask systemd-resolved
rm -f /etc/resolv.conf
ln -s /files/resolv.conf.k8s /etc/resolv.conf

echo "Creating docker setup files"
###
mkdir /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100M"
  },
  "storage-driver": "overlay2"
}
EOF

echo "Creating the kind-cluster setup files"
###
cat << EOF >/root/kind-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: local
networking:
  ipFamily: "ipv4"
  disableDefaultCNI: true
  kubeProxyMode: "none"
  podSubnet: "10.20.0.0/16"
  serviceSubnet: "10.21.0.0/16"
  apiServerAddress: ${CURRENT_IP}
  apiServerPort: 6443
kubeadmConfigPatches:
  - |
    apiVersion: kubeadm.k8s.io/v1beta4
    kind: ClusterConfiguration
    apiServer:
      timeoutForControlPlane: 10m
      extraArgs:
        allow-privileged: "true"
        audit-log-path: /audit/k8s-api-audit.log
        audit-log-maxage: "7"
        audit-log-maxbackup: "4"
        audit-log-maxsize: "100"
        authorization-mode: Node,RBAC
      extraVolumes:
        - name: audit-kubernetes
          hostPath: /var/log/kubernetes
          mountPath: /audit
          readOnly: false
          pathType: DirectoryOrCreate
    controllerManager:
      extraArgs:
        allocate-node-cidrs: "true"
        cluster-cidr: 10.20.0.0/16
        # feature-gates: VolumeSnapshotDataSource=true
        node-cidr-mask-size: "24"
    controlPlaneEndpoint: ${CURRENT_IP}:6443
  - |
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    cgroupDriver: systemd
    clusterDNS:
      - 10.21.0.10
    clusterDomain: cluster.local
    serializeImagePulls: false
    resolvConf: "/files/resolv.conf.k8s"

nodes:
  - role: control-plane
    #image: kindest/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31
    extraMounts:
      - hostPath: /files
        containerPath: /files
        propagation: HostToContainer
    kubeadmConfigPatches:
      - |
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: InitConfiguration
        nodeRegistration:
          name: control-plane
          taints: []
          kubeletExtraArgs:
            node-labels: "operator-home=true,bgp=cluster"
  - role: worker
    #image: kindest/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31
    extraMounts:
      - hostPath: /files
        containerPath: /files
        propagation: HostToContainer
    kubeadmConfigPatches:
      - |
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: JoinConfiguration
        nodeRegistration:
          name: worker-1
          taints: []
          kubeletExtraArgs:
            node-labels: "minio=local,operator-home=true,bgp=cluster"
  - role: worker
    #image: kindest/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31
    extraMounts:
      - hostPath: /files
        containerPath: /files
        propagation: HostToContainer
    kubeadmConfigPatches:
      - |
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: JoinConfiguration
        nodeRegistration:
          name: worker-2
          taints: []
          kubeletExtraArgs:
            node-labels: "minio=local,bgp=cluster"
  - role: worker
    #image: kindest/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31
    extraMounts:
      - hostPath: /files
        containerPath: /files
        propagation: HostToContainer
    kubeadmConfigPatches:
      - |
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: JoinConfiguration
        nodeRegistration:
          name: worker-3
          taints: []
          kubeletExtraArgs:
            node-labels: "minio=local,bgp=cluster"
EOF

echo "installing and configuring FRR for BGP routing"
###
DEBIAN_FRONTEND=noninteractive apt-get -y install frr
cat << 'EOF' > /etc/frr/frr.conf
# default to using syslog. /etc/rsyslog.d/45-frr.conf places the log
# in /var/log/frr/frr.log
# log syslog informational
frr version 7.2.1
frr defaults traditional
hostname external-router
debug bgp updates
debug bgp keepalives
log syslog informational
log file /tmp/frr.log
log timestamp precision 3
no ipv6 forwarding
service integrated-vtysh-config
!
router bgp 65000
 bgp router-id 172.18.0.1
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor 172.18.0.2 remote-as 65200
 neighbor 172.18.0.3 remote-as 65200
 neighbor 172.18.0.4 remote-as 65200
 neighbor 172.18.0.5 remote-as 65200
!
address-family ipv4 unicast
 neighbor 172.18.0.2 activate
 neighbor 172.18.0.2 next-hop-self
 neighbor 172.18.0.3 activate
 neighbor 172.18.0.3 next-hop-self
 neighbor 172.18.0.4 activate
 neighbor 172.18.0.4 next-hop-self
 neighbor 172.18.0.5 activate
 neighbor 172.18.0.5 next-hop-self
 maximum-paths 32
exit-address-family
!
line vty
!
EOF

cat << 'EOF' > /etc/frr/daemons
# This file tells the frr package which daemons to start.
#
# Sample configurations for these daemons can be found in
# /usr/share/doc/frr/examples/.
#
# ATTENTION:
#
# When activation a daemon at the first time, a config file, even if it is
# empty, has to be present *and* be owned by the user and group "frr", else
# the daemon will not be started by /etc/init.d/frr. The permissions should
# be u=rw,g=r,o=.
# When using "vtysh" such a config file is also needed. It should be owned by
# group "frrvty" and set to ug=rw,o= though. Check /etc/pam.d/frr, too.
#
# The watchfrr and zebra daemons are always started.
#
bgpd=yes
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
#bfdd=yes
bfdd=no

# If this option is set the /etc/init.d/frr script automatically loads
# the config via "vtysh -b" when the servers are started.
# Check /etc/pam.d/frr if you intend to use "vtysh"!
#
vtysh_enable=yes
zebra_options="  -A 127.0.0.1 -s 90000000"
bgpd_options="   -A 127.0.0.1"
ospfd_options="  -A 127.0.0.1"
ospf6d_options=" -A ::1"
ripd_options="   -A 127.0.0.1"
ripngd_options=" -A ::1"
isisd_options="  -A 127.0.0.1"
pimd_options="   -A 127.0.0.1"
ldpd_options="   -A 127.0.0.1"
nhrpd_options="  -A 127.0.0.1"
eigrpd_options=" -A 127.0.0.1"
babeld_options=" -A 127.0.0.1"
sharpd_options=" -A 127.0.0.1"
pbrd_options="   -A 127.0.0.1"
staticd_options="-A 127.0.0.1"
bfdd_options="   -A 127.0.0.1"

# The list of daemons to watch is automatically generated by the init script.
# watchfrr_options=""

# for debugging purposes, you can specify a "wrap" command to start instead
# of starting the daemon directly, e.g. to use valgrind on ospfd:
#   ospfd_wrap="/usr/bin/valgrind"
# or you can use "all_wrap" for all daemons, e.g. to use perf record:
#   all_wrap="/usr/bin/perf record --call-graph -"
# the normal daemon command is added to this at the end.
EOF
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
curl -LO https://github.com/derailed/k9s/releases/download/v0.28.0/k9s_Linux_amd64.tar.gz
tar xvf k9s_Linux_amd64.tar.gz -C /usr/bin

echo "Installing helm and configuring repositories for templating initial workloads"
curl -LO https://get.helm.sh/helm-v3.13.1-linux-amd64.tar.gz
tar xvf helm-v3.13.1-linux-amd64.tar.gz
mv ./linux-amd64/helm /usr/bin/helm
helm repo add cilium https://helm.cilium.io/
helm repo update

echo "Templating cilium-1.14.4-direct-routing for CNI requirements"
###
helm template cilium/cilium \
    --version "1.14.4" \
    --kube-version="1.27.3" \
    --namespace="kube-system" \
    --set kubeProxyReplacement="strict" \
    --set autoDirectNodeRoutes="true" \
    --set bandwidthManager.enabled="false" \
    --set bandwidthManager.bbr="false" \
    --set cluster.name="local" \
    --set cluster.id=222 \
    --set bgp.enabled=false \
    --set bgp.announce.loadbalancerIP=true \
    --set bgp.announce.podCIDR=true \
    --set bgpControlPlane.enabled=true \
    --set bpf.masquerade="true" \
    --set bpf.lbExternalClusterIP="true" \
    --set bpf.tproxy="false" \
    --set gatewayAPI.enabled="false" \
    --set pmtuDiscovery.enabled="true" \
    --set healthPort=9877 \
    --set ingressController.enabled="true" \
    --set ingressController.loadbalancerMode="dedicated" \
    --set ipam.mode=kubernetes \
    --set ipam.operator.clusterPoolIPv4PodCIDR="10.20.0.0/16" \
    --set ipam.operator.clusterPoolIPv4MaskSize=24 \
    --set kubeProxyReplacementHealthzBindAddr="0.0.0.0:10256" \
    --set k8sServiceHost="${CURRENT_IP}" \
    --set k8sServicePort="6443" \
    --set tunnel="disabled" \
    --set operator.prometheus.enabled=true \
    --set ipv4NativeRoutingCIDR="10.20.0.0/16" \
    --set k8s.requireIPv4PodCIDR="true" \
    --set installIptablesRules="true" \
    --set l7Proxy="true" \
    --set installNoConntrackIptablesRules="true" \
    --set ipMasqAgent.enabled="true" \
    --set loadBalancer.mode="hybrid" \
    --set loadBalancer.acceleration="disabled" \
    --set socketLB.hostNamespaceOnly="true" \
    --set enableCiliumEndpointSlice="true" \
    --set prometheus.enabled="true" \
    --set hubble.enabled="true" \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}" \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set ingressController.ingressLBAnnotationPrefixes='service.beta.kubernetes.io service.kubernetes.io cloud.google.com io.cilium' \
  > /root/cilium-1.14.4-direct-routing.yaml

cat << 'EOF' > /root/bgp-peering-policy.yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: bgp-peering-policy-cluster
spec:
  nodeSelector:
    matchLabels:
      bgp: cluster
  virtualRouters:
  - exportPodCIDR: true
    localASN: 65200
    neighbors:
    - peerASN: 65000
      peerAddress: 172.18.0.1/32
    serviceSelector:
      matchExpressions:
      - key: somekey
        operator: NotIn
        values:
        - never-used-value
EOF

cat << 'EOF' > /root/bgp-ippool.yaml
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "bgp-svc-ips-cluster"
spec:
  cidrs:
  - cidr: "172.18.0.128/25"
EOF

echo "render echoserver deployment to test the cluster"
###
cat << 'EOF' > /root/echoserver.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: echoserver
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echoserver
  namespace: echoserver
spec:
  replicas: 5
  selector:
    matchLabels:
      app: echoserver
  template:
    metadata:
      labels:
        app: echoserver
    spec:
      containers:
      - image: ealen/echo-server:latest
        imagePullPolicy: IfNotPresent
        name: echoserver
        ports:
        - containerPort: 80
        env:
        - name: PORT
          value: "80"
---
apiVersion: v1
kind: Service
metadata:
  name: echoserver
  namespace: echoserver
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
  selector:
    app: echoserver
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echoserver
  namespace: echoserver
  annotations:
    "io.cilium/lb-ipam-ips": "172.18.0.155"
spec:
  ingressClassName: cilium
  rules:
  - host: echoserver.kind.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echoserver
            port:
              number: 80
EOF
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
kind export kubeconfig --name local --kubeconfig /root/.kube/config
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
kubectl wait --kubeconfig /root/.kube/config --for=condition=ready --timeout=-1 pod -l app=echoserver -n echoserver
curl -L http://echoserver.kind.example.com | jq