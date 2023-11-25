# How to create an AKS cluster with cilium
## High-level overview
There are several methods of achieving a working cluster-network for AKS. Ideally we'll be using cilium to leverage advanced networking functionality like network-policies and ingress-/load-balancing services.

## Install the AKS cluster
### Pre-Requisites
You should have an Azure Subscription.

* Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
```

* Install Helm and add cilium repo for templating a working CNI later on

```bash
curl -LO https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz
tar xvf helm-v3.13.2-linux-amd64.tar.gz
sudo mv ./linux-amd64/helm /usr/local/bin/helm
rm -rf ./linux-amd64 && rm helm-v3.13.2-linux-amd64.tar.gz
helm repo add cilium https://helm.cilium.io/
helm repo update
```

* Install the aks-preview Azure CLI extension

```bash
az extension add --name aks-preview
az extension update --name aks-preview
```

* Ensure you have enough quota resources to create an AKS cluster. Go to the Subscription blade, navigate to “Usage + Quotas”, and make sure you have enough quota for the following resources:
  * Regional vCPUs
  * Standard Dv4 Family vCPUs

* Register the `KubeProxyConfigurationPreview` feature flag

```bash
az feature register --namespace "Microsoft.ContainerService" --name "KubeProxyConfigurationPreview"
az feature show --namespace "Microsoft.ContainerService" --name "KubeProxyConfigurationPreview"
```

* make sure the **state** is **Registered** - as it can take a while to propagate. the last command above should produce output like this:

```bash
{
"id": "/subscriptions/<your-subscription-id>/providers/Microsoft.Features/providers/Microsoft.ContainerService/features/KubeProxyConfigurationPreview",
"name": "Microsoft.ContainerService/KubeProxyConfigurationPreview",
"properties": {
    "state": "Registered"
},
"type": "Microsoft.Features/providers/features"
}
```

* once the feature flag is registered, tell the provider about it:

```bash
az provider register --namespace Microsoft.ContainerService
```

* Utilize *kube-proxy* configuration in a new AKS cluster using Azure CLI
  * kube-proxy configuration is a cluster-wide setting. No action is needed to update your services.
  * To begin with, create a JSON configuration file with the desired settings:
  * Note: enabled being set to “true/false” indicates — whether or not you want to deploy the *kube-proxy* DaemonSet. Default value is set to **true**.

```bash 
cat << 'EOF' > kube-proxy.json
{
  "enabled": false,
  "mode": "IPVS",
  "ipvsConfig": {
    "scheduler": "LeastConnection",
    "TCPTimeoutSeconds": 900,
    "TCPFINTimeoutSeconds": 120,
    "UDPTimeoutSeconds": 300
  }
}
EOF
```

### Install the AKS cluster via az tool
* make sure you use the correct subscription to bring up the cluster - here I use an environment variable set in .bashrc for my subscription - you want to export your subscription ID if you haven't set the environment variable

```bash
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
az account set --subscription ${ARM_SUBSCRIPTION_ID}
```

* create a resource-group to hold the cilium-AKS-cluster

```bash
az group create --name cilium-AKS-cluster --location westeurope
```

* since you want to install AKS in **BYOCNI** (bring your own CNI) mode, you need to create an AKS cluster with the **network-plugin** set to **none**

```bash
az aks create -l westeurope -g cilium-AKS-cluster -n cilium-AKS-cluster --kube-proxy-config kube-proxy.json --network-plugin none
```

* once the cluster is created, setup the .kube/config to access the cluster

```bash
az aks get-credentials --resource-group cilium-AKS-cluster --name cilium-AKS-cluster
```

* you should now be able to see the nodes that comprise the cluster - these will be in **NotReady** state, as we haven't deployed a CNI just yet

```bash
kubectl get nodes
```

* should output something similar to this - ignore the errors, as kube-metrics won't work just yet because of a missing CNI:

```bash
kubectl get nodes
E1120 10:47:28.087304    1414 memcache.go:287] couldn't get resource list for metrics.k8s.io/v1beta1: the server is currently unable to handle the request
E1120 10:47:28.105500    1414 memcache.go:121] couldn't get resource list for metrics.k8s.io/v1beta1: the server is currently unable to handle the request
E1120 10:47:28.129387    1414 memcache.go:121] couldn't get resource list for metrics.k8s.io/v1beta1: the server is currently unable to handle the request
E1120 10:47:28.147876    1414 memcache.go:121] couldn't get resource list for metrics.k8s.io/v1beta1: the server is currently unable to handle the request
NAME                                STATUS     ROLES   AGE     VERSION
aks-nodepool1-29247957-vmss000000   NotReady   agent   5m45s   v1.26.6
aks-nodepool1-29247957-vmss000001   NotReady   agent   5m55s   v1.26.6
aks-nodepool1-29247957-vmss000002   NotReady   agent   5m50s   v1.26.6
```

* the next step involves getting the DNS name of the controlplane endpoint - this can be done by issuing:

```bash
kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}'
```

* for example, the output should look similar to this:

```bash
kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}'
Cluster name    Server
cilium-AKS-cluster      https://<your-cluster-endpoint-dns-name>.azmk8s.io:443
```

* you can save the controlplane API server in a variable (given you only have one cluster in your .kube/config file) like this:

```bash
export CONTROLPLANE_ENDPOINT_IP=$(kubectl config view --minify -o jsonpath='{.clusters[].cluster.server}' | cut -f2 -d":" | cut -f3 -d"/")
export CONTROLPLANE_ENDPOINT_PORT=$(kubectl config view --minify -o jsonpath='{.clusters[].cluster.server}' | cut -f3 -d":")
```

* once these values are set - you can deploy cilium CNI to the cluster to get it into a working state
* we will **NOT** use helm to install cilium onto the cluster - as helm doesn't handle CRD updates well enough - so we revert to managing the CNI manually for now

```bash
helm template cilium/cilium \
    --version "1.14.4" \
    --kube-version="1.26.6" \
    --set kubeProxyReplacement="strict" \
    --namespace="kube-system" \
    --set k8sServiceHost="${CONTROLPLANE_ENDPOINT_IP}" \
    --set k8sServicePort="${CONTROLPLANE_ENDPOINT_PORT}" \
    --set aksbyocni.enabled="true" \
    --set nodeinit.enabled="true" \
    --set cluster.name="cilium-AKS-cluster" \
    --set cluster.id=123 \
    --set gatewayAPI.enabled="false" \
    --set pmtuDiscovery.enabled="true" \
    --set healthPort=9877 \
    --set ingressController.enabled="true" \
    --set ingressController.loadbalancerMode="shared" \
    --set kubeProxyReplacementHealthzBindAddr="0.0.0.0:10256" \
    --set operator.prometheus.enabled=true \
    --set installIptablesRules="true" \
    --set l7Proxy="true" \
    --set ipMasqAgent.enabled="true" \
    --set socketLB.hostNamespaceOnly="true" \
    --set enableCiliumEndpointSlice="true" \
    --set prometheus.enabled="true" \
    --set hubble.enabled="true" \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set hubble.metrics.enabled='{dns,drop,tcp,flow,icmp,http}' \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set ingressController.ingressLBAnnotationPrefixes='service.beta.kubernetes.io service.kubernetes.io cloud.google.com io.cilium' \
    --set bpf.masquerade="true" \
    --set bpf.tproxy="true" \
    --set enableIPv4Masquerade="true" \
  > ./cilium-1.14.4-vxlan.yaml
```

* last step is to apply the created CNI configuration to the cluster, so it will transition the node from **NotReady** to **Ready**

```bash
kubectl apply -f cilium-1.14.4-vxlan.yaml
```
* once this is rolled out and the pods are running, you should get an output like the following, when you check the cluster-nodes:

```bash
kubectl get nodes
NAME                                STATUS   ROLES   AGE     VERSION
aks-nodepool1-29247957-vmss000000   Ready    agent   3h53m   v1.26.6
aks-nodepool1-29247957-vmss000001   Ready    agent   3h53m   v1.26.6
aks-nodepool1-29247957-vmss000002   Ready    agent   3h53m   v1.26.6
```

* You should now be able to deploy the **echoserver** workload and get a successful response from the endpoint.

```bash
cat << 'EOF' > ./echoserver.yaml
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
spec:
  ingressClassName: cilium
  rules:
  - host: echoserver.azure.example.com
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
kubectl apply -f ./echoserver.yaml
```

* `/etc/hosts` file needs to be updated with the chosen ingress-host - so http-headers will contain the correct "Host: echoserver.azure.example.com" header

```bash
echo "$(kubectl get service -n echoserver cilium-ingress-echoserver -o jsonpath='{.status.loadBalancer.ingress[0].ip}') echoserver.azure.example.com" >> /etc/hosts
```

* now you should be able to `curl` the endpoint and get a response from the `echoserver` workload.

```bash
curl -L http://echoserver.azure.example.com | jq .
```

* Please notice that we are using plain http requests here - as we won't get into an automated TLS setup for simplicity here.