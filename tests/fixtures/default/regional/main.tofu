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
  source = "../../../../regional"

  cloud_sql_connection_name    = "test-project:us-east1:authentik-abc123-us-east1"
  existing_secret              = "authentik"
  google_service_account_email = "authentik-cloud-sql@test-project.iam.gserviceaccount.com"
  namespace                    = "authentik"
}
