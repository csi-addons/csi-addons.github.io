# CSI-Addons Website Generator
#
# Generates the website content from the csi-addons/spec and
# csi-addons/kubernetes-csi-addons repositories.
#
# Usage:
#   make generate       - Clone repos (if needed) and generate the site
#   make sync-repos     - Clone or update the source repositories
#   make update         - Pull latest changes and regenerate
#   make clean          - Remove cloned repositories
#   make serve          - Start a local HTTP server for preview
#
# To use local repo checkouts instead of cloning:
#   make generate SPEC_DIR=/path/to/spec K8S_DIR=/path/to/kubernetes-csi-addons

SHELL := /bin/bash

# Repository URLs
SPEC_REPO := https://github.com/csi-addons/spec.git
K8S_REPO  := https://github.com/csi-addons/kubernetes-csi-addons.git

# Local clone directories
REPOS_DIR := _repos
SPEC_DIR  ?= $(REPOS_DIR)/spec
K8S_DIR   ?= $(REPOS_DIR)/kubernetes-csi-addons

# Scripts
GENERATE_SCRIPT := scripts/generate-site.sh

# Default target
.DEFAULT_GOAL := generate

.PHONY: generate sync-repos update clean serve help

## generate: Clone repos (if needed) and generate the website
generate: sync-repos
	@$(GENERATE_SCRIPT) "$(SPEC_DIR)" "$(K8S_DIR)"

## sync-repos: Clone or update the spec and kubernetes-csi-addons repositories
sync-repos: $(SPEC_DIR) $(K8S_DIR)

$(SPEC_DIR):
	@echo "Cloning spec repository..."
	@mkdir -p $(REPOS_DIR)
	git clone --depth 1 $(SPEC_REPO) $(SPEC_DIR)

$(K8S_DIR):
	@echo "Cloning kubernetes-csi-addons repository..."
	@mkdir -p $(REPOS_DIR)
	git clone --depth 1 $(K8S_REPO) $(K8S_DIR)

## update: Pull latest changes from both repos and regenerate
update:
	@if [ -d "$(SPEC_DIR)/.git" ]; then \
		echo "Updating spec repository..."; \
		git -C "$(SPEC_DIR)" pull --ff-only; \
	else \
		echo "Cloning spec repository..."; \
		mkdir -p $(REPOS_DIR); \
		git clone --depth 1 $(SPEC_REPO) $(SPEC_DIR); \
	fi
	@if [ -d "$(K8S_DIR)/.git" ]; then \
		echo "Updating kubernetes-csi-addons repository..."; \
		git -C "$(K8S_DIR)" fetch --tags --force; \
		git -C "$(K8S_DIR)" pull --ff-only; \
	else \
		echo "Cloning kubernetes-csi-addons repository..."; \
		mkdir -p $(REPOS_DIR); \
		git clone $(K8S_REPO) $(K8S_DIR); \
	fi
	@$(GENERATE_SCRIPT) "$(SPEC_DIR)" "$(K8S_DIR)"

## clean: Remove cloned repositories
clean:
	rm -rf $(REPOS_DIR)

## serve: Start a local HTTP server on port 8080 for preview
serve:
	@echo "Serving at http://localhost:8080"
	@python3 -m http.server 8080

## help: Show this help message
help:
	@echo "CSI-Addons Website Generator"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'
	@echo ""
	@echo "Options:"
	@echo "  SPEC_DIR=/path/to/spec                  Use a local spec checkout"
	@echo "  K8S_DIR=/path/to/kubernetes-csi-addons   Use a local k8s-csi-addons checkout"
	@echo ""
	@echo "Examples:"
	@echo "  make generate                            Clone repos and generate site"
	@echo "  make update                              Pull latest and regenerate"
	@echo "  make generate SPEC_DIR=../spec K8S_DIR=../kubernetes-csi-addons"
	@echo "  make serve                               Preview at localhost:8080"
