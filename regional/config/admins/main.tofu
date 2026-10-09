# Authentik Application
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/application

resource "authentik_application" "admins" {
  name               = local.application_name
  policy_engine_mode = "all"
  protocol_provider  = authentik_provider_proxy.admins.id
  slug               = var.configuration.slug
}

# Authentik Certificate Key Pair
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/certificate_key_pair

resource "authentik_certificate_key_pair" "google" {
  certificate_data = var.configuration.signing_certificate
  name             = "${local.application_name} Google verification"
}

# Authentik Flow
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow

resource "authentik_flow" "authorization" {
  authentication = "require_authenticated"
  designation    = "authorization"
  name           = local.application_name
  slug           = "${var.configuration.slug}-authorization"
  title          = "Verify Google administrator access"
}

resource "authentik_flow" "source" {
  for_each = local.source_flows

  authentication = "none"
  designation    = each.value
  name           = "${local.application_name} ${each.key}"
  slug           = "${var.configuration.slug}-${each.key}"
  title          = "Verify Google administrator identity"
}

# Authentik Flow Stage Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding

resource "authentik_flow_stage_binding" "consent" {
  order  = 20
  stage  = authentik_stage_consent.admins.id
  target = authentik_flow.authorization.uuid
}

resource "authentik_flow_stage_binding" "deny" {
  evaluate_on_plan     = false
  order                = 10
  re_evaluate_policies = true
  stage                = authentik_stage_deny.nonmember.id
  target               = authentik_flow.authorization.uuid
}

resource "authentik_flow_stage_binding" "source" {
  order  = 0
  stage  = authentik_stage_source.google.id
  target = authentik_flow.authorization.uuid
}

resource "authentik_flow_stage_binding" "write" {
  for_each = local.source_flows

  order  = 0
  stage  = authentik_stage_user_write.source.id
  target = authentik_flow.source[each.key].uuid
}

# Authentik Group
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group

resource "authentik_group" "admins" {
  is_superuser = false
  name         = var.configuration.group_name
}

# Authentik Policy Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding

resource "authentik_policy_binding" "application" {
  failure_result = false
  order          = 0
  policy         = authentik_policy_expression.application.id
  target         = authentik_application.admins.uuid
}

resource "authentik_policy_binding" "deny" {
  failure_result = true
  order          = 0
  policy         = authentik_policy_expression.nonmember.id
  target         = authentik_flow_stage_binding.deny.id
}

# Authentik Expression Policy
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_expression

resource "authentik_policy_expression" "application" {
  expression = local.application_expression
  name       = "${local.application_name} application entry"
}

resource "authentik_policy_expression" "nonmember" {
  expression = local.nonmember_expression
  name       = "${local.application_name} deny missing membership"
}

# Authentik Provider Scope Mapping
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/property_mapping_provider_scope

resource "authentik_property_mapping_provider_scope" "expiry" {
  expression = local.expiry_expression
  name       = "${local.application_name} absolute membership expiry"
  scope_name = "ak_proxy"
}

# Authentik SAML Source Property Mapping
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/property_mapping_source_saml

resource "authentik_property_mapping_source_saml" "google" {
  expression = local.source_expression
  name       = "${local.application_name} trusted Google identity"
}

# Authentik Proxy Provider
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/provider_proxy

resource "authentik_provider_proxy" "admins" {
  access_token_validity  = local.access_token_validity
  authorization_flow     = authentik_flow.authorization.uuid
  external_host          = var.configuration.external_host
  intercept_header_auth  = false
  invalidation_flow      = var.invalidation_flow_id
  mode                   = "forward_single"
  name                   = local.application_name
  property_mappings      = [authentik_property_mapping_provider_scope.expiry.id]
  refresh_token_validity = "seconds=0"
}

# Authentik SAML Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/source_saml

resource "authentik_source_saml" "google" {
  depends_on = [authentik_group.admins]

  allow_idp_initiated     = false
  authentication_flow     = authentik_flow.source["authentication"].uuid
  binding_type            = "REDIRECT"
  enrollment_flow         = authentik_flow.source["enrollment"].uuid
  group_matching_mode     = "name_link"
  issuer                  = local.source_entity_id
  name                    = "${local.application_name} Google Workspace"
  name_id_policy          = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  pre_authentication_flow = data.authentik_flow.pre_authentication.id
  property_mappings       = [authentik_property_mapping_source_saml.google.id]
  signed_assertion        = false
  signed_response         = true
  slug                    = var.configuration.slug
  sso_url                 = var.configuration.sso_url
  user_matching_mode      = "email_link"
  verification_kp         = authentik_certificate_key_pair.google.id
}

# Authentik Consent Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_consent

resource "authentik_stage_consent" "admins" {
  mode = "always_require"
  name = "${local.application_name} authorization"
}

# Authentik Deny Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_deny

resource "authentik_stage_deny" "nonmember" {
  name = "${local.application_name} membership required"
}

# Authentik Source Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_source

resource "authentik_stage_source" "google" {
  name   = "${local.application_name} Google membership refresh"
  source = authentik_source_saml.google.id
}

# Authentik User Write Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_write

resource "authentik_stage_user_write" "source" {
  create_users_as_inactive = false
  create_users_group       = var.baseline_group_id
  name                     = "${local.application_name} source user write"
  user_creation_mode       = "create_when_required"
}
