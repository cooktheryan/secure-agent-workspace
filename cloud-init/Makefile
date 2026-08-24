# Cloud-init provisioning for three-VM architecture.
# Supports IBM Cirrus and OpenShift CNV (KubeVirt).
#
# Usage:
#   make create-all PLATFORM=cirrus NS=my-namespace
#   make create-all PLATFORM=openshift-cnv NS=my-namespace
#   make verify
#   make delete-all

PLATFORM             ?= cirrus
NS                   ?= $(shell oc project -q 2>/dev/null || echo openshell-agents)
BRANCH               ?= main
SSH_PUBKEY           ?=
CONTAINER_DISK_IMAGE ?= registry.cirrus.ibm.com/mici-golden-images/cirrus-rhel-9-golden-image:latest
GOLDEN_IMAGE_PVC     ?= openshell-gateway-podman-golden
SECRETS_DIR          ?= .secrets
SCRIPTS              := scripts

export NS PLATFORM BRANCH SSH_PUBKEY CONTAINER_DISK_IMAGE GOLDEN_IMAGE_PVC SECRETS_DIR

.PHONY: help secrets secrets-k8s \
        create-all create-infrastructure create-agent create-integration \
        delete-all delete-infrastructure delete-agent delete-integration \
        status verify

help: ## Show this help
	@echo ""
	@echo "SAW Cloud-Init Provisioning"
	@echo "==========================="
	@echo ""
	@echo "Variables:"
	@printf "  \033[33m%-25s\033[0m %s [%s]\n" \
		"PLATFORM" "Target platform: cirrus | openshift-cnv" "$(PLATFORM)" \
		"NS" "Kubernetes namespace" "$(NS)" \
		"BRANCH" "Git branch for cloud-init bootstrap" "$(BRANCH)" \
		"SSH_PUBKEY" "SSH public key for VM access (openshift-cnv)" "$(if $(SSH_PUBKEY),set,unset)" \
		"CONTAINER_DISK_IMAGE" "Base VM image (cirrus)" "$(CONTAINER_DISK_IMAGE)" \
		"GOLDEN_IMAGE_PVC" "Golden image PVC name (openshift-cnv)" "$(GOLDEN_IMAGE_PVC)" \
		"SECRETS_DIR" "Local secrets directory" "$(SECRETS_DIR)"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+[a-zA-Z0-9_-]*:.*## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make create-all PLATFORM=cirrus NS=rh-vm-test1"
	@echo "  make create-all PLATFORM=openshift-cnv NS=openshell-agents SSH_PUBKEY=\"ssh-ed25519 ...\""
	@echo "  make secrets-k8s NS=openshell-agents"
	@echo "  make verify"
	@echo "  make delete-all"

##@ Secrets

secrets: ## Generate local secrets: inter-vm-bearer, gmail/m365/slack-write-frontdoor (.secrets/)
	@bash $(SCRIPTS)/generate-secrets.sh

secrets-k8s: secrets ## Push secrets to K8s: inter-vm-bearer, gmail/m365/slack-write-frontdoor
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
