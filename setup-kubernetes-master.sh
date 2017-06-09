#!/usr/bin/env bash

set -eo pipefail

sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address=`ifconfig wlan0 | grep "inet addr" | cut -d ":" -f2 | cut -d " " -f1`
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf

kubectl taint nodes --all node-role.kubernetes.io/master-

curl -sSL https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml |  kubectl create -f -
curl -sSL https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel.yml | sed "s/amd64/arm/g" | kubectl create -f -
curl -sSL https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml | sed "s/amd64/arm/g" | kubectl create -f -

curl -sSL https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml | kubectl create -f -
curl -sSL https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml | sed "s/amd64/arm/g" | kubectl create -f -
curl -sSL https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/grafana.yaml | sed "s/amd64/arm/g" | sed "s/v4.2.0/v4.0.2/g" | kubectl create -f -
curl -sSL https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml | sed "s/amd64/arm/g" | kubectl create -f -