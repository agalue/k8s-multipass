#!env bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
type multipass >/dev/null 2>&1 || { echo >&2 "multipass required but it's not installed; aborting."; exit 1; }

# Configurable Environment variables
masters="3"
workers="2"
cpus="2"
memory="8"
disk="20"

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
hosts_file="/tmp/__etc_hosts"

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

read -p "Do you want to proceed? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit
fi
echo "Creating Kubernetes cluster..."

# Start Load Balancer if applies (do not change vm name)
if [[ ${masters} > 1 ]]; then
  echo "Starting Load Balancer ${proxy_hostname}..."
  multipass launch -c 1 -m 1g -n ${proxy_hostname} --cloud-init load-balancer.yaml
fi

# Start Masters (do not change vm name)
for i in $(seq 1 ${masters}); do
  master="${master_prefix}${i}"
  echo "Starting Master ${master}..."
  multipass launch -c ${cpus} -m ${memory}g -n ${master} --cloud-init kubernetes.yaml
done

# Start Workers (do not change vm name)
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Starting Worker ${worker}..."
  multipass launch -c ${cpus} -m ${memory}g -d ${disk}g -n ${worker} --cloud-init kubernetes.yaml
done

# Update the /etc/hosts file on each VM (and configure proxy)
multipass list --format json | jq -jr '.list[]|select(.name|test("k8s"))|.ipv4[0]," ",.name,"\n"' > ${hosts_file}
if [[ ${masters} > 1 ]]; then
  echo "Updating /etc/hosts for ${proxy_hostname}..."
  multipass transfer ${hosts_file} ${proxy_hostname}:${hosts_file}
  multipass exec ${proxy_hostname} -- sh -c "cat ${hosts_file} | sudo tee -a /etc/hosts"
  multipass exec ${proxy_hostname} -- sudo /etc/haproxy/setup.sh ${masters} ${master_prefix}
fi
for i in $(seq 1 ${masters}); do
  master="${master_prefix}${i}"
  echo "Updating /etc/hosts for ${master}..."
  multipass transfer ${hosts_file} ${master}:${hosts_file}
  multipass exec ${master} -- sh -c "cat ${hosts_file} | sudo tee -a /etc/hosts"
done
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Updating /etc/hosts for ${worker}..."
  multipass transfer ${hosts_file} ${worker}:${hosts_file}
  multipass exec ${worker} -- sh -c "cat ${hosts_file} | sudo tee -a /etc/hosts"
done

# Configure/Start Cluster
master="${master_prefix}1"
if [[ ${masters} > 1 ]]; then
  echo "Initializing primary master node ${master}..."
  proxy_ip=$(grep ${proxy_hostname} /tmp/__etc_hosts | awk '{print $1}')
  multipass exec ${master} -- sudo kubernetes-setup-primary-master.sh ${proxy_ip}
  multipass transfer ${master}:/tmp/setup_secondary_master.sh .
  multipass transfer ${master}:/tmp/setup_worker.sh .
else
  master="${master_prefix}1"
  echo "Initializing single master node ${master}..."
  multipass exec ${master} -- sudo kubernetes-setup-single-master.sh
  multipass transfer ${master}:/tmp/setup_worker.sh .
fi
multipass transfer ${master}:/home/ubuntu/.kube/config kube_config.conf
for i in $(seq 2 ${masters}); do
  master="${master_prefix}${i}"
  echo "Initializing secondary master node ${master}..."
  multipass transfer ./setup_secondary_master.sh ${master}:/tmp/
  multipass exec ${master} -- sudo bash kubernetes-setup-secondary-master.sh
done
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Initializing worker node ${worker}..."
  multipass transfer ./setup_worker.sh ${worker}:/tmp/
  multipass exec ${worker} -- sudo bash /tmp/setup_worker.sh
done

# Finalizing
rm -f ./setup_secondary_master.sh ./setup_worker.sh ${hosts_file}
echo "Make sure to copy the kube_config.conf file to ~/.kube/config"
echo "Done!"
