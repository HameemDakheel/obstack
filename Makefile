# obstack developer shortcuts
.DEFAULT_GOAL := help

COMPOSE       := docker compose -f docker-compose.yml
SIMPLE_FLAGS  := -f compose/simple.yml
DEMO_FLAGS    := -f compose/simple.yml -f compose/otel-demo.yml

.PHONY: help simple stop restart logs verify update config clean demo demo-stop demo-logs

help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

simple: ## Bring up the Simple profile (default for v1).
	$(COMPOSE) $(SIMPLE_FLAGS) up -d
	@echo ""
	@echo "Stack starting... give it ~30s, then run: make verify"
	@echo "Open Grafana at: https://$${DOMAIN:-localhost}/  (admin / from .env)"

stop: ## Stop the running stack (Simple).
	$(COMPOSE) $(SIMPLE_FLAGS) down

restart: stop simple ## Restart the Simple stack.

logs: ## Tail logs from all services (Ctrl-C to exit).
	$(COMPOSE) $(SIMPLE_FLAGS) logs -f --tail=100

verify: ## Run end-to-end stack verification.
	./scripts/verify_stack.sh

update: ## Pull latest images and recreate containers.
	$(COMPOSE) $(SIMPLE_FLAGS) pull
	$(COMPOSE) $(SIMPLE_FLAGS) up -d

config: ## Show the resolved compose config.
	$(COMPOSE) $(SIMPLE_FLAGS) config

demo: ## Bring up Simple stack + OTel demo overlay (needs ~8 GB RAM).
	$(COMPOSE) $(DEMO_FLAGS) up -d
	@echo ""
	@echo "Demo starting (~2 min)... Astronomy Shop services + load generator."
	@echo "Frontend:    http://localhost:8082/"
	@echo "Grafana:     https://$${DOMAIN:-localhost}/   (look at Traces Browser)"

demo-stop: ## Stop the demo overlay (keeps the rest of the stack running).
	$(COMPOSE) $(DEMO_FLAGS) stop demo-frontend demo-cart demo-valkey demo-checkout demo-payment demo-recommendation demo-load-generator
	$(COMPOSE) $(DEMO_FLAGS) rm -f demo-frontend demo-cart demo-valkey demo-checkout demo-payment demo-recommendation demo-load-generator

demo-logs: ## Tail logs from the demo services only.
	$(COMPOSE) $(DEMO_FLAGS) logs -f --tail=100 demo-frontend demo-cart demo-checkout demo-payment demo-recommendation demo-load-generator

clean: ## Stop stack AND remove volumes (DESTRUCTIVE - wipes all data).
	@echo "This will delete all telemetry data. Press Ctrl-C to abort, Enter to continue."
	@read _
	$(COMPOSE) $(DEMO_FLAGS) down -v
