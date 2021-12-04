#!env bash

set -e

# Environment variables
workers="2"
cpus="2"
memory="8"
disk="50"

# Processing parameters
while [ $# -gt 0 ]; do
  if [[ $1 == *"--"* ]]; then
    param="${1/--/}"
    declare $param="$2"
  fi
  shift
done

# Validation
if [ $cpu -lt 2 ]; then
  echo "ERROR: A minimum of 2 CPUs per VM is required."
  exit 1
fi
if [ $memory -lt 2 ]; then
  echo "ERROR: A minimum of 2GB of RAM per VM is required."
  exit 1
fi

echo "Creating cluster using: workers=${workers}, cpus=${cpus}, memory=${memory}g, disk=${disk}g"

# Temporal variables
cmd="kubeadm_join_cmd.sh"

# Start and configure Master (do not change vm name)
echo "Starting Master..."
multipass launch -c ${cpus} -m ${memory}g -n k8smaster --cloud-init kubernetes.yaml bionic
multipass transfer ./metrics-server.yaml k8smaster:/home/ubuntu/metrics-server.yaml
multipass exec k8smaster -- sudo kubernetes-setup-master.sh
multipass transfer k8smaster:/home/ubuntu/${cmd} .

# Start and configure Workers (do not change vm name)
for i in $(seq 1 ${workers}); do
  worker="k8sworker${i}"
  echo "Starting Worker ${worker}..."
  multipass launch -c ${cpus} -m ${memory}g -d ${disk}g -n ${worker} --cloud-init kubernetes.yaml bionic
  multipass transfer ./${cmd} ${worker}:/tmp/
  multipass exec ${worker} -- sudo bash /tmp/${cmd}
done
rm ./${cmd}

echo "Done!"
