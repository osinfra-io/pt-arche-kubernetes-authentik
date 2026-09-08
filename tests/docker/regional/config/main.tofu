# Required Providers
# https://opentofu.org/docs/language/providers/requirements

terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
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

  authentik_url              = var.authentik_url
  external_host              = var.external_host
  google_oauth_client_id     = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  namespace                  = var.namespace

  redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://gateway.localhost/oauth2/callback"
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

output "issuer_url" {
  value = module.test.issuer_url
}

output "outpost_service_name" {
  value = module.test.outpost_service_name
}
