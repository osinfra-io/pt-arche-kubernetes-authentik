# Authentik Flow Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/flow

data "authentik_flow" "pre_authentication" {
  slug = "default-source-pre-authentication"
}
