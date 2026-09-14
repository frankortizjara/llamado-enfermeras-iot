.DEFAULT_GOAL := help
SHELL := /bin/bash

COMPOSE := docker compose
DB      := enfermeras-postgres
BACKEND := enfermeras-backend
FRONTEND:= enfermeras-frontend
DBNAME  := sistema_enfermeras
DBUSER  := postgres

# =============================================================================
# HELP
# =============================================================================
help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# DESPLIEGUE INICIAL (servidor nuevo)
# =============================================================================
deploy: ## Despliegue completo en un comando (crea .env, construye, levanta y verifica)
	@./deploy.sh

verify: ## Comprueba que BD, backend y frontend responden
	@echo "== Estado de contenedores =="
	@$(COMPOSE) ps
	@echo
	@echo "== Base de datos =="
	@docker exec $(DB) pg_isready -U $(DBUSER) -d $(DBNAME) || echo "  BD NO responde"
	@echo "== Backend =="
	@docker exec $(BACKEND) wget -q --spider http://127.0.0.1:4000/health && echo "  backend OK" || echo "  backend NO responde"
	@echo "== Frontend =="
	@docker exec $(FRONTEND) wget -q --spider http://127.0.0.1/ && echo "  frontend OK" || echo "  frontend NO responde"
	@echo
	@echo "== Migraciones =="
	@docker exec $(DB) psql -U $(DBUSER) -d $(DBNAME) -tAc \
	  "SELECT COUNT(*) || ' migraciones aplicadas' FROM schema_migrations;" 2>/dev/null || echo "  (sin tabla schema_migrations)"

# =============================================================================
# CICLO DE VIDA (levantar/bajar)
# =============================================================================
up: ## Levanta toda la stack (postgres -> migraciones -> mosquitto -> backend -> frontend)
	$(COMPOSE) up -d
	@$(MAKE) --no-print-directory status

up-build: ## Igual que 'up' pero fuerza rebuild de backend/frontend
	$(COMPOSE) up -d --build

down: ## Para la stack (NO borra datos)
	$(COMPOSE) down

restart-backend: ## Reinicia solo el backend (tras cambios en codigo ya compilado)
	$(COMPOSE) restart backend

restart-frontend: ## Reinicia solo el frontend
	$(COMPOSE) restart frontend

status: ## Muestra el estado de los servicios
	@$(COMPOSE) ps

# =============================================================================
# MIGRACIONES DE BD (solo aplica lo nuevo, NO borra datos)
# =============================================================================
migrate: ## Aplica las migraciones pendientes (re-ejecuta el runner)
	$(COMPOSE) run --rm db-migrate

migrate-status: ## Lista migraciones aplicadas vs pendientes
	@echo "== Aplicadas =="
	@docker exec $(DB) psql -U $(DBUSER) -d $(DBNAME) -c \
	  "SELECT filename, applied_at FROM schema_migrations ORDER BY filename;" 2>/dev/null || echo "(tabla schema_migrations no existe todavia)"
	@echo ""
	@echo "== Archivos en database/migrations/ =="
	@ls -1 database/migrations/*.sql 2>/dev/null | xargs -n1 basename

migrate-force: ## CUIDADO: Marca una migracion como aplicada sin ejecutarla (uso: make migrate-force FILE=20_xxx.sql)
	@test -n "$(FILE)" || (echo "Uso: make migrate-force FILE=nombre.sql"; exit 1)
	docker exec $(DB) psql -U $(DBUSER) -d $(DBNAME) -c \
	  "INSERT INTO schema_migrations (filename) VALUES ('$(FILE)') ON CONFLICT DO NOTHING;"

migrate-unmark: ## Borra el registro de una migracion (la proxima vez se re-ejecuta). Uso: make migrate-unmark FILE=20_xxx.sql
	@test -n "$(FILE)" || (echo "Uso: make migrate-unmark FILE=nombre.sql"; exit 1)
	docker exec $(DB) psql -U $(DBUSER) -d $(DBNAME) -c \
	  "DELETE FROM schema_migrations WHERE filename = '$(FILE)';"

# =============================================================================
# CARGA DE DATOS DEL PILOTO (CSV -> BD)
# =============================================================================
# Los CSV de database/seed/ son el export del servidor del piloto.
# REEMPLAZA el contenido de esas tablas y reajusta todas las secuencias.
# Pensado para el PRIMER despliegue en un servidor nuevo.

seed: ## Carga los datos del piloto desde database/seed/*.csv (REEMPLAZA esas tablas)
	@test -d database/seed || (echo "No existe database/seed/"; exit 1)
	@echo "Esto REEMPLAZARA el contenido de las tablas que tienen CSV en database/seed/."
	@echo "Las secuencias se reajustaran automaticamente."
	@read -p "Escribe 'si' para continuar: " ans; \
	  [ "$$ans" = "si" ] || (echo "Cancelado."; exit 1)
	@docker cp database/seed $(DB):/seed
	@docker cp database/seed.sh $(DB):/seed.sh
	docker exec -e PGHOST=127.0.0.1 -e PGPORT=5432 -e PGUSER=$(DBUSER) \
	  -e PGPASSWORD=$$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-) \
	  -e PGDATABASE=$(DBNAME) $(DB) sh /seed.sh
	@echo "Listo. Ejecuta: make restart-backend"

# =============================================================================
# OPERACIONES DE BD
# =============================================================================
psql: ## Abre una consola psql dentro del contenedor de la BD
	docker exec -it $(DB) psql -U $(DBUSER) -d $(DBNAME)

backup: ## Backup completo de la BD a ./backups/backup_YYYY-MM-DD_HHMM.sql
	@mkdir -p backups
	@FILE=backups/backup_$$(date +%Y-%m-%d_%H%M).sql; \
	docker exec $(DB) pg_dump -U $(DBUSER) $(DBNAME) > $$FILE && \
	echo "Backup creado: $$FILE"

restore: ## Restaura un backup, REEMPLAZANDO los datos actuales (uso: make restore FILE=backups/backup_XXX.sql)
	@test -n "$(FILE)" || (echo "Uso: make restore FILE=backups/backup_XXX.sql"; exit 1)
	@test -f "$(FILE)" || (echo "No existe: $(FILE)"; exit 1)
	@echo "Esto BORRARA los datos actuales de '$(DBNAME)' y cargara: $(FILE)"
	@read -p "Escribe 'si' para continuar: " ans; \
	[ "$$ans" = "si" ] || (echo "Cancelado."; exit 1)
	@# El servidor nuevo ya tiene el esquema creado por las migraciones, asi que
	@# hay que vaciarlo antes: sino el dump choca con las tablas ya existentes
	@# ("constraint ... already exists") y no restaura nada.
	docker exec -i $(DB) psql -U $(DBUSER) -d $(DBNAME) -v ON_ERROR_STOP=1 -q \
	  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
	docker exec -i $(DB) psql -U $(DBUSER) -d $(DBNAME) -v ON_ERROR_STOP=1 -q < $(FILE)
	@echo "Restauracion completada. Ejecuta: make restart-backend"

# =============================================================================
# SYNC DE DATOS EsSi (camas_essi) entre maquinas
# =============================================================================
# Uso tipico:
#   LAPTOP (con acceso a API_ESSI):   make essi-export
#   Copias ./exports/camas_essi_*.sql al servidor
#   SERVIDOR (sin API_ESSI):          make essi-import FILE=exports/camas_essi_XXX.sql

essi-export: ## Exporta camas_essi a ./exports/camas_essi_FECHA.sql (ejecutar en la laptop)
	@mkdir -p exports
	@FILE=exports/camas_essi_$$(date +%Y-%m-%d_%H%M).sql; \
	docker exec $(DB) pg_dump -U $(DBUSER) -d $(DBNAME) \
	  --table=camas_essi --data-only --column-inserts > $$FILE && \
	echo "Exportado: $$FILE"
	@echo "Copia ese archivo al servidor y ejecuta: make essi-import FILE=..."

essi-import: ## Importa camas_essi en el servidor (uso: make essi-import FILE=exports/camas_essi_XXX.sql)
	@test -n "$(FILE)" || (echo "Uso: make essi-import FILE=exports/camas_essi_XXX.sql"; exit 1)
	@test -f "$(FILE)" || (echo "No existe: $(FILE)"; exit 1)
	docker exec $(DB) psql -U $(DBUSER) -d $(DBNAME) \
	  -c "TRUNCATE TABLE camas_essi RESTART IDENTITY CASCADE;"
	docker exec -i $(DB) psql -U $(DBUSER) -d $(DBNAME) < $(FILE)
	@docker exec $(DB) psql -U $(DBUSER) -d $(DBNAME) \
	  -c "SELECT COUNT(*) AS filas_en_camas_essi FROM camas_essi;"

# =============================================================================
# LOGS
# =============================================================================
logs: ## Sigue los logs de todos los servicios
	$(COMPOSE) logs -f --tail=100

logs-db: ## Logs solo de postgres
	$(COMPOSE) logs -f --tail=100 postgres

logs-migrate: ## Logs del ultimo run de migraciones
	$(COMPOSE) logs --tail=200 db-migrate

logs-backend: ## Logs solo del backend
	$(COMPOSE) logs -f --tail=100 backend

# =============================================================================
# TRASPASO A OTRO SERVIDOR / SIN INTERNET
# =============================================================================
# Opcion A (recomendada, el servidor NO compila nada):
#   PC con internet:  make release-save     -> ./images/release-*.tar
#   Copias el repo + ./images al servidor
#   Servidor:         make release-load && make up
#
# Opcion B (el servidor compila, pero sin descargar imagenes base):
#   PC con internet:  make images-save      -> imagenes base en ./images/
#   Servidor:         make images-load && make up-build

BASE_IMAGES := postgres:16-alpine eclipse-mosquitto:2 node:20-alpine nginx:alpine
APP_IMAGES  := sistema_llamado_de_enfermeras-backend sistema_llamado_de_enfermeras-frontend sistema_llamado_de_enfermeras-mosquitto

images-save: ## Descarga y exporta las 4 imagenes BASE a ./images/ (para compilar sin internet)
	@mkdir -p images
	@for img in $(BASE_IMAGES); do \
	  echo "Descargando $$img..."; docker pull $$img; \
	done
	docker save $(BASE_IMAGES) -o images/base-images.tar
	@echo "Listo: images/base-images.tar ($$(du -h images/base-images.tar | cut -f1))"

release-save: ## Construye y exporta las imagenes YA CONSTRUIDAS a ./images/ (el servidor no compila)
	@mkdir -p images
	$(COMPOSE) build
	docker pull postgres:16-alpine
	docker save postgres:16-alpine $(APP_IMAGES) -o images/release.tar
	@echo "Listo: images/release.tar ($$(du -h images/release.tar | cut -f1))"
	@echo "Copia al servidor: el repo completo + la carpeta ./images/"

images-load: ## Carga en Docker todos los .tar de ./images/
	@ls images/*.tar >/dev/null 2>&1 || (echo "No hay archivos .tar en ./images/"; exit 1)
	@for f in images/*.tar; do echo "Cargando $$f..."; docker load -i $$f; done

release-load: images-load ## Alias de images-load (carga el release.tar en el servidor)

# =============================================================================
# PELIGRO (confirmacion requerida)
# =============================================================================
reset-db: ## !!! BORRA TODA LA BD y la vuelve a crear desde cero (pide confirmacion)
	@read -p "Esto BORRARA todos los datos. Escribe 'si' para continuar: " ans; \
	[ "$$ans" = "si" ] || (echo "Cancelado."; exit 1)
	$(COMPOSE) down -v
	$(COMPOSE) up -d --build

.PHONY: help deploy verify up up-build down restart-backend restart-frontend status seed \
        migrate migrate-status migrate-force migrate-unmark \
        psql backup restore logs logs-db logs-migrate logs-backend \
        images-save images-load release-save release-load reset-db \
        essi-export essi-import
