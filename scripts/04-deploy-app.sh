#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="cnpg-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying application services ==="

# Application-facing services that route to the active cluster by name
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
---
apiVersion: v1
kind: Service
metadata:
  name: pg-rw
  labels:
    app: postgres
    operation: read-write
spec:
  type: ClusterIP
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
  selector:
    cnpg.io/podRole: instance
    role: primary
    cnpg.io/cluster: pg-blue
---
apiVersion: v1
kind: Service
metadata:
  name: pg-ro
  labels:
    app: postgres
    operation: read-only
spec:
  type: ClusterIP
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
  selector:
    cnpg.io/podRole: instance
    role: replica
    cnpg.io/cluster: pg-blue
---
apiVersion: v1
kind: Service
metadata:
  name: pg-r
  labels:
    app: postgres
    operation: read-any
spec:
  type: ClusterIP
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
  selector:
    cnpg.io/podRole: instance
    cnpg.io/cluster: pg-blue
EOF

echo "=== Deploying PgBouncer connection pooler ==="
kubectl apply -n "$NAMESPACE" -f "$SCRIPT_DIR/../app/k8s/pgbouncer.yaml"
echo "Waiting for PgBouncer to be ready..."
kubectl rollout status deployment/pgbouncer -n "$NAMESPACE" --timeout=120s

echo "=== Deploying demo application ==="

# Build and load demo app image into k3d
if [ -f "$SCRIPT_DIR/../app/Dockerfile" ]; then
  echo "Building demo app image..."
  docker build -t demo-app:latest "$SCRIPT_DIR/../app/"
  k3d image import demo-app:latest -c cnpg-demo
fi

# Deploy the app
kubectl apply -n "$NAMESPACE" -f "$SCRIPT_DIR/../app/k8s/deployment.yaml"

echo "=== Waiting for app to be ready ==="
kubectl rollout status deployment/demo-app -n "$NAMESPACE" --timeout=120s

echo ""
echo "✅ App and services deployed!"
echo ""
echo "Watch the app logs (zero-downtime proof):"
echo "  kubectl logs -f deployment/demo-app -n $NAMESPACE"
echo ""
echo "Next: ./05-switchover.sh (when ready to demo)"
