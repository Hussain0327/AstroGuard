.PHONY: help install dev test lint format clean docker-up docker-down dbt-run dbt-test prefect-start pipeline

help:
	@echo "Available commands:"
	@echo "  install        Install dependencies"
	@echo "  dev            Start development server"
	@echo "  test           Run tests"
	@echo "  docker-up      Start all services"
	@echo "  docker-down    Stop all services"
	@echo "  dbt-run        Run dbt models"
	@echo "  dbt-test       Run dbt tests"
	@echo "  prefect-start  Start Prefect server"
	@echo "  pipeline       Run the daily metrics pipeline"

install:
	pip3 install -r requirements.txt
	cd dbt && python3 -m dbt deps

dev:
	python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test:
	python3 -m pytest tests/ -v --cov=app --cov-report=term-missing

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f

dbt-deps:
	cd dbt && python3 -m dbt deps

dbt-run:
	cd dbt && python3 -m dbt run

dbt-test:
	cd dbt && python3 -m dbt test

dbt-build:
	cd dbt && python3 -m dbt build

dbt-docs:
	cd dbt && python3 -m dbt docs generate && python3 -m dbt docs serve

prefect-start:
	python3 -m prefect server start

prefect-worker:
	python3 -m prefect worker start -p default-pool

pipeline:
	python3 -m orchestration.flows.daily_metrics

pipeline-ingest:
	python3 -m orchestration.flows.data_ingestion

pipeline-experiment:
	python3 -m orchestration.flows.experiment_analysis

gx-docs:
	cd data_quality && python3 -m great_expectations docs build

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	rm -rf dbt/target dbt/dbt_packages dbt/logs
