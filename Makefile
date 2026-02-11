.PHONY: up down reset logs migrate shell test

up:
	docker compose up --build

down:
	docker compose down

reset:
	docker compose down -v --remove-orphans

logs:
	docker compose logs -f

migrate:
	docker compose exec api alembic upgrade head

shell:
	docker compose exec api /bin/sh

test:
	python -m pytest
