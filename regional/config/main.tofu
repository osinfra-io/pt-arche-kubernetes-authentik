# Authentik Application
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/application

resource "authentik_application" "browser" {
  depends_on = [
    authentik_group.all,
    authentik_group.application,
    authentik_group.browser,
  ]

  for_each = var.browser_group_policy_bindings

  name               = local.browser_application_names[each.key]
  policy_engine_mode = "all"
  protocol_provider  = authentik_provider_proxy.browser[each.key].id
  slug               = local.browser_application_slugs[each.key]
}

resource "authentik_application" "gateway" {
  meta_launch_url   = var.application_launch_url
  name              = var.application_name
  protocol_provider = authentik_provider_oauth2.gateway.id
  slug              = var.application_slug
}

resource "authentik_application" "openbao" {
  lifecycle {
    enabled = local.openbao_oidc_enabled
  }

  name              = "OpenBao"
  protocol_provider = authentik_provider_oauth2.openbao.id
  slug              = "openbao"
}

# Authentik Flow
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow

resource "authentik_flow" "google_authentication" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  authentication = "require_unauthenticated"
  designation    = "authentication"
  name           = "Google Source Authentication"
  slug           = "google-source-authentication"
  title          = "Google Source Authentication"
}

# Dedicated prompt-free enrollment flow for the Google source, kept separate from
# default-source-enrollment so JIT-created Google users always land in
# authentik_group.all, without changing the enrollment behavior of any other source.
resource "authentik_flow" "google_enrollment" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  designation = "enrollment"
  name        = "Google Source Enrollment"
  slug        = "google-source-enrollment"
  title       = "Google Source Enrollment"
}

# Authentik Flow Stage Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding

resource "authentik_flow_stage_binding" "google_authentication" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  order  = 0
  stage  = authentik_stage_user_write.google_authentication.id
  target = authentik_flow.google_authentication.uuid
}

resource "authentik_flow_stage_binding" "google_authentication_login" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  order  = 1
  stage  = authentik_stage_user_login.google_enrollment.id
  target = authentik_flow.google_authentication.uuid
}

resource "authentik_flow_stage_binding" "google_enrollment" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  order  = 0
  stage  = authentik_stage_user_write.google_enrollment.id
  target = authentik_flow.google_enrollment.uuid
}

resource "authentik_flow_stage_binding" "google_enrollment_login" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  order  = 1
  stage  = authentik_stage_user_login.google_enrollment.id
  target = authentik_flow.google_enrollment.uuid
}

# Authentik Group
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group

# Every user provisioned through any Authentik source (not just Google) lands here by default;
# route_auth_policies can grant baseline access platform-wide by requiring this group.
resource "authentik_group" "all" {
  is_superuser = false
  name         = local.all_group_name
}

resource "authentik_group" "application" {
  for_each = var.application_groups

  attributes   = local.application_group_attributes[each.key]
  is_superuser = contains(var.superuser_group_keys, each.key)
  name         = each.value.name
  users        = local.application_group_users[each.key]
}

resource "authentik_group" "browser" {
  for_each = local.browser_groups

  is_superuser = false
  name         = each.value.group
}

# Authentik Outpost
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/outpost

# The embedded outpost ships with Authentik and runs inside the authentik-server pods, so it
# needs no service connection or managed Kubernetes deployment. Consumers import it (an import
# block in the root module, keyed on its name) so this resource assigns the proxy provider to
# it, which makes each regional authentik-server serve forward-auth locally for Istio.
resource "authentik_outpost" "embedded" {
  config             = local.outpost_config
  name               = local.embedded_outpost_name
  protocol_providers = local.outpost_provider_ids
  type               = "proxy"
}

# Authentik Policy Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding

resource "authentik_policy_binding" "browser_access" {
  for_each = var.browser_group_policy_bindings

  failure_result = false
  order          = 0
  policy         = authentik_policy_expression.browser_access[each.key].id
  target         = authentik_application.browser[each.key].uuid
}

resource "authentik_policy_binding" "google_authentication_sso" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  failure_result = false
  order          = 0
  policy         = authentik_policy_expression.google_authentication_sso.id
  target         = authentik_flow.google_authentication.uuid
}

# Authentik Expression Policy
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_expression

resource "authentik_policy_expression" "browser_access" {
  for_each = var.browser_group_policy_bindings

  expression = local.browser_access_policy_expressions[each.key]
  name       = local.browser_access_policy_names[each.key]
}

resource "authentik_policy_expression" "google_authentication_sso" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  expression = "return ak_is_sso_flow"
  name       = "Google Source Authentication - Require SSO"
}

# Authentik Property Mapping Provider Scope
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/property_mapping_provider_scope

resource "authentik_property_mapping_provider_scope" "google_proxy" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  expression = local.google_proxy_mapping_expression
  name       = "Gateway - verified Google proxy identity"
  scope_name = "ak_proxy"
}

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

# Authentik OAuth Source Property Mapping
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/property_mapping_source_oauth

resource "authentik_property_mapping_source_oauth" "google_application_groups" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  expression = local.google_group_mapping_expression
  name       = "Google - Logos application groups"
}

resource "authentik_property_mapping_source_oauth" "google_username" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  expression = local.google_identity_mapping_expression
  name       = "Google - email as username"
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

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
    authentik_property_mapping_provider_scope.roles.id,
  ]

  signing_key = data.authentik_certificate_key_pair.signing.id
  sub_mode    = "user_email"
}

resource "authentik_provider_oauth2" "openbao" {
  lifecycle {
    enabled = local.openbao_oidc_enabled
  }

  allowed_redirect_uris = local.openbao_redirect_uris
  authorization_flow    = data.authentik_flow.authorization.id
  client_id             = "openbao"
  client_type           = "confidential"
  grant_types           = ["authorization_code"]
  invalidation_flow     = data.authentik_flow.invalidation.id
  issuer_mode           = "per_provider"
  name                  = "OpenBao"

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
    authentik_property_mapping_provider_scope.roles.id,
  ]

  signing_key = data.authentik_certificate_key_pair.signing.id
  sub_mode    = "user_uuid"
}

# Authentik Proxy Provider (forward-auth)
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/provider_proxy

resource "authentik_provider_proxy" "browser" {
  for_each = var.browser_group_policy_bindings

  access_token_validity = "minutes=10"
  authorization_flow    = data.authentik_flow.authorization.id
  external_host         = each.value.host
  invalidation_flow     = data.authentik_flow.invalidation.id
  mode                  = "forward_single"
  name                  = local.browser_application_names[each.key]
  property_mappings     = local.browser_proxy_property_mapping_ids
}

resource "authentik_provider_proxy" "gateway" {
  authorization_flow = data.authentik_flow.authorization.id
  external_host      = var.external_host
  invalidation_flow  = data.authentik_flow.invalidation.id
  mode               = "forward_single"
  name               = local.forward_auth_provider_name
  property_mappings  = local.proxy_default_property_mapping_ids
}

# Authentik Google OAuth Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/source_oauth

resource "authentik_source_oauth" "google" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  access_token_url    = "https://oauth2.googleapis.com/token"
  authentication_flow = local.google_authentication_flow_id
  authorization_url   = "https://accounts.google.com/o/oauth2/v2/auth"
  consumer_key        = var.google_oauth_client_id
  consumer_secret     = var.google_oauth_client_secret
  enrollment_flow     = authentik_flow.google_enrollment.uuid
  group_matching_mode = local.google_group_matching_mode
  name                = "Google"
  oidc_jwks_url       = "https://www.googleapis.com/oauth2/v3/certs"
  profile_url         = "https://openidconnect.googleapis.com/v1/userinfo"
  property_mappings   = local.google_source_property_mapping_ids
  provider_type       = "google"
  slug                = "google"
}

# Authentik Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_identification

# The default authentication flow's identification stage is a pre-existing, shared object.
# Consumers import it while management is enabled and pass any independently managed source UUIDs
# so adding or removing Google preserves the stage and its complete source list.
resource "authentik_stage_identification" "default_authentication" {
  lifecycle {
    enabled = local.default_authentication_stage_managed
  }

  captcha_stage             = var.default_authentication_stage_settings.captcha_stage
  case_insensitive_matching = var.default_authentication_stage_settings.case_insensitive_matching
  enable_remember_me        = var.default_authentication_stage_settings.enable_remember_me
  enrollment_flow           = var.default_authentication_stage_settings.enrollment_flow
  name                      = local.default_authentication_identification_stage_name
  password_stage            = var.default_authentication_stage_settings.password_stage
  passwordless_flow         = var.default_authentication_stage_settings.passwordless_flow
  pretend_user_exists       = var.default_authentication_stage_settings.pretend_user_exists
  recovery_flow             = var.default_authentication_stage_settings.recovery_flow
  show_matched_user         = var.default_authentication_stage_settings.show_matched_user
  show_source_labels        = var.default_authentication_stage_settings.show_source_labels
  sources                   = local.default_authentication_stage_sources
  user_fields               = var.default_authentication_stage_settings.user_fields
  webauthn_stage            = var.default_authentication_stage_settings.webauthn_stage
}

# Authentik Stage User Login
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_login

resource "authentik_stage_user_login" "google_enrollment" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  name = "Google Source Enrollment - User Login"
}

# Authentik Stage User Write
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_write

resource "authentik_stage_user_write" "google_authentication" {
  lifecycle {
    enabled = local.application_groups_enabled
  }

  name               = "Google Source Authentication - User Write"
  user_creation_mode = "never_create"
}

resource "authentik_stage_user_write" "google_enrollment" {
  lifecycle {
    enabled = local.google_oauth_enabled
  }

  create_users_as_inactive = false
  create_users_group       = authentik_group.all.id
  name                     = "Google Source Enrollment - User Write"
  user_creation_mode       = "create_when_required"
}
