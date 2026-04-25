# OTel-jps developer shortcuts
.DEFAULT_GOAL := help

COMPOSE       := docker compose -f docker-compose.yml
SIMPLE_FLAGS  := -f compose/simple.yml

.PHONY: help simple stop restart logs verify update config clean

help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

simple: ## Bring up the Simple profile (default for v1).
	$(COMPOSE) $(SIMPLE_FLAGS) up -d
	@echo ""
	@echo "Stack starting... give it ~30s, then run: make verify"

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

clean: ## Stop stack AND remove volumes (DESTRUCTIVE - wipes all data).
	@echo "This will delete all telemetry data. Press Ctrl-C to abort, Enter to continue."
	@read _
	$(COMPOSE) $(SIMPLE_FLAGS) down -v
