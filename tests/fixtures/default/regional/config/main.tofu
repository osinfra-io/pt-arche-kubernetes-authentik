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
      groups = ["platform-engineers", "project-admins"]
      host   = "https://gateway.example.com"
    }
  }
  external_host = "https://gateway.example.com"
  namespace     = "authentik"
}
