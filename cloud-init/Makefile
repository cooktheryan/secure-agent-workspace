# Cloud-init provisioning for three-VM architecture.
# All logic lives in Ansible playbooks — this Makefile is a convenience wrapper.
#
# Usage:
#   make create-all PLATFORM=cirrus NS=my-namespace
#   make delete-all
#   make verify

PLATFORM             ?= cirrus
NS                   ?= $(shell oc project -q 2>/dev/null || echo openshell-agents)
BRANCH               ?= main
SSH_PUBKEY           ?=
CONTAINER_DISK_IMAGE ?= registry.cirrus.ibm.com/mici-golden-images/cirrus-rhel-9-golden-image:latest
GOLDEN_IMAGE_PVC     ?= openshell-gateway-podman-golden
ANSIBLE_DIR          := ansible

export NS PLATFORM BRANCH SSH_PUBKEY CONTAINER_DISK_IMAGE GOLDEN_IMAGE_PVC

.PHONY: help create-all delete-all verify status

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
		"SSH_PUBKEY" "SSH public key (openshift-cnv)" "$(if $(SSH_PUBKEY),set,unset)" \
		"CONTAINER_DISK_IMAGE" "Base VM image (cirrus)" "$(CONTAINER_DISK_IMAGE)" \
		"GOLDEN_IMAGE_PVC" "Golden image PVC (openshift-cnv)" "$(GOLDEN_IMAGE_PVC)"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+[a-zA-Z0-9_-]*:.*## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make create-all PLATFORM=cirrus NS=rh-vm-test1"
	@echo "  make create-all PLATFORM=openshift-cnv NS=openshell-agents SSH_PUBKEY=\"ssh-ed25519 ...\""
	@echo "  make delete-all NS=rh-vm-test1"
	@echo "  make verify"

create-all: ## Create secrets + all three VMs (infrastructure, integration, agent)
	@ansible-playbook $(ANSIBLE_DIR)/provision.yml \
		-e platform=$(PLATFORM) \
		-e ns=$(NS) \
		-e branch=$(BRANCH) \
		-e ssh_pubkey="$(SSH_PUBKEY)" \
		-e container_disk_image="$(CONTAINER_DISK_IMAGE)" \
		-e golden_image_pvc="$(GOLDEN_IMAGE_PVC)"

delete-all: ## Delete all three VMs + K8s Secrets
	@ansible-playbook $(ANSIBLE_DIR)/provision.yml \
		-e platform=$(PLATFORM) \
		-e ns=$(NS) \
		-e action=delete

verify: ## Verify all VMs are running
	@bash scripts/verify-vms.sh

status: ## Show VM status
	@echo "=== VMs in $(NS) ==="
	@kubectl get vmi -n $(NS) 2>/dev/null || echo "No running VMIs"
