# Kubernetes - Authentik

[![OpenTofu Tests](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-arche-kubernetes-authentik/test.yml?style=for-the-badge&logo=opentofu&color=FEDA15&label=OpenTofu%20Tests)](https://github.com/osinfra-io/pt-arche-kubernetes-authentik/actions/workflows/test.yml) [![Dependabot](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-arche-kubernetes-authentik/dependabot.yml?style=for-the-badge&logo=github&color=2088FF&label=Dependabot)](https://github.com/osinfra-io/pt-arche-kubernetes-authentik/actions/workflows/dependabot.yml) [![Datadog Security Enabled](https://img.shields.io/badge/Datadog%20Security-Enabled-632CA6?style=for-the-badge&logo=datadog)](https://app.datadoghq.com/security/code-security/repositories?repository_id=pt-arche-kubernetes-authentik)

## Repository Description

Reusable OpenTofu child module that deploys [Authentik](https://goauthentik.io) on Google Kubernetes Engine via the official Helm chart and configures it as the centralized gateway identity provider for the platform.

A single Authentik deployment provides both gateway authentication layers:

- an **OIDC identity provider** used by Istio `RequestAuthentication` for JWT validation, and
- an **embedded outpost** (Proxy Provider, forward-auth mode) used as the Istio `ext_authz` check endpoint.

The Authentik server and worker are stateless — all state lives in an external Cloud SQL PostgreSQL — so the module is consumed per gateway region against a shared, replicated database. Modern Authentik caches core state in PostgreSQL, so **no Redis** is deployed. See the [Authentik high-availability docs](https://docs.goauthentik.io/install-config/high-availability/).

## 🔩 Usage

Provide external PostgreSQL, Workload Identity for Cloud SQL Auth Proxy, and an existing Secret containing bootstrap and database credentials. Deploy `//regional` before `//regional/config`, which requires public HTTPS URLs. Protect credentials and provider tokens; follow the migration instructions below when enabling Google OAuth on an existing deployment. The repository root is not a consumable module.

> [!TIP]
> You can check the [tests/fixtures](tests/fixtures) directory for example configurations. These fixtures set up the system for testing by providing all the necessary initial code, thus creating good examples on which to base your configurations.

## 🛠️ Tools

- [pre-commit](https://github.com/pre-commit/pre-commit)
- [osinfra-pre-commit-hooks](https://github.com/osinfra-io/pt-techne-pre-commit-hooks)

## 📋 Skills and Knowledge

Links to documentation and other resources required to develop and iterate in this repository successfully.

- [Authentik documentation](https://docs.goauthentik.io)
- [Authentik Helm chart](https://github.com/goauthentik/helm)
- [goauthentik/authentik Terraform provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Authentik proxy provider (forward auth)](https://docs.goauthentik.io/add-secure-apps/providers/proxy/)

## 🔍 Tests

All tests are [mocked](https://opentofu.org/docs/cli/commands/test/#the-mock_provider-blocks) allowing us to test the module without creating infrastructure or requiring credentials. The trade-offs are acceptable in favor of speed and simplicity. In an OpenTofu test, a mocked provider or resource will generate fake data for all computed attributes that would normally be provided by the underlying provider APIs.

```none
tofu init
```

```none
tofu test
```

### Local gateway-stack testing

Run this command in Copilot CLI with the [`platform-grouping` plugin](https://github.com/osinfra-io/pt-ai-plugins/tree/main/plugins/platform-grouping) installed:

```text
/platform-grouping:test-local-gateway-stack
```

### Existing deployment: Google OAuth migration

When enabling Google in an existing Authentik deployment, import the shared `default-authentication-identification` stage at the consumer's indexed module address and set `manage_default_authentication_stage = true`. Before importing, inspect the live stage and pass every setting through `default_authentication_stage_settings`, including explicit `null` values for unlinked stages and flows, plus the UUIDs of existing login sources through `default_authentication_source_uuids`. This one-time migration prevents OpenTofu from trying to recreate the built-in stage and preserves local-password, CAPTCHA, WebAuthn, flow-link, and independently configured OAuth or SAML behavior.

To disable Google safely, keep `manage_default_authentication_stage = true`, clear the Google credentials, and apply once. This removes only Google from the stage's `sources` while retaining the shared stage. Either leave the stage managed, or run `tofu state rm 'module.<name>.authentik_stage_identification.default_authentication[0]'` before setting `manage_default_authentication_stage = false`.

## 📦 Release

To release a new version, simply push a new tag to the repository. The tag should be in the format `vX.Y.Z` where `X`, `Y`, and `Z` are integers.

```none
git tag vX.Y.Z
git push origin vX.Y.Z
```
