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

The default test suite is [mocked](https://opentofu.org/docs/cli/commands/test/#the-mock_provider-blocks), allowing CI-safe validation without infrastructure or credentials.

```none
tofu init
```

```none
tofu test
```

You can also run a **Docker integration test** for `regional/config` against a local Authentik instance. Two modes are available depending on whether you want resources to persist for inspection.

**Full cycle** — creates resources, runs assertions, then destroys everything:

```none
docker compose -f tests/docker/compose.yml up -d
./tests/docker/wait-for-authentik.sh
tofu -chdir=tests/docker/regional/config init
tofu -chdir=tests/docker/regional/config test -filter=regional-config-live.tftest.hcl
docker compose -f tests/docker/compose.yml down -v
```

**Apply and inspect** — creates resources and leaves them running for manual inspection:

```none
docker compose --env-file tests/docker/.env -f tests/docker/compose.yml up -d
./tests/docker/wait-for-authentik.sh
tofu -chdir=tests/docker/regional/config init
tofu -chdir=tests/docker/regional/config apply
```

When you're done, tear down:

```none
tofu -chdir=tests/docker/regional/config destroy
docker compose -f tests/docker/compose.yml down -v
```

The Docker fixture uses the bootstrap API token from the committed `tests/docker/.env` defaults. The Authentik UI is available at `http://localhost:9000` (login: `akadmin` / `not-a-secret`).

### Testing the Google OAuth source locally

The `google_oauth_client_id`/`google_oauth_client_secret` variables in `tests/docker/regional/config` are empty by default, so `authentik_source_oauth.google` is skipped. To exercise real Google sign-in against the local fixture:

1. Use the sandbox environment's `authentik-google-oauth` client (provisioned in `pt-pneuma/main.tofu`) — its `allowed_redirect_uris` already includes `http://localhost:9000/source/oauth/callback/google/` in addition to the real sandbox Authentik callback, specifically so it can be reused for local module testing. Non-production and production clients are not widened this way, so don't use those. Retrieve the client ID/secret from the sandbox `pt-pneuma` outputs (`authentik_google_oauth_client_id` / `authentik_google_oauth_client_secret`, the latter is sensitive).
2. Export the credentials before applying the "Apply and inspect" flow above:

   ```none
   export TF_VAR_google_oauth_client_id="<client-id>"
   export TF_VAR_google_oauth_client_secret="<client-secret>"
   tofu -chdir=tests/docker/regional/config apply
   ```

3. The "Google" source becomes available on the Authentik login page at `http://localhost:9000`.

## 📦 Release

To release a new version, simply push a new tag to the repository. The tag should be in the format `vX.Y.Z` where `X`, `Y`, and `Z` are integers.

```none
git tag vX.Y.Z
git push origin vX.Y.Z
```
