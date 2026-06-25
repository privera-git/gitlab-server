.PHONY: install up down logs password open

install: ## Copia .env.example a .env si no existe
	@test -f .env || (cp .env.example .env && echo ".env creado desde .env.example — ajusta los valores antes de ejecutar 'make up'")

up: ## Levanta GitLab en segundo plano
	docker compose up -d

down: ## Detiene y elimina los contenedores (los datos persisten en GITLAB_HOME)
	docker compose down

logs: ## Muestra los logs en tiempo real
	docker compose logs -f gitlab

password: ## Muestra la contraseña inicial del usuario root (válida solo 24 hs tras el primer arranque)
	docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password

open: ## Abre GitLab en el navegador
	@source .env 2>/dev/null; open "$${GITLAB_EXTERNAL_URL:-http://localhost:8929}"
