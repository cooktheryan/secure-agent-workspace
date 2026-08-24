# Cloud-init provisioning for three-VM architecture.
# Supports IBM Cirrus and OpenShift CNV (KubeVirt).
#
# Usage:
#   make create-all PLATFORM=cirrus NS=my-namespace
#   make create-all PLATFORM=openshift-cnv NS=my-namespace
#   make verify
#   make delete-all

PLATFORM       ?= cirrus
NS             ?= $(shell oc project -q 2>/dev/null || echo openshell-agents)
SCRIPTS        := scripts

export NS PLATFORM

.PHONY: help secrets secrets-k8s \
        create-all create-infrastructure create-agent create-integration \
        delete-all delete-infrastructure delete-agent delete-integration \
        status verify

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'

##@ Secrets

secrets: ## Generate local secrets (.secrets/)
	@bash $(SCRIPTS)/generate-secrets.sh

secrets-k8s: secrets ## Generate + push to K8s Secrets
	@bash $(SCRIPTS)/push-secrets-k8s.sh

##@ Create

create-all: create-infrastructure create-integration create-agent ## Create all three VMs

create-infrastructure: ## Create infrastructure VM
	@bash $(SCRIPTS)/create-vm.sh $(PLATFORM) infrastructure

create-agent: ## Create agent VM
	@bash $(SCRIPTS)/create-vm.sh $(PLATFORM) agent

create-integration: ## Create integration VM
	@bash $(SCRIPTS)/create-vm.sh $(PLATFORM) integration

##@ Delete

delete-all: delete-agent delete-integration delete-infrastructure ## Delete all three VMs

delete-infrastructure: ## Delete infrastructure VM
	@bash $(SCRIPTS)/delete-vm.sh infrastructure

delete-agent: ## Delete agent VM
	@bash $(SCRIPTS)/delete-vm.sh agent

delete-integration: ## Delete integration VM
	@bash $(SCRIPTS)/delete-vm.sh integration

##@ Status

status: ## Show VM status
	@echo "=== VMs in $(NS) ==="
	@kubectl get vmi -n $(NS) 2>/dev/null || echo "No running VMIs"

verify: ## Verify all VMs are running
	@bash $(SCRIPTS)/verify-vms.sh
