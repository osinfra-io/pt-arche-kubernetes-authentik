# Authentik Certificate Key Pair Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/certificate_key_pair

data "authentik_certificate_key_pair" "signing" {
  name = var.signing_key_name
}

# Authentik Flow Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/flow

data "authentik_flow" "authorization" {
  slug = var.authorization_flow_slug
}

data "authentik_flow" "default_source_authentication" {
  slug = "default-source-authentication"
}

data "authentik_flow" "default_source_enrollment" {
  slug = "default-source-enrollment"
}

data "authentik_flow" "invalidation" {
  slug = var.invalidation_flow_slug
}

# Authentik Property Mapping Provider Scope Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/property_mapping_provider_scope

data "authentik_property_mapping_provider_scope" "email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_property_mapping_provider_scope" "openid" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

data "authentik_property_mapping_provider_scope" "profile" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}
