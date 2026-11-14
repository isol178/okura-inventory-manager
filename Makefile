.DEFAULT_GOAL := help
.PHONY: help setup sync lint fmt typecheck test cov audit build check clean

help: ## このヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

setup: sync ## 初回セットアップ（依存のインストールと git フックの登録）
	uv run pre-commit install

sync: ## 依存を uv.lock どおりにインストール
	uv sync

lint: ## lint と format のチェック（修正はしない）
	uv run ruff check
	uv run ruff format --check

fmt: ## 自動修正と整形
	uv run ruff check --fix
	uv run ruff format

typecheck: ## mypy（strict）で型チェック
	uv run mypy

test: ## テストを実行
	uv run pytest

cov: ## カバレッジ付きでテスト
	uv run pytest --cov --cov-report=term --cov-report=html

audit: ## 依存パッケージの既知の脆弱性を検査
	uv audit --preview-features audit-command

build: ## sdist と wheel をビルド
	uv build

check: ## CI と同じチェックを一通り実行
	uv lock --check
	uv run pre-commit run --all-files
	uv run pytest --cov

clean: ## 生成物を削除
	rm -rf dist build htmlcov .coverage coverage.xml .pytest_cache .mypy_cache .ruff_cache
