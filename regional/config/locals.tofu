# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # The built-in embedded outpost that runs inside the authentik-server pods. Assigning the proxy
  # provider to it makes each regional server serve forward-auth locally for Istio ext_authz.
  embedded_outpost_name = "authentik Embedded Outpost"

  # Name of the built-in default authentication flow's identification stage. Consumers import
  # the pre-existing object into authentik_stage_identification.default_authentication (same
  # pattern as the embedded outpost import), so this module only adds Google to its "sources"
  # list without touching any of its other live settings.
  default_authentication_identification_stage_name = "default-authentication-identification"

  # Normalize the base URL so a trailing slash in authentik_url does not produce double slashes in
  # the issuer and JWKS URLs.
  authentik_base_url = trimsuffix(var.authentik_url, "/")

  # Per-provider issuer mode: the issuer and JWKS live under the application slug.
  # https://docs.goauthentik.io/add-secure-apps/providers/oauth2
  issuer_url = "${local.authentik_base_url}/application/o/${var.application_slug}/"

  jwks_uri = "${local.authentik_base_url}/application/o/${var.application_slug}/jwks/"

  # The embedded outpost is served by the authentik-server Service, which Istio ext_authz
  # forward-auth targets on the HTTP service port at /outpost.goauthentik.io/auth/envoy.
  # https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_envoy
  outpost_service_name = "authentik-server"

  outpost_service_port = 80
}
