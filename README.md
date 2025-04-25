# Kubernetes Cluster with Multipass

This repository contains a script to set up a simple Kubernetes cluster via [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) for learning purposes. It deploys Kubernetes version 1.33 using [Cilium](https://cilium.io/) as CNI without Kubeproxy with encryption enabled. It will create Ubuntu 24.04 LTS VMs on your machine using [Multipass](https://multipass.run/).

This allows you to deploy either a single master or a multi-master deployment.

## Requirements

Make sure you have [multipass](https://multipass.run/) and [kubectl](https://kubectl.docs.kubernetes.io/) installed on your machine.

Additionally, if you plan to manage [Cilium](https://cilium.io/) from your machine, ensure you have the [CLI installed](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli); or use it from any of the master nodes.

## Start the cluster

The following starts a cluster with 3 masters behind a proxy and 3 workers with 2 CPUs and 16GB of RAM per instance:

```bash=
./start.sh --workers 3 --cpus 2 --memory 16
```

To learn about all the options and its default values, run the following command:

```bash=
./start.sh -h
```

The cluster is initialized using [cloud-init](https://cloudinit.readthedocs.io/en/latest/), and all the detailes live inside the [kubernetes.yaml](./kubernetes.yaml) file.

## Interact with the cluster

Import the `kubeconfig` configuration on your machine:

```bash=
export KUBECONFIG=$(pwd)/k8s_kube_config.conf
kubectl get nodes
```

## Clean up

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh
```
