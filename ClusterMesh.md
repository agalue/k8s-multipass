# Cilium ClusterMesh

By default, Cilium will be deployed as CNI with WireGuard encryption enabled. To ensure that all MultiMesh capabilities are available, both clusters must share the same CA. Do the following to create the CA Root Certificate. If exists, the `start.sh` script will pass it to the Masters to ensure Cilium uses it:

```bash=
step certificate create \
  root.cilium \
  ca.crt ca.key \
  --profile root-ca \
  --no-password --insecure \
  --force
```

> The above assumes you have the [Step CLI](https://smallstep.com/docs/step-cli/) tool installed on your system.

Use the following to deploy two clusters with a single master and two worker nodes:

```bash=
./start.sh --masters 1 --domain east --id 1 --podCIDR 10.1.0.0/16 --svcCIDR 11.1.0.0/16
./start.sh --masters 1 --domain west --id 2 --podCIDR 10.2.0.0/16 --svcCIDR 11.2.0.0/16
```

> Ensure both clusters have different values for `domain`, `id`, `podCIDR`, and `svcCIDR`. As all the nodes from both clusters can reach each other, we have the networking requirements for Cluster Mesh.

Import the `kubeconfig` from both clusters:

```bash=
./update-config.sh east
./update-config.sh west
export KUBECONFIG="$(pwd)/east_kube_config_v2.conf:$(pwd)/west_kube_config_v2.conf"
```

It is recommended to use `LoadBalancer` as the service type for the mesh connection establishment. For that, we must deploy a Load Balancer solution, so the following installs MetalLB in both clusters:

```bash=
helm repo add metallb https://metallb.github.io/metallb
helm repo update
i=1
for ctx in "east" "west"; do
  kubectl config use-context ${ctx}
  helm install metallb metallb/metallb -n metallb-system --create-namespace --wait
  cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lb-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.65.2${i}1-192.168.65.2${i}9
EOF
  ((i++))
done
```

> Ensure the IP ranges are different and won't collide with the IPs assigned to the running Multipass VMs.

Deploy the Cilium ClusterMesh components and connect the clusters:

```bash=
for ctx in "east" "west"; do
  cilium clustermesh enable --service-type LoadBalancer --context ${ctx}
  cilium clustermesh status --wait --context ${ctx}
done
cilium clustermesh connect --context east --destination-context west
```

Run the following command to verify functionality:
```bash=
cilium connectivity test --context east --multi-cluster west
```

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh east
./cleanup.sh west
rm -f east* west*
```
