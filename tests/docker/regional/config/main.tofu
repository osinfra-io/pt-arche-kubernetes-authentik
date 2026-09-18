# Required Providers
# https://opentofu.org/docs/language/providers/requirements

terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.5.0"
    }
  }
}

# Authentik Provider
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

provider "authentik" {
  insecure = var.authentik_insecure
  token    = var.authentik_token
  url      = var.authentik_url
}

# Kubernetes Authentik
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "test" {
  source = "../../../../regional/config"

  application_name = "Development"
  application_slug = "development-oidc"
  authentik_url    = var.authentik_url
  browser_group_policy_bindings = {
    development = {
      groups = ["all"]
      host   = var.external_host
    }
  }
  client_id = "development"
  default_authentication_stage_settings = {
    captcha_stage             = null
    case_insensitive_matching = true
    enable_remember_me        = false
    enrollment_flow           = null
    password_stage            = null
    passwordless_flow         = null
    pretend_user_exists       = true
    recovery_flow             = null
    show_matched_user         = true
    show_source_labels        = false
    user_fields               = ["email", "username"]
    webauthn_stage            = null
  }
  external_host                       = var.external_host
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  manage_default_authentication_stage = true
  namespace                           = var.namespace
  outpost_authentik_url               = "http://localhost:9000"

  redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://dev.localhost/oauth2/callback"
    },
  ]
}

# Authentik Outpost (import)
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/outpost

# The embedded outpost is a built-in Authentik object. Its UUID is written to
# terraform.auto.tfvars by wait-for-authentik.sh so each fresh instance is handled correctly.
import {
  id = var.embedded_outpost_id
  to = module.test.authentik_outpost.embedded
}

# Authentik Stage Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/stage

data "authentik_stage" "default_authentication_identification" {
  for_each = toset(["default"])

  name = module.test.default_authentication_identification_stage_name
}

# Authentik Stage Identification (import)
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_identification

# The default authentication flow's identification stage is a pre-existing, shared object built
# into every Authentik instance, so it is imported (rather than created) to add the Google source
# to its "sources" list without touching any of its other live settings.
import {
  for_each = toset(["default"])

  id = data.authentik_stage.default_authentication_identification[each.key].id
  to = module.test.authentik_stage_identification.default_authentication[0]
}

output "issuer_url" {
  value = module.test.issuer_url
}

output "outpost_service_name" {
  value = module.test.outpost_service_name
}
