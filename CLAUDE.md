# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Delivery pipeline

```mermaid
flowchart LR
    subgraph github["GitHub"]
        SRC["sample-service\nsource + Dockerfile + CI"]
        CFG["sample-service-config\ndry Helm chart"]
        ADD["platform-addons\nroles/<role>/"]
        APP["platform-apps\nregistry/*.yaml"]
    end

    GHCR[("GHCR\nghcr.io/…/sample-service:<sha>")]

    subgraph mgmt["management cluster"]
        AC(["Argo CD"])
        HY["Source\nHydrator"]
        GP["gitops-\npromoter"]
    end

    DEV(["dev spoke"])
    PROD(["prod spoke"])

    SRC -->|"CI: build + push :sha"| GHCR
    SRC -->|"CI: PR bump image.tag"| CFG
    ADD -->|"App-of-Apps"| AC
    APP -->|"cd-apps ApplicationSet"| AC
    CFG -->|"dry source HEAD"| HY
    HY -->|"push env/dev-next\nenv/prod-next"| CFG
    CFG -->|"env/dev · env/prod"| AC
    GP -->|"merge env/*-next → env/*"| CFG
    AC -->|"sync"| DEV
    AC -->|"sync"| PROD
    GHCR -.->|"pull"| DEV
    GHCR -.->|"pull"| PROD
    DEV -->|"argocd-health ✓\nunlocks prod"| GP
```

## Architecture

`platform-addons` is the role-based GitOps addon configuration repo. It contains **platform-level concerns only** — addon installation and platform-wide operator config. App-level configs (Argo CD Applications, gitops-promoter CRs) live in each app's own config repo (e.g. `sample-service-config/config/`).

`platform-control-plane/scripts/bootstrap.sh` creates one App-of-Apps root Application per role (`management-configuration`, `dev-configuration`, `prod-configuration`), each pointing at `roles/<role>/` in this repo. Argo CD recurses the role directory and discovers addons via `directory.recurse: true` + `include: "**/application.yaml"`.

- `roles/<role>/<addon>/application.yaml` — Argo CD Application for that addon on that role.
- `charts/<addon>/` — local Helm wrapper for addons with no official chart (e.g. gitops-promoter).
- `manifests/gitops-promoter/scm-provider.yaml` — platform-level GitHub App config shared by all promoter-enabled apps.
- `charts/business-app/` — golden-path Helm chart rendered by the `promoter` ApplicationSet. Given values from a service's `.argocd/registry.yaml`, it generates the `sourceHydrator` Applications (one per env) and the three gitops-promoter CRs (`GitRepository`, `PromotionStrategy`, `ArgoCDCommitStatus`). Services need no hand-written config — only `chart/` + `.argocd/registry.yaml`.

Sync waves control install order within a role: cert-manager (0) → gitops-promoter (1) → envoy-gateway (2) → envoy-gateway-config (3).

## What does NOT belong here

- App-specific Argo CD Application objects or gitops-promoter CRs authored by hand — `charts/business-app/` generates these from each service's `.argocd/registry.yaml`.
- Helm values for business apps — those live in dedicated config repos (`podinfo-config`, `sample-service-config`, etc.).

## Key conventions

- **Never use `destination.server`** — always `destination.name` (`in-cluster`, `dev`, or `prod`).
- **App names are role-suffixed** (e.g. `cert-manager-dev`) to avoid collisions in the shared Argo CD instance.
- **Adding a new addon**: create `roles/<role>/<addon>/application.yaml` (+ values files) and push — the root App-of-Apps picks it up automatically, no root manifests to update.
- **Local wrapper chart pattern**: store raw upstream `install.yaml` in `charts/<addon>/files/` and expose via `{{ .Files.Get "files/install.yaml" }}` — bypasses Helm templating on upstream manifests that contain Go template syntax.
