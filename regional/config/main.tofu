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

# Authentik Flow
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow

# Dedicated enrollment flow for the Google source, kept separate from
# default-source-enrollment so JIT-created Google users always land in
# authentik_group.all, without changing the enrollment behavior of any other source.
resource "authentik_flow" "google_enrollment" {
  count = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" ? 0 : 1

  name        = "Google Source Enrollment"
  title       = "Google Source Enrollment"
  slug        = "google-source-enrollment"
  designation = "enrollment"
}

# Authentik Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_write

resource "authentik_stage_user_write" "google_enrollment" {
  count = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" ? 0 : 1

  name                     = "Google Source Enrollment - User Write"
  create_users_as_inactive = false
  create_users_group       = authentik_group.all.id
  user_creation_mode       = "create_when_required"
}

# Authentik Flow Stage Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding

resource "authentik_flow_stage_binding" "google_enrollment" {
  count = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" ? 0 : 1

  target = authentik_flow.google_enrollment[0].uuid
  stage  = authentik_stage_user_write.google_enrollment[0].id
  order  = 0
}

# Authentik Google OAuth Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/source_oauth

resource "authentik_source_oauth" "google" {
  count = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" ? 0 : 1

  authentication_flow = data.authentik_flow.default_source_authentication.id
  consumer_key        = var.google_oauth_client_id
  consumer_secret     = var.google_oauth_client_secret
  enrollment_flow     = authentik_flow.google_enrollment[0].id
  name                = "Google"
  provider_type       = "google"
  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  slug = "google"
}

# Authentik Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_identification

# The default authentication flow's identification stage is a pre-existing, shared object (see
# the embedded outpost comment below for why this pattern is used). Consumers import it here so
# adding the Google source only appends to its "sources" list; every other field is set to match
# the stage's current live configuration so nothing else changes.
resource "authentik_stage_identification" "default_authentication" {
  name                      = local.default_authentication_identification_stage_name
  case_insensitive_matching = true
  enable_remember_me        = false
  pretend_user_exists       = true
  show_matched_user         = true
  show_source_labels        = false
  sources                   = length(authentik_source_oauth.google) > 0 ? [authentik_source_oauth.google[0].uuid] : []
  user_fields               = ["email", "username"]
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

# Every user provisioned through any Authentik source (not just Google) lands here by default;
# route_auth_policies can grant baseline access platform-wide by requiring this group.
resource "authentik_group" "all" {
  name         = "all"
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
