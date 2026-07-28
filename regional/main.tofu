# Helm Release
# https://search.opentofu.org/provider/hashicorp/helm/latest/docs/resources/release

resource "helm_release" "authentik" {
  chart      = "authentik"
  name       = "authentik"
  namespace  = var.namespace
  repository = var.chart_repository

  values = [
    local.helm_values
  ]

  version = var.authentik_version
}
