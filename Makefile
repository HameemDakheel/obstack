# obstack developer shortcuts
.DEFAULT_GOAL := help

COMPOSE        := docker compose -f docker-compose.yml
SIMPLE_FLAGS   := -f compose/simple.yml
STANDARD_FLAGS := -f compose/standard.yml

.PHONY: help simple stop restart logs verify update config clean standard standard-stop standard-logs standard-verify demo-up demo-down demo-logs

help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

simple: ## Bring up the Simple profile (default).
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

standard: ## Bring up the Standard profile (8 GB host, 30-day retention).
	$(COMPOSE) $(STANDARD_FLAGS) up -d
	@echo ""
	@echo "Standard stack starting... give it ~45s, then run: make standard-verify"
	@echo "Open Grafana at: https://$${DOMAIN:-localhost}/  (admin / from .env)"

standard-stop: ## Stop the Standard profile stack.
	$(COMPOSE) $(STANDARD_FLAGS) down

standard-logs: ## Tail Standard-profile logs.
	$(COMPOSE) $(STANDARD_FLAGS) logs -f --tail=100

standard-verify: ## Run end-to-end verification on the Standard stack.
	./scripts/verify_stack.sh

clean: ## Stop stack AND remove volumes (DESTRUCTIVE - wipes all data).
	@echo "This will delete all telemetry data. Press Ctrl-C to abort, Enter to continue."
	@read _
	$(COMPOSE) $(SIMPLE_FLAGS) down -v

DEMO_COMPOSE := docker compose \
	--env-file examples/otel-demo/upstream/.env \
	--env-file examples/otel-demo/.env \
	-f examples/otel-demo/upstream/docker-compose.yml \
	-f examples/otel-demo/docker-compose.override.yml \
	-p obstack-demo

demo-up: ## Bring up the OTel demo as an external test client (needs ~6 GB RAM).
	./scripts/demo-up.sh

demo-down: ## Stop the demo client.
	$(DEMO_COMPOSE) down

demo-logs: ## Tail demo client logs (Ctrl-C to exit).
	$(DEMO_COMPOSE) logs -f --tail=100
