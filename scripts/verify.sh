#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE="$ROOT/evidence"
KUBECONFIG="${KUBECONFIG:-$ROOT/.kube/config}"

mkdir -p "$EVIDENCE"

echo "VERIFYING CLUSTER"
echo

date -u +"%Y-%m-%dT%H:%M:%SZ" | tee "$EVIDENCE/timestamp.txt"

echo "[1/7] Nodes ready"
kubectl --kubeconfig "$KUBECONFIG" wait nodes --all --for=condition=Ready --timeout=180s
kubectl --kubeconfig "$KUBECONFIG" get nodes -o wide | tee "$EVIDENCE/nodes.txt"

echo
echo "[2/7] Cluster information"
kubectl --kubeconfig "$KUBECONFIG" cluster-info | tee "$EVIDENCE/cluster-info.txt"

echo
echo "[3/7] System pods"
kubectl --kubeconfig "$KUBECONFIG" get pods -n kube-system -o wide | tee "$EVIDENCE/system-pods.txt"

echo
echo "[4/7] Cilium"
kubectl --kubeconfig "$KUBECONFIG" -n kube-system rollout status daemonset/cilium --timeout=180s
kubectl --kubeconfig "$KUBECONFIG" -n kube-system get pods -l k8s-app=cilium -o wide | tee "$EVIDENCE/cilium.txt"

echo
echo "[5/7] Application rollout"
kubectl --kubeconfig "$KUBECONFIG" -n field-lab rollout status deployment/field-app --timeout=180s
kubectl --kubeconfig "$KUBECONFIG" -n field-lab get pods -o wide | tee "$EVIDENCE/pods.txt"

echo
echo "[6/7] Cluster DNS"
kubectl --kubeconfig "$KUBECONFIG" -n field-lab run dns-check \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -i \
  --command -- nslookup field-app.field-lab.svc.cluster.local \
  | tee "$EVIDENCE/dns.txt"

echo
echo "[7/7] Service reachability"
kubectl --kubeconfig "$KUBECONFIG" -n field-lab run app-check \
  --image=curlimages/curl:8.12.1 \
  --restart=Never \
  --rm -i \
  --command -- curl -fsS http://field-app.field-lab.svc.cluster.local/ \
  | tee "$EVIDENCE/app.txt"

grep -q "KUBERNETES FIELD LAB" "$EVIDENCE/app.txt"

echo
echo "RESULT: CLUSTER HEALTHY"
echo "Evidence written to: $EVIDENCE"
