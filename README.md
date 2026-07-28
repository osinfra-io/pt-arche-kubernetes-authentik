# Kubernetes - Authentik

[![OpenTofu Tests](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-arche-kubernetes-authentik/test.yml?style=for-the-badge&logo=opentofu&color=FEDA15&label=OpenTofu%20Tests)](https://github.com/osinfra-io/pt-arche-kubernetes-authentik/actions/workflows/test.yml) [![Dependabot](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-arche-kubernetes-authentik/dependabot.yml?style=for-the-badge&logo=github&color=2088FF&label=Dependabot)](https://github.com/osinfra-io/pt-arche-kubernetes-authentik/actions/workflows/dependabot.yml) [![Datadog Security Enabled](https://img.shields.io/badge/Datadog%20Security-Enabled-632CA6?style=for-the-badge&logo=datadog)](https://app.datadoghq.com/security/code-security/repositories?repository_id=pt-arche-kubernetes-authentik)

## Repository Description

OpenTofu child module that deploys [Authentik](https://goauthentik.io) on Google Kubernetes Engine via the official Helm chart and configures it as the centralized gateway identity provider for the platform.

A single Authentik deployment provides **both** layers required by the centralized Gateway auth initiative ([osinfra-io/pt-pneuma#142](https://github.com/osinfra-io/pt-pneuma/issues/142)):

- an **OIDC identity provider** used by Istio `RequestAuthentication` for JWT validation, and
- an **embedded outpost** (Proxy Provider, forward-auth mode) used as the Istio `ext_authz` check endpoint.

The Authentik server and worker are stateless — all state lives in an external Cloud SQL PostgreSQL — so the module is consumed per gateway region against a shared, replicated database. Modern Authentik caches core state in PostgreSQL, so **no Redis** is deployed. See the [Authentik high-availability docs](https://docs.goauthentik.io/install-config/high-availability/).

## 🔩 Usage

> [!TIP]
> You can check the [tests/fixtures](tests/fixtures) directory for example configurations.

This module is consumed from a regional workspace via the `//regional` sub-path. The Helm release runs first, then the `goauthentik/authentik` provider configures the OIDC provider, application, proxy (forward-auth) provider, `roles`/`groups` scope mappings, and the embedded outpost.

## 🛠️ Tools

- [pre-commit](https://github.com/pre-commit/pre-commit)
- [osinfra-pre-commit-hooks](https://github.com/osinfra-io/pt-techne-pre-commit-hooks)

## 📋 Skills and Knowledge

- [Authentik documentation](https://docs.goauthentik.io)
- [Authentik Helm chart](https://github.com/goauthentik/helm)
- [goauthentik/authentik Terraform provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Authentik proxy provider (forward auth)](https://docs.goauthentik.io/add-secure-apps/providers/proxy/)

## 🔍 Tests

All tests are [mocked](https://opentofu.org/docs/cli/commands/test/#the-mock_provider-blocks) allowing us to test the module without creating infrastructure or requiring credentials.

```none
tofu init
```

```none
tofu test
```

## 📦 Release

To release a new version, simply push a new tag to the repository. The tag should be in the format `vX.Y.Z` where `X`, `Y`, and `Z` are integers.

```none
git tag vX.Y.Z
git push origin vX.Y.Z
```
