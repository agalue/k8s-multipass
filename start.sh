#!env bash

set -e

# Environment variables
workers="2"
cpus="2"
memory="8g"
disk="50g"

# Processing parameters
while [ $# -gt 0 ]; do
  if [[ $1 == *"--"* ]]; then
    param="${1/--/}"
    declare $param="$2"
  fi
  shift
done
echo "Creating cluster using: workers=$workers, cpus=$cpus, memory=$memory, disk=$disk"

# Temporal variables
cmd="kubeadm_join_cmd.sh"

# Start and configure Master (do not change vm name)
echo "Starting Master..."
multipass launch -c $cpus -m $memory -n k8smaster --cloud-init kubernetes.yaml bionic
multipass exec k8smaster -- sudo kubernetes-setup-master.sh
multipass transfer k8smaster:/home/ubuntu/$cmd .
multipass transfer ./metrics-server.yaml k8smaster:/home/ubuntu/metrics-server.yaml

# Start and configure Workers (do not change vm name)
for i in $(seq 1 $workers); do
  echo "Starting Worker $i..."
  multipass launch -c $cpus -m $memory -d $disk -n k8sworker$i --cloud-init kubernetes.yaml bionic
  multipass transfer ./$cmd k8sworker$i:/tmp/
  multipass exec k8sworker$i -- sudo bash /tmp/$cmd
done
rm ./$cmd

echo "Done!"
