#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="cnpg-demo"
BLUE_CLUSTER="pg-blue"
GREEN_CLUSTER="pg-green"

echo "=== Setting up replication user and secrets ==="

# Get blue primary pod
PRIMARY_POD=$(kubectl get cluster "$BLUE_CLUSTER" -n "$NAMESPACE" -o jsonpath='{.status.currentPrimary}')
echo "Blue primary pod: $PRIMARY_POD"

# Create streaming replication user
echo "Creating streaming_user..."
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -- psql -U postgres -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'streaming_user') THEN
        CREATE USER streaming_user WITH REPLICATION PASSWORD 'streaming_password';
        RAISE NOTICE 'streaming_user created';
    ELSE
        RAISE NOTICE 'streaming_user already exists';
    END IF;
END
\$\$;
"

# Create replica secrets for both clusters
for CLUSTER in "$BLUE_CLUSTER" "$GREEN_CLUSTER"; do
  SECRET_NAME="${CLUSTER}-replica-user"
  if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Secret $SECRET_NAME already exists"
  else
    echo "Creating secret $SECRET_NAME..."
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
      --from-literal=username=streaming_user \
      --from-literal=password=streaming_password
  fi
done

# Verify
echo ""
echo "=== Verification ==="
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -- psql -U postgres -tAc \
  "SELECT usename, userepl FROM pg_user WHERE usename = 'streaming_user';"
kubectl get secrets -n "$NAMESPACE" | grep replica-user

echo ""
echo "✅ Replication setup complete!"
echo "Next: ./03-deploy-green.sh"
