PREFIX?=$(shell pwd)

NAME := crusoe-csi-driver
PKG := github.com/crusoecloud/crusoe-csi-driver/cmd/$(NAME)
CHART_DIR = ./charts
DEFAULT_BRANCH = release

.PHONY: dev
dev: build-deps lint ## Runs a build-deps, test, lint

.PHONY: ci
ci:  lint-ci ## Runs test, build-deps, lint

.PHONY: build-deps
build-deps: ## Install build dependencies
	@echo "==> $@"
	@brew install helm

.PHONY: lint
precommit: ## runs various formatters that will be checked by linter (but can/should be automatic in your editor)
	@echo "==> $@"

.PHONY: lint
lint:
	@echo "==> $@"
	@for f in $(shell ls ${CHART_DIR}); do helm lint ${CHART_DIR}/$${f}; done

.PHONY: lint-ci
lint-ci: ## Verifies `golangci-lint` passes and outputs in CI-friendly format
	@echo "==> $@"
	@for f in $(shell ls ${CHART_DIR}); do helm lint ${CHART_DIR}/$${f}; done
.PHONY: test-render
test-render: ## Assert the chart renders correctly across the StorageClass cases
	@echo "==> $@"
	@hack/test-storageclass-render.sh

.PHONY: test-upgrade
test-upgrade: ## Assert upgrade behaviour against a running cluster (kind is enough)
	@echo "==> $@"
	@hack/test-upgrade.sh

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
