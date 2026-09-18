# Required Providers
# https://opentofu.org/docs/language/providers/requirements

terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# Kubernetes Authentik
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "test" {
  source = "../../../../../regional/config"

  authentik_url = "https://authentik.example.com"
  browser_group_policy_bindings = {
    "https://gateway.example.com" = {
      groups = ["all", "project-admins"]
      host   = "https://gateway.example.com"
    }
  }
  default_authentication_source_uuids = [
    "00000000-0000-0000-0000-000000000013",
  ]
  default_authentication_stage_settings = {
    case_insensitive_matching = true
    enable_remember_me        = false
    pretend_user_exists       = true
    show_matched_user         = true
    show_source_labels        = false
    user_fields               = ["email", "username"]
  }
  external_host              = "https://gateway.example.com"
  google_oauth_client_id     = "test-client-id"
  google_oauth_client_secret = "test-client-secret"
  namespace                  = "authentik"
}

output "browser_group_policy_binding_count" {
  description = "Number of per-group Authentik browser policy bindings created by the fixture"
  value       = length(module.test.browser_policy_bindings)
}

output "google_oauth_source_enabled" {
  description = "Whether the fixture created the optional Google Authentik source"
  value       = module.test.google_oauth_source_enabled
}

output "preserved_authentication_source" {
  description = "Whether the fixture preserved its pre-existing authentication source"
  value       = contains(module.test.default_authentication_source_uuids, "00000000-0000-0000-0000-000000000013")
}
