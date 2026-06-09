.DEFAULT_GOAL := help
COMPOSE      := docker compose
PROJECT_NAME := kickstart-otel-lgtm
BACKUP_DIR   := backups

# ─── Help ────────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo "kickstart-otel-lgtm"
	@echo ""
	@echo "Setup"
	@echo "  make deps              Install Docker + Docker Compose (Debian/Ubuntu)"
	@echo "  make setup             First-time setup: submodules + .env"
	@echo "  make configure         Interactive guided configuration (writes .env)"
	@echo ""
	@echo "Lifecycle"
	@echo "  make up                Start all services (detached)"
	@echo "  make down              Stop and remove containers"
	@echo "  make restart           Restart all services"
	@echo "  make restart s=<svc>   Restart a specific service"
	@echo "  make update            Pull latest images and restart"
	@echo "  make pull              Pull latest images (no restart)"
	@echo ""
	@echo "Observability"
	@echo "  make check             Check health of all services"
	@echo "  make ps                Show container status"
	@echo "  make logs              Follow all logs"
	@echo "  make logs s=<svc>      Follow logs for a specific service"
	@echo "  make open              Open Grafana in the browser"
	@echo "  make smoke-test        Send a test trace and verify end-to-end"
	@echo ""
	@echo "Backup"
	@echo "  make backup            Backup all volumes to ./$(BACKUP_DIR)/"
	@echo "  make restore file=<f>  Restore volumes from a backup file"
	@echo ""
	@echo "Cleanup"
	@echo "  make clean             Remove containers, networks, and volumes"

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
ifdef s
	$(COMPOSE) restart $(s)
else
	$(COMPOSE) restart
endif

.PHONY: update
update:
	$(COMPOSE) pull
	$(COMPOSE) up -d

.PHONY: pull
pull:
	$(COMPOSE) pull

# ─── Observability ───────────────────────────────────────────────────────────

.PHONY: check
check:
	@echo "" && \
	printf '  %-22s %s\n' "Service" "Status" && \
	printf '  %s\n' "─────────────────────────────────" && \
	for row in \
		"Loki|http://localhost:3100/ready" \
		"Tempo|http://localhost:3200/ready" \
		"Mimir|http://localhost:9009/ready" \
		"OTel Collector|http://localhost:13133/" \
		"Grafana|http://localhost:3000/api/health"; do \
		label=$$(echo "$$row" | cut -d'|' -f1); \
		url=$$(echo "$$row" | cut -d'|' -f2); \
		if curl -sf --max-time 3 "$$url" > /dev/null 2>&1; then \
			printf '  %-22s \033[32mUP\033[0m\n' "$$label"; \
		else \
			printf '  %-22s \033[31mDOWN\033[0m\n' "$$label"; \
		fi; \
	done && echo ""

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

.PHONY: open
open:
	@if command -v xdg-open > /dev/null 2>&1; then xdg-open http://localhost:3000; \
	elif command -v open > /dev/null 2>&1; then open http://localhost:3000; \
	else echo "  Open http://localhost:3000 in your browser"; fi

.PHONY: smoke-test
smoke-test:
	@bash scripts/smoke-test.sh

# ─── Backup ──────────────────────────────────────────────────────────────────

.PHONY: backup
backup:
	@mkdir -p $(BACKUP_DIR) && \
	FNAME="$(BACKUP_DIR)/backup-$$(date +%Y%m%d-%H%M%S).tar.gz" && \
	echo "==> Backup in corso → $$FNAME" && \
	docker run --rm \
		-v $(PROJECT_NAME)_loki-data:/src/loki:ro \
		-v $(PROJECT_NAME)_tempo-data:/src/tempo:ro \
		-v $(PROJECT_NAME)_mimir-data:/src/mimir:ro \
		-v $(PROJECT_NAME)_grafana-data:/src/grafana:ro \
		-v "$(CURDIR)/$(BACKUP_DIR):/dst" \
		alpine tar czf "/dst/$$(basename $$FNAME)" -C /src . && \
	echo "  Salvato: $$FNAME"

.PHONY: restore
restore:
ifndef file
	$(error Uso: make restore file=backups/backup-YYYYMMDD-HHMMSS.tar.gz)
endif
	@echo "==> Fermo i servizi..." && \
	$(COMPOSE) down && \
	echo "==> Ripristino da $(file)..." && \
	docker run --rm \
		-v $(PROJECT_NAME)_loki-data:/dst/loki \
		-v $(PROJECT_NAME)_tempo-data:/dst/tempo \
		-v $(PROJECT_NAME)_mimir-data:/dst/mimir \
		-v $(PROJECT_NAME)_grafana-data:/dst/grafana \
		-v "$(CURDIR)/$(file):/backup.tar.gz:ro" \
		alpine tar xzf /backup.tar.gz -C /dst && \
	echo "==> Riavvio i servizi..." && \
	$(COMPOSE) up -d

# ─── Cleanup ─────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	$(COMPOSE) down -v --remove-orphans
