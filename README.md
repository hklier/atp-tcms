# ATP TCMS GitOps deployment

This repository deploys Kiwi TCMS Community Edition to Kubernetes through Argo CD.

The deployment intentionally keeps all credentials out of Git. Create the two runtime Secrets from the templates in `deploy/bootstrap/` before applying the Argo CD Application. The database and uploaded attachments use independent PersistentVolumeClaims, so neither is deleted by normal application upgrades.

## Architecture

```text
GitHub repository -> Argo CD Application -> atp-tcms namespace
                                      |- Kiwi TCMS HTTPS service
                                      |- MariaDB
                                      |- uploads PVC + database PVC
```

The public Community Edition image is a rolling release. It is therefore kept in `kustomization.yaml` as an explicit operational choice. For a production change-control process, mirror and scan the image into an internal registry, then replace the image name with an immutable digest.

## Bootstrap

1. Create `deploy/bootstrap/kiwi-credentials.yaml` from `kiwi-credentials.example.yaml`, with long random values. Do not commit it.
2. Create `deploy/bootstrap/argocd-repository.yaml` from `argocd-repository.example.yaml` when this GitHub repository is private. Do not commit it.
3. Apply the two Secrets to the cluster, then apply `deploy/argocd/application.yaml`.
4. Argo CD creates the namespace, MariaDB, the one-time initialisation Job, and Kiwi TCMS. The initialisation Job creates the supplied administrator account, applies migrations, configures the site domain, and refreshes the default permissions.
5. Obtain the service address with `kubectl -n atp-tcms get service kiwi-tcms` and open `https://ADDRESS:8443`.

The Service is a `LoadBalancer` to match the cluster convention used by the existing deployments. If the cluster uses an Ingress controller instead, add an Ingress in an environment overlay and change the bootstrap domain to its DNS name.

## Day-two operation

- Make all desired-state changes in Git; Argo CD has automated sync, prune, and self-heal enabled.
- Back up both PVCs before database or image upgrades.
- Do not delete the `atp-tcms` namespace while preserving test history matters.
- Review the upstream Kiwi TCMS release notes before updating the image. Community Edition does not publish versioned public images; use a scanned internal mirror for reproducible releases.

