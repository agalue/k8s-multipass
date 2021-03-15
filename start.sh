#!/usr/local/bin/bash

# Total workers to start (default: 2)
workers=${1-2}

# Temporal variables
cmd="kubeadm_join_cmd.sh"

# Start and configure Master (do not change vm name)
echo "Starting Master..."
multipass launch -c 2 -m 8g -n k8smaster --cloud-init kubernetes.yaml bionic
multipass transfer k8smaster:/home/ubuntu/$cmd .

# Start and configure Workers (do not change vm name)
for i in $(seq 1 $workers); do
  echo "Starting Worker $i..."
  multipass launch -c 2 -m 8g -n k8sworker$i --cloud-init kubernetes.yaml bionic
  multipass transfer ./$cmd k8sworker$i:/tmp/
  multipass exec k8sworker$i -- sudo bash /tmp/$cmd
done
rm ./$cmd

echo "Done!"
