.DEFAULT_GOAL := help
COMPOSE := docker compose

# ─── Help ────────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo "kickstart-otel-lgtm"
	@echo ""
	@echo "Setup"
	@echo "  make deps        Install Docker + Docker Compose (Debian/Ubuntu)"
	@echo "  make setup       First-time setup: submodules + .env"
	@echo "  make configure   Interactive guided configuration (writes .env)"
	@echo ""
	@echo "Lifecycle"
	@echo "  make up          Start all services (detached)"
	@echo "  make down        Stop and remove containers"
	@echo "  make restart     Restart all services"
	@echo "  make pull        Pull latest images"
	@echo ""
	@echo "Observability"
	@echo "  make ps          Show container status"
	@echo "  make logs        Follow all logs"
	@echo "  make logs s=<svc> Follow logs for a specific service (eg: make logs s=grafana)"
	@echo ""
	@echo "Cleanup"
	@echo "  make clean       Remove containers, networks, and volumes"

# ─── Setup ───────────────────────────────────────────────────────────────────

.PHONY: deps
deps:
	@echo "==> Installing Docker Engine + Compose plugin (Debian/Ubuntu)..."
	@sudo apt-get update -qq
	@sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
	@sudo install -m 0755 -d /etc/apt/keyrings
	@curl -fsSL https://download.docker.com/linux/$$(. /etc/os-release && echo "$$ID")/gpg \
		| sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	@sudo chmod a+r /etc/apt/keyrings/docker.gpg
	@echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
		https://download.docker.com/linux/$$(. /etc/os-release && echo "$$ID") \
		$$(. /etc/os-release && echo "$$VERSION_CODENAME") stable" \
		| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	@sudo apt-get update -qq
	@sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	@sudo systemctl enable --now docker
	@sudo usermod -aG docker $$USER
	@echo ""
	@echo "Done. Log out and back in (or run 'newgrp docker') for group membership to take effect."
	@docker --version
	@docker compose version

.PHONY: setup
setup:
	@echo "==> Initialising git submodules..."
	git submodule update --init --recursive
	@echo "==> Copying .env.example → .env..."
	@if [ ! -f .env ]; then cp .env.example .env && echo "  Created .env — run 'make configure' to customise."; \
	else echo "  .env already exists, skipping."; fi

.PHONY: configure
configure:
	@bash scripts/configure.sh

# ─── Lifecycle ───────────────────────────────────────────────────────────────

.PHONY: up
up:
	$(COMPOSE) up -d

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: restart
restart:
	$(COMPOSE) restart

.PHONY: pull
pull:
	$(COMPOSE) pull

# ─── Observability ───────────────────────────────────────────────────────────

.PHONY: ps
ps:
	$(COMPOSE) ps

.PHONY: logs
logs:
ifdef s
	$(COMPOSE) logs -f $(s)
else
	$(COMPOSE) logs -f
endif

# ─── Cleanup ─────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	$(COMPOSE) down -v --remove-orphans
