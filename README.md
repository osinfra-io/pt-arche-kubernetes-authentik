# Kubernetes - Authentik

[![OpenTofu Tests](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-arche-kubernetes-authentik/test.yml?style=for-the-badge&logo=opentofu&color=FEDA15&label=OpenTofu%20Tests)](https://github.com/osinfra-io/pt-arche-kubernetes-authentik/actions/workflows/test.yml) [![Dependabot](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-arche-kubernetes-authentik/dependabot.yml?style=for-the-badge&logo=github&color=2088FF&label=Dependabot)](https://github.com/osinfra-io/pt-arche-kubernetes-authentik/actions/workflows/dependabot.yml) [![Datadog Security Enabled](https://img.shields.io/badge/Datadog%20Security-Enabled-632CA6?style=for-the-badge&logo=datadog)](https://app.datadoghq.com/security/code-security/repositories?repository_id=pt-arche-kubernetes-authentik)

## Repository Description

Reusable OpenTofu child module that deploys [Authentik](https://goauthentik.io) on Google Kubernetes Engine via the official Helm chart and configures it as the centralized gateway identity provider for the platform.

A single Authentik deployment provides **both** layers required by the centralized Gateway auth initiative ([osinfra-io/pt-pneuma#142](https://github.com/osinfra-io/pt-pneuma/issues/142)):

- an **OIDC identity provider** used by Istio `RequestAuthentication` for JWT validation, and
- an **embedded outpost** (Proxy Provider, forward-auth mode) used as the Istio `ext_authz` check endpoint.

The Authentik server and worker are stateless — all state lives in an external Cloud SQL PostgreSQL — so the module is consumed per gateway region against a shared, replicated database. Modern Authentik caches core state in PostgreSQL, so **no Redis** is deployed. See the [Authentik high-availability docs](https://docs.goauthentik.io/install-config/high-availability/).

## 🔩 Usage

### Module interfaces

| Source path | Purpose | Interface |
| --- | --- | --- |
| `//regional` | Deploys stateless Authentik server and worker pods with Cloud SQL Auth Proxy sidecars and an existing Kubernetes Secret. | [`regional/variables.tofu`](regional/variables.tofu) · [`regional/outputs.tofu`](regional/outputs.tofu) |
| `//regional/config` | Configures gateway/browser applications, OIDC and proxy providers, scope mappings, policy bindings, optional Google OAuth, and the embedded outpost. | [`regional/config/variables.tofu`](regional/config/variables.tofu) · [`regional/config/outputs.tofu`](regional/config/outputs.tofu) |

The repository root is not a consumable module. `//regional` requires an external PostgreSQL database, Workload Identity for the Cloud SQL Auth Proxy, and a pre-existing Secret containing Authentik bootstrap and database credentials; no Redis or in-cluster PostgreSQL is deployed. It defaults to two server replicas and one worker replica. `//regional/config` requires public HTTPS URLs and leaves Google OAuth disabled by default. Managing Google OAuth against an existing deployment requires importing the shared default identification stage exactly as described below. Authentik, Cloud SQL, replicas, and load-balancing traffic incur ongoing cost; protect bootstrap tokens, database passwords, OAuth secrets, and provider tokens as secrets.

> [!TIP]
> You can check the [tests/fixtures](tests/fixtures) directory for example configurations.

The Helm release should run before the `goauthentik/authentik` provider configures the OIDC provider, application, proxy provider, scope mappings, and embedded outpost.

## 🛠️ Tools

- [pre-commit](https://github.com/pre-commit/pre-commit)
- [osinfra-pre-commit-hooks](https://github.com/osinfra-io/pt-techne-pre-commit-hooks)

## 📋 Skills and Knowledge

- [Authentik documentation](https://docs.goauthentik.io)
- [Authentik Helm chart](https://github.com/goauthentik/helm)
- [goauthentik/authentik Terraform provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Authentik proxy provider (forward auth)](https://docs.goauthentik.io/add-secure-apps/providers/proxy/)

## 🔍 Tests

The default test suite is [mocked](https://opentofu.org/docs/cli/commands/test/#the-mock_provider-blocks), allowing CI-safe validation without infrastructure or credentials.

```none
tofu init
```

```none
tofu test
```

For the Docker integration test and full Istio browser-authentication flow, install the [`platform-grouping` plugin](https://github.com/osinfra-io/pt-ai-plugins/tree/main/plugins/platform-grouping) and ask Copilot CLI to use the `test-istio-authentik-locally` skill. The skill discovers the related repositories, starts and validates both fixtures, diagnoses failures, supports optional Google OAuth testing, and performs cleanup when requested.

```text
Use the test-istio-authentik-locally skill to test this checkout.
```

To include Google sign-in, create an OAuth 2.0 client of type **Web application** under **Google Cloud Console → APIs & Services → Credentials**. Add `http://localhost:9000/source/oauth/callback/google/` as an authorized redirect URI, then export its credentials before invoking the skill:

```bash
export TF_VAR_google_oauth_client_id="<client-id>"
read -rsp "Google OAuth client secret: " TF_VAR_google_oauth_client_secret
export TF_VAR_google_oauth_client_secret
echo
```

Unset both variables after testing:

```bash
unset TF_VAR_google_oauth_client_id TF_VAR_google_oauth_client_secret
```

When enabling Google in an existing Authentik deployment, import the shared `default-authentication-identification` stage at the consumer's indexed module address and set `manage_default_authentication_stage = true`. Before importing, inspect the live stage and pass every setting through `default_authentication_stage_settings`, including explicit `null` values for unlinked stages and flows, plus the UUIDs of existing login sources through `default_authentication_source_uuids`. This one-time migration prevents OpenTofu from trying to recreate the built-in stage and preserves local-password, CAPTCHA, WebAuthn, flow-link, and independently configured OAuth or SAML behavior.

To disable Google safely, keep `manage_default_authentication_stage = true`, clear the Google credentials, and apply once. This removes only Google from the stage's `sources` while retaining the shared stage. Either leave the stage managed, or run `tofu state rm 'module.<name>.authentik_stage_identification.default_authentication[0]'` before setting `manage_default_authentication_stage = false`.

## 📦 Release

To release a new version, simply push a new tag to the repository. The tag should be in the format `vX.Y.Z` where `X`, `Y`, and `Z` are integers.

```none
git tag vX.Y.Z
git push origin vX.Y.Z
```
