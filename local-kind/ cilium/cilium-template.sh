#!/usr/bin/env bash

## create a custom cilium configuration tailored to our specific needs
## TODO: explain subtle diffrerences in different environment and features being used
## this CNI configuration WILL change for all environment - see cluster.id for example

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
  > cilium-1.14.4-direct-routing.yaml
