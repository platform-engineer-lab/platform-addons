MGMT_CTX  ?= k3d-management
ARGOCD_NS ?= argocd

.PHONY: help apply diff project

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

project: ## Apply the addons AppProject only
	kubectl --context $(MGMT_CTX) apply -f argocd/project.yaml

apply: project ## Apply all argocd/ manifests (project + appsets + apps)
	kubectl --context $(MGMT_CTX) apply -f argocd/

diff: ## Dry-run diff against the live cluster
	kubectl --context $(MGMT_CTX) diff -f argocd/ || true
