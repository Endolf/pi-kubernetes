#!/usr/bin/env bash

set -eo pipefail

./install-kubernetes.sh

sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address=`ifconfig wlan0 | grep "inet addr" | cut -d ":" -f2 | cut -d " " -f1`
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf

kubectl taint nodes --all node-role.kubernetes.io/master-

curl -sSL https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml |  kubectl create -f -
curl -sSL https://rawgit.com/coreos/flannel/master/Documentation/kube-flannel.yml | sed "s/amd64/arm/g" | kubectl create -f -
curl -sSL https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml | sed "s/amd64/arm/g" | kubectl create -f -