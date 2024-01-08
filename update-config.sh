#!/usr/local/bin/bash

set -eu

for cmd in "multipass" "openssl" "kubectl"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

domain=${1-east}
user="${domain}-admin"
fileName="${domain}-kubeconfig.conf"

multipass transfer ${domain}-master1:/home/ubuntu/.kube/config ${fileName}

export KUBECONFIG="${fileName}"
kubectl config use-context kubernetes-admin@${domain}

openssl genrsa -out ${user}.key 2048
openssl req -new -key ${user}.key -out ${user}.csr -subj "/CN=${user}/O=kubeadm:cluster-admins"

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${user}
spec:
  request: $(cat ${user}.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  groups:
  - kubeadm:cluster-admins
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

kubectl certificate approve ${user}
kubectl get csr ${user} -o jsonpath='{.status.certificate}' | base64 -d > ${user}.crt
kubectl config set-credentials ${user} --client-certificate=${user}.crt --client-key=${user}.key --embed-certs=true
kubectl config set-context ${domain} --user=${user} --cluster=${domain}
kubectl config use-context ${domain}
kubectl config view --kubeconfig=${fileName} --minify --flatten > ${fileName}.tmp

mv -f ${fileName}.tmp ${fileName}
rm -f ${user}.*
