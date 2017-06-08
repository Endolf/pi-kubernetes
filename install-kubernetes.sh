#!/usr/bin/env bash

set -eo pipefail

curl -sSL https://get.docker.com | sudo sh

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
fi
sudo apt-get update && sudo apt-get install -y kubeadm
