# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Per-provider issuer mode: the issuer and JWKS live under the application slug.
  # https://docs.goauthentik.io/add-secure-apps/providers/oauth2
  issuer_url = "${var.authentik_url}/application/o/${var.application_slug}/"

  jwks_uri = "${var.authentik_url}/application/o/${var.application_slug}/jwks/"

  # The managed outpost auto-creates a Kubernetes Service named "ak-outpost-<name>" that Istio
  # ext_authz forward-auth targets on port 9000 at /outpost.goauthentik.io/auth/envoy.
  outpost_service_name = "ak-outpost-${var.outpost_name}"

  outpost_service_port = 9000
}
