SHELL := /bin/bash
TF := terraform -chdir=terraform
KUBECONFIG := $(CURDIR)/.kube/config
ANSIBLE_INVENTORY := $(CURDIR)/ansible/inventory.ini

.PHONY: help prereqs infra inventory ping cluster deploy verify break recover \
        destroy ips ssh-control nodes pods evidence clean

help:
	@printf "\nKUBERNETES FIELD LAB\n\n"
	@printf "  make prereqs      check local tooling\n"
	@printf "  make infra        terraform init + apply\n"
	@printf "  make inventory    generate Ansible inventory from Terraform\n"
	@printf "  make ping         test Ansible connectivity\n"
	@printf "  make cluster      configure hosts + bootstrap Kubernetes\n"
	@printf "  make deploy       deploy demo workload\n"
	@printf "  make verify       verify cluster and write evidence/\n"
	@printf "  make break        stop kubelet on worker-01\n"
	@printf "  make recover      restart kubelet on worker-01\n"
	@printf "  make nodes        kubectl get nodes -o wide\n"
	@printf "  make pods         kubectl get pods -A -o wide\n"
	@printf "  make ips          show Terraform server IPs\n"
	@printf "  make ssh-control  SSH to control-01\n"
	@printf "  make destroy      destroy all cloud infrastructure\n\n"

prereqs:
	@command -v terraform >/dev/null || (echo "missing: terraform"; exit 1)
	@command -v ansible-playbook >/dev/null || (echo "missing: ansible-playbook"; exit 1)
	@command -v kubectl >/dev/null || (echo "missing: kubectl"; exit 1)
	@command -v ssh >/dev/null || (echo "missing: ssh"; exit 1)
	@command -v jq >/dev/null || (echo "missing: jq"; exit 1)
	@test -n "$$HCLOUD_TOKEN" || (echo "missing: HCLOUD_TOKEN"; exit 1)
	@test -n "$$TF_VAR_admin_cidr" || (echo "missing: TF_VAR_admin_cidr (example: 203.0.113.4/32)"; exit 1)
	@test -f "$${SSH_PUBLIC_KEY_PATH:-$$HOME/.ssh/id_ed25519.pub}" || (echo "missing SSH public key"; exit 1)
	@ansible-galaxy collection install -r ansible/requirements.yml >/dev/null
	@echo "prereqs: OK"

infra: prereqs
	$(TF) init
	$(TF) apply

inventory:
	@mkdir -p ansible
	@$(TF) output -raw ansible_inventory > $(ANSIBLE_INVENTORY)
	@chmod 600 $(ANSIBLE_INVENTORY)
	@echo "wrote $(ANSIBLE_INVENTORY)"
	@cat $(ANSIBLE_INVENTORY)
	@echo
	@echo "enrolling SSH host keys..."
	@for ip in $$($(TF) output -json server_ips | jq -r '.[] | .public'); do \
		ssh-keygen -R "$$ip" >/dev/null 2>&1 || true; \
		ssh-keyscan -H "$$ip" >> "$$HOME/.ssh/known_hosts" 2>/dev/null; \
	done

ping:
	ansible all -i $(ANSIBLE_INVENTORY) -m ping

cluster:
	@mkdir -p .kube
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/site.yml
	@echo
	@echo "Kubeconfig: $(KUBECONFIG)"
	@KUBECONFIG=$(KUBECONFIG) kubectl get nodes -o wide

deploy:
	KUBECONFIG=$(KUBECONFIG) kubectl apply -f manifests/namespace.yml
	KUBECONFIG=$(KUBECONFIG) kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/field-lab --timeout=30s
	KUBECONFIG=$(KUBECONFIG) kubectl apply -f manifests/configmap.yml
	KUBECONFIG=$(KUBECONFIG) kubectl apply -f manifests/service.yml
	KUBECONFIG=$(KUBECONFIG) kubectl apply -f manifests/deployment.yml
	KUBECONFIG=$(KUBECONFIG) kubectl -n field-lab rollout status deployment/field-app --timeout=180s

verify:
	KUBECONFIG=$(KUBECONFIG) ./scripts/verify.sh

break:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/failure.yml

recover:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/recover.yml

nodes:
	KUBECONFIG=$(KUBECONFIG) kubectl get nodes -o wide

pods:
	KUBECONFIG=$(KUBECONFIG) kubectl get pods -A -o wide

ips:
	$(TF) output server_ips

ssh-control:
	@IP="$$( $(TF) output -raw control_public_ip )"; \
	ssh -i "$${SSH_PRIVATE_KEY_PATH:-$$HOME/.ssh/id_ed25519}" root@"$$IP"

evidence: verify

destroy:
	$(TF) destroy

clean:
	rm -rf .kube evidence/*
