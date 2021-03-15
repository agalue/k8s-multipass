# Kubernetes Cluster with Multipass

## Requirements

Make sure you have [Multipass](https://multipass.run/) installed on your machine.

## Start the cluster

The following starts a cluster with a single master and 3 workers on Ubuntu 18.0.4, execute the following command:

```bash=
./start.sh 3
```

> When the number of workers is not specified, the default is 2.

The cluster is initialized using [cloud-init](https://cloudinit.readthedocs.io/en/latest/), and all the detailes live inside the [kubernetes.yaml])./kubernetes.yaml) file.

## Interact with the cluster

Open a session against the master:

```bash=
multipass shell k8smaster
```

From there, `kubectl` is already configured for the default user (i.e., `ubuntu`), and the alias `k` can be used. In both cases, bash-completion is enabled.

```bash=
ubuntu@k8smaster:~$ k get nodes -o wide
NAME         STATUS   ROLES                  AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
k8smaster    Ready    control-plane,master   56m   v1.20.4   192.168.75.6    <none>        Ubuntu 18.04.5 LTS   4.15.0-136-generic   containerd://1.3.3
k8sworker1   Ready    <none>                 11m   v1.20.4   192.168.75.11   <none>        Ubuntu 18.04.5 LTS   4.15.0-136-generic   containerd://1.3.3
k8sworker2   Ready    <none>                 10m   v1.20.4   192.168.75.12   <none>        Ubuntu 18.04.5 LTS   4.15.0-136-generic   containerd://1.3.3
```

## Clean up

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh
```

> **WARNING**: If there are already deleted VMs, the purge command will permanently remove them.