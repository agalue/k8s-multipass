#!env bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
type multipass >/dev/null 2>&1 || { echo >&2 "multipass required but it's not installed; aborting."; exit 1; }

# Configurable Environment variables
masters="3"
workers="2"
cpus="2"
memory="8"
disk="50"

if [[ $# -gt 0 ]] && [[ "$1" == "-h" ]]; then
  cat <<EOF
Usage: start.sh [parameters]

Parameters:
--masters n   Number of masters (default: $masters)
--workers n   Number of workers (default: $workers)
--cpus n      Number of CPUs per VM (default: $cpus)
--memory n    Amount of Memory in GB per VM (default: $memory)
--disk n      Amount of Disk in GB per worker VM (default: $disk)
EOF
  exit
fi

# Processing parameters
while [[ $# -gt 0 ]]; do
  if [[ $1 == *"--"* ]]; then
    param="${1/--/}"
    declare $param="$2"
  fi
  shift
done

# Validate parameters
if [[ ${cpus} < 2 ]]; then
  echo "ERROR: A minimum of 2 CPUs per VM is required (you specified ${cpus})."
  exit 1
fi
if [[ ${memory} < 2 ]]; then
  echo "ERROR: A minimum of 2GB of RAM per VM is required (you specified ${memory})."
  exit 1
fi

# Internal Fixed Variables
proxy_hostname="k8smain"
master_prefix="k8smaster"
worker_prefix="k8sworker"

# Infrastructure Verification
nodes=$(($masters + $workers))
total_cpus=$(($cpus * $nodes))
total_memory=$(($memory * $nodes))
if [[ ${masters} > 1 ]]; then
  nodes=$(($nodes + 1))
  total_cpus=$(($total_cpus + 1))
  total_memory=$(($total_memory + 1))
fi
echo "Creating cluster using ${masters} masters, ${workers} workers; each VM with ${cpus} CPUs, ${memory}GB of RAM; workers will have ${disk}GB of Disk."
echo "This environment requires ${nodes} VMs, using ${total_cpus} CPUs and ${total_memory}GB of RAM from your machine."
if [[ ${masters} > 1 ]]; then
  echo "An additional VM with 1 CPU and 1GB of RAM will be started as the Load Balancer."
fi

read -p "Do you want to proceed? [y/n]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit
fi
echo "Creating Kubernetes cluster..."

# Start VMs for the Master nodes
for i in $(seq 1 ${masters}); do
  master="${master_prefix}${i}"
  echo "Starting Master ${master}..."
  multipass launch -c ${cpus} -m ${memory}g -n ${master} --cloud-init kubernetes.yaml
done

# Start VMs for the Worker nodes
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Starting Worker ${worker}..."
  multipass launch -c ${cpus} -m ${memory}g -d ${disk}g -n ${worker} --cloud-init kubernetes.yaml
done

# Configure Control Plane nodes
if [[ ${masters} > 1 ]]; then
  echo "Configuring Load Balancer..."
  multipass launch -c 1 -m 1g -n ${proxy_hostname} --cloud-init load-balancer.yaml
  multipass exec ${proxy_hostname} -- sudo /etc/haproxy/setup.sh ${masters} ${master_prefix}
  master="${master_prefix}1"
  echo "Initializing primary master node ${master}..."
  multipass exec ${master} -- sudo kubernetes-setup-primary-master.sh ${proxy_hostname}.local
  multipass transfer ${master}:/tmp/setup_secondary_master.sh .
  multipass transfer ${master}:/tmp/setup_worker.sh .
  for i in $(seq 2 ${masters}); do
    master="${master_prefix}${i}"
    echo "Initializing secondary master node ${master}..."
    multipass transfer ./setup_secondary_master.sh ${master}:/tmp/
    multipass exec ${master} -- sudo bash kubernetes-setup-secondary-master.sh
  done
else
  master="${master_prefix}1"
  echo "Initializing single master node ${master}..."
  multipass exec ${master} -- sudo kubernetes-setup-single-master.sh
  multipass transfer ${master}:/tmp/setup_worker.sh .
fi
multipass transfer ${master_prefix}1:/home/ubuntu/.kube/config kube_config.conf

# Configure Worker nodes
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Initializing worker node ${worker}..."
  multipass transfer ./setup_worker.sh ${worker}:/tmp/
  multipass exec ${worker} -- sudo bash /tmp/setup_worker.sh
done

# Finalizing
rm -f ./setup_secondary_master.sh ./setup_worker.sh
echo 'To access the cluster locally use:'
echo 'export KUBECONFIG=$(pwd)/kube_config.conf'
echo 'Done!'
