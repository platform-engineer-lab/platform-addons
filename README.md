# platform-addons

GitOps addon manifests for the [platform-control-plane](https://github.com/platform-engineer-lab/platform-control-plane) lab. Argo CD on the management cluster watches this repository and reconciles the addon stack across spoke clusters.

## Addons

| Addon | Target | Chart / Source |
|---|---|---|
| Argo Workflows | dev, prod spokes | `argo/argo-workflows` v1.0.16 |
| Argo Events | dev, prod spokes | `argo/argo-events` v2.4.22 |
| GitOps Promoter | management cluster | kustomize `config/default` @ v0.32.0 |

## How it works

```
platform-control-plane/gitops/addons-bootstrap.yaml   (App-of-Apps)
  └── watches platform-addons/argocd/
        ├── project.yaml              AppProject "addons"
        ├── appset-argo-workflows.yaml   ApplicationSet → dev + prod
        ├── appset-argo-events.yaml      ApplicationSet → dev + prod
        └── app-gitops-promoter.yaml     Application  → management
```

Each ApplicationSet uses [multi-source](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/) to pull the Helm chart from the upstream repo and values from this repo:

```
sources:
  - chart: argo-workflows          # upstream Helm chart
    valueFiles:
      - $values/addons/argo-workflows/values-base.yaml
      - $values/addons/argo-workflows/values-{{name}}.yaml
  - ref: values                    # this repo as the values source
```

## Repository layout

```
argocd/
  project.yaml                 AppProject "addons"
  appset-argo-workflows.yaml   ApplicationSet — fans to dev/prod
  appset-argo-events.yaml      ApplicationSet — fans to dev/prod
  app-gitops-promoter.yaml     Application — management cluster

addons/
  argo-workflows/
    values-base.yaml           shared defaults
    values-dev.yaml            dev overrides
    values-prod.yaml           prod overrides
  argo-events/
    values-base.yaml
    values-dev.yaml
    values-prod.yaml
```

## Bootstrapping

The `platform-control-plane` repo contains `gitops/addons-bootstrap.yaml` — an Argo CD Application that points at this repo's `argocd/` directory. Apply it once after `make up`:

```bash
# from platform-control-plane/
kubectl --context k3d-management apply -f gitops/addons-bootstrap.yaml
```

Argo CD will then self-manage everything in `argocd/`.

### Manual apply (without bootstrap app)

```bash
# from platform-addons/
make apply
```

## Customising per-environment values

Edit `addons/<addon>/values-<env>.yaml` and push. Argo CD will detect the change and reconcile within ~3 minutes (default polling interval).

## Adding a new addon

1. Add a new ApplicationSet (or Application) under `argocd/`.
2. Add `addons/<new-addon>/values-base.yaml` and environment overrides.
3. Add the chart's `repoURL` to `argocd/project.yaml` `sourceRepos`.
4. Push — the bootstrap app reconciles automatically.
