#!env bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
type multipass >/dev/null 2>&1 || { echo >&2 "multipass required but it's not installed; aborting."; exit 1; }

# Configurable Environment variables
domain="k8s"
id="1"
podCIDR="10.244.0.0/16"
svcCIDR="10.96.0.0/12"
masters="3"
workers="2"
cpus="2"
memory="8"
disk="50"

if [[ $# -gt 0 ]] && [[ "$1" == "-h" ]]; then
  cat <<EOF
Usage: start.sh [parameters]

Parameters:
--domain txt   Kubernetes Cluster Name and Hostname Prefix for all nodes (default: $domain)
--id num       Cilium ID for ClusterMesh (default: $id)
--podCIDR txt  Pod Network CIDR (default: $podCIDR)
--svcCIDR txt  Service Network CIDR (default: $svcCIDR)
--masters num  Number of masters (default: $masters)
--workers num  Number of workers (default: $workers)
--cpus num     Number of CPUs per VM (default: $cpus)
--memory num   Amount of Memory in GB per VM (default: $memory)
--disk num     Amount of Disk in GB per worker VM (default: $disk)
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
proxy_hostname="${domain}-main"
master_prefix="${domain}-master"
worker_prefix="${domain}-worker"
kubeconfig="${domain}-kubeconfig.conf"

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
echo "Creating Kubernetes cluster ${domain}..."

# Start VMs for the Master nodes
for i in $(seq 1 ${masters}); do
  master="${master_prefix}${i}"
  echo "Starting Master ${master}..."
  multipass launch -c ${cpus} -m ${memory}g -n ${master} --cloud-init kubernetes.yaml
  if [ -e ca.crt ] && [ -e ca.key ]; then
    multipass transfer ca.crt ca.key ${master}:/tmp/
  fi
done

# Start VMs for the Worker nodes
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Starting Worker ${worker}..."
  multipass launch -c ${cpus} -m ${memory}g -d ${disk}g -n ${worker} --cloud-init kubernetes.yaml
done

# Configure Control Plane nodes
master="${master_prefix}1"
if [[ ${masters} > 1 ]]; then
  echo "Configuring Load Balancer..."
  multipass launch -c 1 -m 1g -n ${proxy_hostname} --cloud-init load-balancer.yaml
  proxy_ip=$(multipass info ${proxy_hostname} | grep IPv4 | awk '{print $2}')
  addresses=$(multipass info ${master_prefix}{1..${masters}} | grep IPv4 | awk '{print $2}' | tr '\n' ' ')
  multipass exec ${proxy_hostname} -- sudo /etc/haproxy/setup.sh "${master_prefix}" "${addresses}"
  echo "Initializing primary master node ${master}..."
  multipass exec ${master} -- sudo kubernetes-create-config.sh ${podCIDR} ${svcCIDR} ${proxy_ip}
  multipass exec ${master} -- sudo kubernetes-setup-primary-master.sh ${id}
  multipass transfer ${master}:/tmp/setup_secondary_master.sh .
  multipass transfer ${master}:/tmp/setup_worker.sh .
  for i in $(seq 2 ${masters}); do
    master="${master_prefix}${i}"
    echo "Initializing secondary master node ${master}..."
    multipass transfer ./setup_secondary_master.sh ${master}:/tmp/
    multipass exec ${master} -- sudo bash kubernetes-setup-secondary-master.sh
  done
else
  echo "Initializing single master node ${master}..."
  multipass exec ${master} -- sudo kubernetes-create-config.sh ${podCIDR} ${svcCIDR}
  multipass exec ${master} -- sudo kubernetes-setup-single-master.sh ${id}
  multipass transfer ${master}:/tmp/setup_worker.sh .
fi

# Copy configuration
multipass transfer ${master_prefix}1:/home/ubuntu/.kube/config ${kubeconfig}

# Configure Worker nodes
for i in $(seq 1 ${workers}); do
  worker="${worker_prefix}${i}"
  echo "Initializing worker node ${worker}..."
  multipass transfer ./setup_worker.sh ${worker}:/tmp/
  multipass exec ${worker} -- sudo bash /tmp/setup_worker.sh
done

# Finalizing
rm -f ./setup_secondary_master.sh ./setup_worker.sh
echo "To access the cluster locally use:"
echo "export KUBECONFIG=$(pwd)/${kubeconfig}"
echo "Done!"
