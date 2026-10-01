#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONFIG="${KUBECONFIG:-$ROOT/.kube/config}"

echo
echo "NODES"
kubectl --kubeconfig "$KUBECONFIG" get nodes -o wide

echo
echo "FIELD-LAB POD PLACEMENT"
kubectl --kubeconfig "$KUBECONFIG" get pods -n field-lab -o wide

echo
echo "CILIUM"
kubectl --kubeconfig "$KUBECONFIG" get pods -n kube-system -l k8s-app=cilium -o wide
