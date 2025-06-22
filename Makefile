# =============================================================================
# DOCKERKIT MAKEFILE
# =============================================================================
# Development environment management for PHP projects
#
# Usage: make <target>
# Help:  make help
# =============================================================================

.DEFAULT_GOAL := help

# Load environment variables from .env file
ENV_FILE := .env
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
endif

# Declare all targets as phony (they don't create files)
.PHONY: help status health setup start stop restart reset \
		build build-nc rebuild shell shell-nginx shell-root \
		lint

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Common command patterns
LOAD_ENV = set -a && source $(ENV_FILE)
DOCKER_COMPOSE = docker compose

# Compose files configuration
COMPOSE_FILES = -f docker-compose.yml
ifneq (,$(wildcard docker-compose.aliases.yml))
    COMPOSE_FILES += -f docker-compose.aliases.yml
    ALIASES_AVAILABLE = true
else
    ALIASES_AVAILABLE = false
endif

# Function to show aliases status
define show_aliases_status
	$(if $(filter true,$(ALIASES_AVAILABLE)), \
		echo "$(BLUE)Using network aliases for .local projects$(NC)", \
		echo "$(YELLOW)No aliases file found, using default configuration$(NC)" && \
		echo "$(YELLOW)Tip: Run 'make setup' to generate aliases for .local projects$(NC)" \
	)
endef

# =============================================================================
# HELP & INFO
# =============================================================================

help: ## Show this help message
	@echo "$(BLUE)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sed 's/^.*Makefile://' | sed 's/:.*## / ## /' | awk 'BEGIN {FS = " ## "}; {printf "  \033[0;32m%-20s\033[0m %s\n", $$1, $$2}' | sort
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  $(GREEN)make start$(NC)          # Start all services"
	@echo "  $(GREEN)make build$(NC)          # Build all containers"
	@echo "  $(GREEN)make shell$(NC)          # Enter workspace container"
	@echo "  $(GREEN)make lint$(NC)           # Run all quality checks"

status: ## Show current system status
	@tools/status.sh

health: ## Check container health status
	@$(DOCKER_COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

setup: ## Complete environment setup (deps, hosts, SSL, nginx for .local projects)
	@tools/setup.sh

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

start: ## Start all services with network aliases
	@echo "$(GREEN)Starting dockerkit services...$(NC)"
	@$(call show_aliases_status)
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) up -d

stop: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) down

restart: ## Restart all services with network aliases
	@echo "$(YELLOW)Restarting all services...$(NC)"
	@$(call show_aliases_status)
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) restart

# =============================================================================
# BUILD MANAGEMENT
# =============================================================================

build: ## Build all containers
	@echo "$(GREEN)Building all containers...$(NC)"
	@$(DOCKER_COMPOSE) build

build-nc: ## Build all containers without cache
	@echo "$(GREEN)Building all containers from scratch...$(NC)"
	@$(DOCKER_COMPOSE) build --no-cache

rebuild: build-nc start ## Rebuild everything and start with aliases

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================

shell: ## Enter workspace container shell
	@$(LOAD_ENV) && $(DOCKER_COMPOSE) exec --user $$APP_USER workspace bash

shell-nginx: ## Enter nginx container shell
	@$(LOAD_ENV) && $(DOCKER_COMPOSE) exec --user $$APP_USER nginx bash

shell-root: ## Enter workspace as root
	@$(DOCKER_COMPOSE) exec --user root workspace bash

# =============================================================================
# CLEANUP & MAINTENANCE
# =============================================================================

reset: ## Reset project to initial state (clean containers, volumes, configs)
	@tools/reset.sh

# =============================================================================
# QUALITY ASSURANCE
# =============================================================================

lint: ## Run all linting and quality checks (Dockerfiles, bash scripts, docker-compose)
	@tools/lint.sh

