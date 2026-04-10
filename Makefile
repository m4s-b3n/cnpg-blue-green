.PHONY: setup deploy-blue replication deploy-green deploy-app switch teardown demo logs status

# Full demo sequence
demo: setup deploy-blue replication deploy-green deploy-app
	@echo ""
	@echo "🎉 Demo ready! Watch the app:"
	@echo "  make logs"
	@echo ""
	@echo "Trigger switchover:"
	@echo "  make switch"

setup:
	@bash scripts/00-setup.sh

deploy-blue:
	@bash scripts/01-deploy-blue.sh

replication:
	@bash scripts/02-setup-replication.sh

deploy-green:
	@bash scripts/03-deploy-green.sh

deploy-app:
	@bash scripts/04-deploy-app.sh

switch:
	@bash scripts/05-switchover.sh

teardown:
	@bash scripts/06-teardown.sh

# Watch the demo app logs (proof of zero downtime)
logs:
	@kubectl logs -f deployment/demo-app -n cnpg-demo

# Show cluster and pod status
status:
	@echo "=== Clusters ==="
	@kubectl get clusters -n cnpg-demo -o wide 2>/dev/null || echo "No clusters found"
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -n cnpg-demo -L active,role,cnpg.io/instanceRole 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n cnpg-demo 2>/dev/null || echo "No services found"
