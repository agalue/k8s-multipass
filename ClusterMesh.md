# Cilium ClusterMesh

By default, Cilium will be deployed as CNI with WireGuard encryption enabled. To ensure that all MultiMesh capabilities are available, both clusters must share the same CA. Do the following to create the CA Root Certificate. If exists, the `start.sh` script will pass it to the Masters to ensure Cilium uses it:

```bash=
step certificate create \
  root.cilium.io \
  ca.crt ca.key \
  --profile root-ca \
  --no-password --insecure \
  --force
```

> The above assumes you have the [Step CLI](https://smallstep.com/docs/step-cli/) tool installed on your system.

Use the following to deploy two clusters with a single master and two worker nodes:

```bash=
yes | ./start.sh --masters 1 --domain east --id 1 --podCIDR 10.11.0.0/16 --svcCIDR 10.12.0.0/16
yes | ./start.sh --masters 1 --domain west --id 2 --podCIDR 10.21.0.0/16 --svcCIDR 10.22.0.0/16
```

> Ensure both clusters have different values for `domain`, `id`, `podCIDR`, and `svcCIDR`. As all the nodes from both clusters can reach each other, we have the networking requirements for Cluster Mesh.

Import the `kubeconfig` from both clusters:

```bash=
./update-config.sh east
./update-config.sh west
export KUBECONFIG="$(pwd)/east-kubeconfig.conf:$(pwd)/west-kubeconfig.conf"
```

It is recommended to use `LoadBalancer` as the service type for the mesh connection establishment. For that, we must deploy a Load Balancing solution. We could use MetalLB, but Cilium does offer the same functionality:

```bash=
declare -A subnets=([east]=240 [west]=248)
for domain in east west; do
  ip=$(multipass list --format json | jq -jr ".list[]|select(.name|test(\"${domain}-master1\"))|.ipv4[0]")
  cat <<EOF | kubectl create --context ${domain} -f -
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: ${domain}-policy
spec:
  interfaces:
  - ens3
  externalIPs: true
  loadBalancerIPs: true
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: ${domain}-pool
spec:
  cidrs:
  - cidr: "${ip%.*}.${subnets[$domain]}/29"
EOF
done
```

> Ensure the IP ranges are different and won't collide with the IPs assigned to the running Multipass VMs. For reference, the above takes different subnets from the IP of each master node. The primary motivator to use the above solution was that I tried MetalLB, but it didn't work.

Deploy the Cilium ClusterMesh components and connect the clusters:

```bash=
for ctx in east west; do
  cilium clustermesh enable --service-type LoadBalancer --context ${ctx}
  cilium clustermesh status --wait --context ${ctx}
done
cilium clustermesh connect --context east --destination-context west
for ctx in east west; do
  cilium clustermesh status --wait --context ${ctx}
done
```

Run the following command to verify functionality:
```bash=
cilium connectivity test --context east --multi-cluster west
```

Execute the following command to delete the VMs and purge the state of `multipass`:

```bash=
./cleanup.sh east
./cleanup.sh west
rm -f east-* west-*
```
