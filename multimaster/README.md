# Kubernetes Cluster with Multipass

This repository contains a simple script to set up a simple Kubernetes cluster via Kubeadm for learning purposes. It deploys the latest version (v1.29) using Cilium as CNI without Kubeproxy. It will create Ubuntu 22.04 LTS VMs on your machine using Multipass.

This allows you to deploy either a single master or a multi-master deployment.

## Requirements

Make sure you have [Multipass](https://multipass.run/) installed on your machine.

## Start the cluster

The following starts a cluster with 3 masters behind a proxy and 3 workers with 2 CPUs and 16GB of RAM per instance:

```bash=
./start.sh --workers 3 --cpus 2 --memory 16
```

Default values are:

* 3 master nodes (`--masters`) - use 1 for a single master
* 2 worker nodes (`--workers`)
* 2 CPUs per VM (`--cpus`)
* 8 GB of RAM per VM (`--memory`)
* 50 GB for Disk per worker VM (`--disk`)
* All node kinds share the same CPU and Memory.

The cluster is initialized using [cloud-init](https://cloudinit.readthedocs.io/en/latest/), and all the detailes live inside the [kubernetes.yaml](./kubernetes.yaml) file.

## Interact with the cluster

If you choose to have only one master, open a session against the master:

```bash=
multipass shell k8smaster
```

From there, `kubectl` is already configured for the default user (i.e., `ubuntu`), and the alias `k` can be used. In both cases, bash-completion is enabled.

However, if you choose to have multiple master servers, an additional load balancer was configured, and you can do the following from hour machine (assuming you have `kubectl` installed):

```bash=
export KUBECONFIG=$(pwd)/kube_config.conf
kubectl get nodes
```

> The `kube_config.conf` file was created by the `start.sh` script and should use the LB to access the cluster.

## Clean up

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh
```
