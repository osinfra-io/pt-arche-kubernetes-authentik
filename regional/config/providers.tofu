terraform {
  required_providers {

    # Authentik Provider
    # https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

    authentik = {
      source = "goauthentik/authentik"
    }
  }
}
