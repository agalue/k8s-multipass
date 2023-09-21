# Kubernetes Cluster with Multipass

## Requirements

Make sure you have [Multipass](https://multipass.run/) installed on your machine.

## Start the cluster

The following starts a cluster with a single master and 3 workers on Ubuntu with 2 CPUs and 8GB of RAM per instance, execute the following command:

```bash=
./start.sh --workers 3 --cpus 2 --memory 16g
```

Default values are:

* 3 master nodes (`--masters`) - use 1 for a single master
* 2 worker nodes (`--workers`)
* 2 CPUs per VM (`--cpus`)
* 8 GB of RAM per VM (`--memory`)
* 20 GB for Disk per Worker VM (`--disk`)
* The master node will use the same settings

The cluster is initialized using [cloud-init](https://cloudinit.readthedocs.io/en/latest/), and all the detailes live inside the [kubernetes.yaml](./kubernetes.yaml) file.

## Interact with the cluster

If you choose to have only one master, open a session against the master:

```bash=
multipass shell k8smaster
```

From there, `kubectl` is already configured for the default user (i.e., `ubuntu`), and the alias `k` can be used. In both cases, bash-completion is enabled.

However, if you choose to have multiple master servers, an additional load balancer was configured, and you can do the following from hour machine (assuming you have `kubectl` installed):

```bash=
KUBECONFIG=$(pwd)/kube-config.yaml
kubectl get nodes
```

`kube_config.conf` was created by the `start.sh` script and should use the LB to access the cluster.

## Clean up

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh
```
