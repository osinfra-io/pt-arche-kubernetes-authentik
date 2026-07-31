terraform {
  required_providers {

    # Authentik Provider
    # https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

    authentik = {
      source = "goauthentik/authentik"
    }

    # Helm Provider
    # https://search.opentofu.org/provider/hashicorp/helm/latest/docs

    helm = {
      source = "hashicorp/helm"
    }
  }
}
