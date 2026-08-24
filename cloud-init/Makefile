# Cloud-init provisioning for two-VM + infra architecture.
# Supports IBM Cirrus and OpenShift CNV (KubeVirt).
#
# Usage:
#   make create-all PLATFORM=cirrus NS=my-namespace
#   make create-all PLATFORM=openshift-cnv NS=my-namespace SSH_PUBKEY="ssh-ed25519 ..."
#   make verify
#   make delete-all

PLATFORM       ?= cirrus
NS             ?= $(shell oc project -q 2>/dev/null || echo openshell-agents)
BRANCH         ?= main
SSH_PUBKEY     ?=
GOLDEN_IMAGE_PVC ?= openshell-gateway-podman-golden
CONTAINER_DISK_IMAGE ?= registry.cirrus.ibm.com/mici-golden-images/cirrus-rhel-9-golden-image:latest

KUBE_DIR       := kubernetes/$(PLATFORM)
ANSIBLE_DIR    := ansible
SECRETS_DIR    := .secrets

.PHONY: check-platform check-ns create-all create-infrastructure create-agent create-integration \
        delete-all delete-infrastructure delete-agent delete-integration \
        status verify secrets help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'

check-platform:
	@test -d "$(KUBE_DIR)" || { \
		echo "Error: Platform '$(PLATFORM)' not found. Use: cirrus or openshift-cnv"; \
		exit 1; \
	}

check-ns:
	@test -n "$(NS)" || { echo "Error: NS is required."; exit 1; }
	@oc whoami >/dev/null 2>&1 || { echo "Error: Not logged in. Run 'oc login' first."; exit 1; }

##@ Secrets

secrets: ## Generate local secrets for provisioning (inter-VM bearer, front-door tokens)
	@install -d -m 0700 "$(SECRETS_DIR)"
	@if [ ! -f "$(SECRETS_DIR)/inter-vm-bearer" ]; then \
		openssl rand -hex 32 > "$(SECRETS_DIR)/inter-vm-bearer"; \
		echo "Generated inter-vm-bearer"; \
	else echo "inter-vm-bearer exists"; fi
	@if [ ! -f "$(SECRETS_DIR)/gmail-write-frontdoor" ]; then \
		openssl rand -hex 32 > "$(SECRETS_DIR)/gmail-write-frontdoor"; \
		echo "Generated gmail-write-frontdoor"; \
	else echo "gmail-write-frontdoor exists"; fi
	@if [ ! -f "$(SECRETS_DIR)/m365-write-frontdoor" ]; then \
		openssl rand -hex 32 > "$(SECRETS_DIR)/m365-write-frontdoor"; \
		echo "Generated m365-write-frontdoor"; \
	else echo "m365-write-frontdoor exists"; fi
	@if [ ! -f "$(SECRETS_DIR)/slack-write-frontdoor" ]; then \
		openssl rand -hex 32 > "$(SECRETS_DIR)/slack-write-frontdoor"; \
		echo "Generated slack-write-frontdoor"; \
	else echo "slack-write-frontdoor exists"; fi
	@chmod 600 "$(SECRETS_DIR)"/*
	@echo "Secrets stored in $(SECRETS_DIR)/"

secrets-k8s: check-ns secrets ## Generate secrets locally AND create K8s Secrets in namespace
	@echo "Creating K8s Secrets in $(NS)..."
	@BEARER=$$(cat "$(SECRETS_DIR)/inter-vm-bearer"); \
	BEARER_SHA=$$(echo -n "$$BEARER" | sha256sum | cut -d ' ' -f 1); \
	oc create secret generic inter-vm-bearer -n "$(NS)" \
		--from-literal=bearer="$$BEARER" \
		--from-literal=sha256="$$BEARER_SHA" \
		--dry-run=client -o yaml | oc apply -f -
	@oc create secret generic gmail-write-frontdoor -n "$(NS)" \
		--from-file=bearer="$(SECRETS_DIR)/gmail-write-frontdoor" \
		--dry-run=client -o yaml | oc apply -f -
	@oc create secret generic m365-write-frontdoor -n "$(NS)" \
		--from-file=bearer="$(SECRETS_DIR)/m365-write-frontdoor" \
		--dry-run=client -o yaml | oc apply -f -
	@oc create secret generic slack-write-frontdoor -n "$(NS)" \
		--from-file=bearer="$(SECRETS_DIR)/slack-write-frontdoor" \
		--dry-run=client -o yaml | oc apply -f -
	@echo "K8s Secrets created in $(NS)"

##@ Create

create-all: check-platform check-ns create-infrastructure create-integration create-agent ## Create all three VMs
	@echo ""
	@echo "All VMs created in namespace $(NS) (platform: $(PLATFORM))"
	@echo "  saw-infrastructure  — provisioner (SSH + Ansible)"
	@echo "  saw-integration     — proxy services"
	@echo "  saw-agent           — OpenClaw agent"

create-infrastructure: check-platform check-ns ## Create infrastructure VM
	@echo "Creating saw-infrastructure in $(NS) ($(PLATFORM))..."
	@sed -e "s|\$${NS}|$(NS)|g" \
		-e "s|\$${BRANCH}|$(BRANCH)|g" \
		-e "s|\$${CONTAINER_DISK_IMAGE}|$(CONTAINER_DISK_IMAGE)|g" \
		-e "s|\$${SSH_PUBKEY}|$(SSH_PUBKEY)|g" \
		-e "s|\$${GOLDEN_IMAGE_PVC}|$(GOLDEN_IMAGE_PVC)|g" \
		"$(KUBE_DIR)/infrastructure-server.yml" | oc apply -n "$(NS)" -f -

create-agent: check-platform check-ns ## Create agent VM
	@echo "Creating saw-agent in $(NS) ($(PLATFORM))..."
	@sed -e "s|\$${NS}|$(NS)|g" \
		-e "s|\$${BRANCH}|$(BRANCH)|g" \
		-e "s|\$${CONTAINER_DISK_IMAGE}|$(CONTAINER_DISK_IMAGE)|g" \
		-e "s|\$${SSH_PUBKEY}|$(SSH_PUBKEY)|g" \
		-e "s|\$${GOLDEN_IMAGE_PVC}|$(GOLDEN_IMAGE_PVC)|g" \
		"$(KUBE_DIR)/agent-server.yml" | oc apply -n "$(NS)" -f -

create-integration: check-platform check-ns ## Create integration VM
	@echo "Creating saw-integration in $(NS) ($(PLATFORM))..."
	@sed -e "s|\$${NS}|$(NS)|g" \
		-e "s|\$${BRANCH}|$(BRANCH)|g" \
		-e "s|\$${CONTAINER_DISK_IMAGE}|$(CONTAINER_DISK_IMAGE)|g" \
		-e "s|\$${SSH_PUBKEY}|$(SSH_PUBKEY)|g" \
		-e "s|\$${GOLDEN_IMAGE_PVC}|$(GOLDEN_IMAGE_PVC)|g" \
		"$(KUBE_DIR)/integration-server.yml" | oc apply -n "$(NS)" -f -

##@ Delete

delete-all: check-ns delete-agent delete-integration delete-infrastructure ## Delete all three VMs
	@echo "All VMs deleted from $(NS)"

delete-infrastructure: check-ns ## Delete infrastructure VM
	@echo "Deleting saw-infrastructure..."
	-@oc delete -n "$(NS)" -f "$(KUBE_DIR)/infrastructure-server.yml" --ignore-not-found 2>/dev/null || \
		kubectl delete vm saw-infrastructure -n "$(NS)" --ignore-not-found 2>/dev/null || true

delete-agent: check-ns ## Delete agent VM
	@echo "Deleting saw-agent..."
	-@oc delete -n "$(NS)" -f "$(KUBE_DIR)/agent-server.yml" --ignore-not-found 2>/dev/null || \
		kubectl delete vm saw-agent -n "$(NS)" --ignore-not-found 2>/dev/null || true

delete-integration: check-ns ## Delete integration VM
	@echo "Deleting saw-integration..."
	-@oc delete -n "$(NS)" -f "$(KUBE_DIR)/integration-server.yml" --ignore-not-found 2>/dev/null || \
		kubectl delete vm saw-integration -n "$(NS)" --ignore-not-found 2>/dev/null || true

##@ Status & Verify

status: check-ns ## Show status of all VMs
	@echo "=== VMs in $(NS) ==="
	@if [ "$(PLATFORM)" = "cirrus" ]; then \
		oc get servers -n "$(NS)" 2>/dev/null || echo "No Cirrus Servers found"; \
	else \
		kubectl get vm -n "$(NS)" 2>/dev/null || echo "No VMs found"; \
	fi
	@echo ""
	@echo "=== VMIs ==="
	@kubectl get vmi -n "$(NS)" 2>/dev/null || echo "No running VMIs"

verify: check-ns ## Verify all VMs are running and accessible
	@echo "============================================================"
	@echo "Verifying SAW VMs in $(NS)"
	@echo "============================================================"
	@PASS=0; FAIL=0; \
	for vm in saw-infrastructure saw-agent saw-integration; do \
		phase=$$(kubectl get vmi "$$vm" -n "$(NS)" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound"); \
		if [ "$$phase" = "Running" ]; then \
			echo "  PASS  $$vm is Running"; \
			PASS=$$((PASS + 1)); \
		else \
			echo "  FAIL  $$vm is $$phase"; \
			FAIL=$$((FAIL + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "Results: $$PASS passed, $$FAIL failed"; \
	test "$$FAIL" -eq 0

##@ Provision (from infra VM)

provision: ## Run Ansible provisioning from infrastructure VM (SSH into infra, run playbooks)
	@echo "SSH into saw-infrastructure and run:"
	@echo "  cd /opt/secure-agent-workspace/cloud-init/ansible"
	@echo "  ansible-playbook site.yml -i inventory.ini -e @/etc/openshell-saw/vars.yml"
	@echo ""
	@echo "Or from your workstation:"
	@echo "  virtctl -n $(NS) ssh openshell@vm/saw-infrastructure"
