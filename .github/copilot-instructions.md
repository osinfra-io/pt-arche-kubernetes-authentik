# pt-arche-kubernetes-authentik

OpenTofu child module that deploys Authentik (OIDC identity provider and embedded outpost forward-auth for Istio `ext_authz`) on GKE via the official Helm chart, and configures its OIDC/proxy providers, scope mappings, and embedded outpost with the `goauthentik/authentik` Terraform provider.
