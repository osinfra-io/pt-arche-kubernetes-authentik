locals {
  browser_group_policy_bindings = flatten([
    for host_key, binding in var.browser_group_policy_bindings : [
      for group in binding.groups : {
        host_key = host_key
        group    = group
        host     = binding.host
      }
    ]
  ])
}

# Authentik Application
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/application

resource "authentik_application" "gateway" {
  name              = var.application_name
  protocol_provider = authentik_provider_oauth2.gateway.id
  slug              = var.application_slug
}

resource "authentik_application" "browser" {
  for_each = var.browser_group_policy_bindings

  name              = "${var.application_name} Browser Access (${each.value.host})"
  protocol_provider = authentik_provider_proxy.browser[each.key].id
  slug              = replace(replace(replace(trimprefix(each.key, "https://"), ".", "-"), "/", "-"), "_", "-")
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

# Authentik Google OAuth Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/source_oauth

resource "authentik_source_oauth" "google" {
  count = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" ? 0 : 1

  authentication_flow = data.authentik_flow.default_source_authentication.id
  consumer_key        = var.google_oauth_client_id
  consumer_secret     = var.google_oauth_client_secret
  enrollment_flow     = data.authentik_flow.default_source_enrollment.id
  name                = "Google"
  provider_type       = "google"
  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  slug = "google"
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

resource "authentik_provider_proxy" "browser" {
  for_each = var.browser_group_policy_bindings

  authorization_flow = data.authentik_flow.authorization.id
  external_host      = each.value.host
  invalidation_flow  = data.authentik_flow.invalidation.id
  mode               = "forward_single"
  name               = "${var.application_name} Browser Access (${each.value.host})"
}

# Authentik Group
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group

resource "authentik_group" "browser" {
  for_each = {
    for group in distinct([for item in local.browser_group_policy_bindings : item.group]) : group => {
      group = group
    }
  }

  name         = each.value.group
  is_superuser = false
}

# Authentik Policy Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding

resource "authentik_policy_binding" "browser_group" {
  for_each = {
    for item in local.browser_group_policy_bindings : "${item.host_key}:${item.group}" => item
  }

  target = authentik_application.browser[each.value.host_key].uuid
  group  = authentik_group.browser[each.value.group].id
  order  = 0
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
  name = local.embedded_outpost_name
  protocol_providers = concat(
    [authentik_provider_proxy.gateway.id],
    [for provider in authentik_provider_proxy.browser : provider.id],
  )
  type = "proxy"
}
