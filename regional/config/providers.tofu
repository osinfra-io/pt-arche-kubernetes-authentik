terraform {
  required_providers {

    # Authentik Provider
    # https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

    # Constrained to the provider line matching the Authentik server version
    # installed by regional/variables.tofu. Newer provider lines expect API
    # response fields the server does not return.

    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
  }
}
