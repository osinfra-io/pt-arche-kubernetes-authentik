# Authentik Application
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/application

resource "authentik_application" "gateway" {
  name              = var.application_name
  protocol_provider = authentik_provider_oauth2.gateway.id
  slug              = var.application_slug
}

# Authentik OAuth2 Provider
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/provider_oauth2

resource "authentik_provider_oauth2" "gateway" {
  allowed_redirect_uris = var.redirect_uris
  authorization_flow    = data.authentik_flow.authorization.id
  client_id             = var.client_id
  client_type           = "confidential"
  invalidation_flow     = data.authentik_flow.invalidation.id
  issuer_mode           = "per_provider"
  name                  = var.application_name
  signing_key           = data.authentik_certificate_key_pair.signing.id
  sub_mode              = "user_email"

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
    authentik_property_mapping_provider_scope.roles.id,
  ]
}

# Authentik Proxy Provider (forward-auth)
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/provider_proxy

resource "authentik_provider_proxy" "gateway" {
  authorization_flow = data.authentik_flow.authorization.id
  external_host      = var.external_host
  invalidation_flow  = data.authentik_flow.invalidation.id
  mode               = "forward_single"
  name               = "${var.application_name} forward-auth"
}

# Authentik Property Mapping Provider Scope
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/property_mapping_provider_scope

resource "authentik_property_mapping_provider_scope" "groups" {
  expression = <<-EOT
    return {"groups": [group.name for group in request.user.ak_groups.all()]}
  EOT
  name       = "Gateway - groups claim"
  scope_name = "groups"
}

resource "authentik_property_mapping_provider_scope" "roles" {
  expression = <<-EOT
    return {"roles": [group.name for group in request.user.ak_groups.all()]}
  EOT
  name       = "Gateway - roles claim"
  scope_name = "roles"
}

# Authentik Outpost
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/outpost

# The embedded outpost ships with Authentik and runs inside the authentik-server pods, so it
# needs no service connection or managed Kubernetes deployment. Consumers import it (an import
# block in the root module, keyed on its name) so this resource assigns the proxy provider to
# it, which makes each regional authentik-server serve forward-auth locally for Istio.
resource "authentik_outpost" "embedded" {
  name               = local.embedded_outpost_name
  protocol_providers = [authentik_provider_proxy.gateway.id]
  type               = "proxy"
}
