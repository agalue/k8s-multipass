# Kubernetes Cluster with Multipass

This repository contains a simple script to set up a simple Kubernetes cluster via Kubeadm for learning purposes. It deploys the latest version (v1.29) using Cilium as CNI without Kubeproxy. It will create Ubuntu 22.04 LTS VMs on your machine using Multipass.

## Requirements

Make sure you have [Multipass](https://multipass.run/) installed on your machine.

## Start the cluster

The following starts a cluster with a single master and 3 workers on Ubuntu with 2 CPUs and 8GB of RAM per instance, execute the following command:

```bash=
./start.sh --workers 3 --cpus 2 --memory 16g
```

Default values are:

* 2 worker nodes (`--workers`)
* 2 CPUs per VM (`--cpus`)
* 8 GB of RAM per VM (`--memory`)
* The master node will use the same settings

The cluster is initialized using [cloud-init](https://cloudinit.readthedocs.io/en/latest/), and all the detailes live inside the [kubernetes.yaml](./kubernetes.yaml) file.

## Interact with the cluster

Open a session against the master:

```bash=
multipass shell k8smaster
```

From there, `kubectl` is already configured for the default user (i.e., `ubuntu`), and the alias `k` can be used. In both cases, bash-completion is enabled.

```bash=
ubuntu@k8smaster:~$ k get nodes -o wide
NAME         STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8smaster    Ready    control-plane   4m31s   v1.29.0   192.168.65.39   <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.2
k8sworker1   Ready    <none>          2m23s   v1.29.0   192.168.65.40   <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.2
k8sworker2   Ready    <none>          34s     v1.29.0   192.168.65.41   <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.2
```

## Clean up

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh
```
