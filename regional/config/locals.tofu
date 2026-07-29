# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # The built-in embedded outpost that runs inside the authentik-server pods. Assigning the proxy
  # provider to it makes each regional server serve forward-auth locally for Istio ext_authz.
  embedded_outpost_name = "authentik Embedded Outpost"

  # Per-provider issuer mode: the issuer and JWKS live under the application slug.
  # https://docs.goauthentik.io/add-secure-apps/providers/oauth2
  issuer_url = "${var.authentik_url}/application/o/${var.application_slug}/"

  jwks_uri = "${var.authentik_url}/application/o/${var.application_slug}/jwks/"

  # The embedded outpost is served by the authentik-server Service, which Istio ext_authz
  # forward-auth targets on the HTTP service port at /outpost.goauthentik.io/auth/envoy.
  # https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_envoy
  outpost_service_name = "authentik-server"

  outpost_service_port = 80
}
