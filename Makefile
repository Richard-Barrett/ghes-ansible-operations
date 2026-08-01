SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

PYTHON ?= python3
VENV ?= .venv
PIP := $(VENV)/bin/pip
ANSIBLE_PLAYBOOK := $(VENV)/bin/ansible-playbook
ANSIBLE_GALAXY := $(VENV)/bin/ansible-galaxy
ANSIBLE_LINT := $(VENV)/bin/ansible-lint
PRE_COMMIT := $(VENV)/bin/pre-commit

ENV ?= staging
INVENTORY ?= inventory/$(ENV)/hosts.yml
LIMIT ?=
EXTRA_VARS ?=
UPGRADE_VARS ?= vars/upgrade.yml

LIMIT_ARG := $(if $(LIMIT),--limit $(LIMIT),)
EXTRA_VARS_ARG := $(if $(EXTRA_VARS),--extra-vars "$(EXTRA_VARS)",)
UPGRADE_VARS_ARG := $(if $(wildcard $(UPGRADE_VARS)),--extra-vars @$(UPGRADE_VARS),)

.PHONY: help setup install requirements hooks lint syntax validate connectivity health service-status restart-core-services upgrade-standalone upgrade-ha-primary clean

help: ## Show available targets and common variables
	@printf '\nGHES Ansible Operations\n\n'
	@printf 'Usage: make <target> [ENV=staging|production] [LIMIT=host] [EXTRA_VARS="..."]\n\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-28s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\nExamples:\n'
	@printf '  make setup\n'
	@printf '  make connectivity ENV=staging LIMIT=ghes-staging\n'
	@printf '  make upgrade-standalone ENV=staging LIMIT=ghes-staging\n'
	@printf '  make upgrade-ha-primary ENV=production LIMIT=ghes-primary\n\n'

$(VENV)/bin/activate:
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip

setup: $(VENV)/bin/activate ## Create the virtual environment and install dependencies
	$(PIP) install -r requirements-dev.txt
	$(MAKE) requirements

install: setup ## Alias for setup

requirements: $(VENV)/bin/activate ## Install the Galaxy role into the repository-local roles path
	$(ANSIBLE_GALAXY) role install -r requirements.yml -p .ansible/roles --force

hooks: setup ## Install Git pre-commit and pre-push hooks
	$(PRE_COMMIT) install
	$(PRE_COMMIT) install --hook-type pre-push

lint: setup ## Run YAML and Ansible linting
	$(PRE_COMMIT) run --all-files
	$(ANSIBLE_LINT) playbooks inventory

syntax: setup ## Run playbook syntax checks
	@for playbook in playbooks/*.yml; do \
	  echo "Checking $$playbook"; \
	  $(ANSIBLE_PLAYBOOK) -i $(INVENTORY) --syntax-check "$$playbook"; \
	done

validate: lint syntax ## Run all static validation

connectivity: setup ## Verify SSH access and the GHES administrative CLI
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/connectivity.yml $(LIMIT_ARG)

health: setup ## Run read-only GHES health checks
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/health.yml $(LIMIT_ARG)

service-status: setup ## Display GHES service status
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/service-status.yml $(LIMIT_ARG)

restart-core-services: setup ## Guardedly reload GHES core services on one appliance
	@test -n "$(LIMIT)" || (echo "LIMIT is required"; exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/restart-core-services.yml \
	  $(LIMIT_ARG) --extra-vars ghes_service_restart_confirm=true $(EXTRA_VARS_ARG)

upgrade-standalone: setup ## Upgrade one standalone GHES appliance
	@test -n "$(LIMIT)" || (echo "LIMIT is required"; exit 2)
	@test -f "$(UPGRADE_VARS)" || (echo "Create $(UPGRADE_VARS) from vars/upgrade.example.yml"; exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/upgrade-standalone.yml \
	  $(LIMIT_ARG) $(UPGRADE_VARS_ARG) $(EXTRA_VARS_ARG)

upgrade-ha-primary: setup ## Upgrade one HA primary; does not sequence replicas
	@test -n "$(LIMIT)" || (echo "LIMIT is required"; exit 2)
	@test -f "$(UPGRADE_VARS)" || (echo "Create $(UPGRADE_VARS) from vars/upgrade.example.yml"; exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/upgrade-ha-primary.yml \
	  $(LIMIT_ARG) $(UPGRADE_VARS_ARG) $(EXTRA_VARS_ARG)

clean: ## Remove local Python and Ansible artifacts
	rm -rf $(VENV) .ansible .cache .pytest_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type f -name '*.retry' -delete
