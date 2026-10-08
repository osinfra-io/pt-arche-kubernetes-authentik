# Test
# https://opentofu.org/docs/cli/commands/test

mock_provider "helm" {}

run "cloud_sql_defaults" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    cloud_sql_connection_name    = "test-project:us-east1:authentik"
    existing_secret              = "authentik"
    google_service_account_email = "authentik@test-project.iam.gserviceaccount.com"
    namespace                    = "authentik"
  }

  assert {
    condition     = yamldecode(helm_release.authentik.values[0]).authentik.postgresql.host == "127.0.0.1"
    error_message = "Existing callers must retain loopback Cloud SQL connectivity."
  }

  assert {
    condition     = length(yamldecode(helm_release.authentik.values[0]).server.extraContainers) == 1
    error_message = "Existing callers must retain their Cloud SQL proxy."
  }
}

run "direct_postgresql" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    existing_secret        = "authentik-local"
    external_database_host = "postgresql.authentik.svc.cluster.local"
    namespace              = "authentik"
  }

  assert {
    condition     = yamldecode(helm_release.authentik.values[0]).authentik.postgresql.host == "postgresql.authentik.svc.cluster.local"
    error_message = "Direct PostgreSQL must use the configured Service hostname."
  }

  assert {
    condition     = length(yamldecode(helm_release.authentik.values[0]).server.extraContainers) == 0 && length(yamldecode(helm_release.authentik.values[0]).worker.extraContainers) == 0
    error_message = "Direct PostgreSQL must not start a Cloud SQL proxy."
  }

  assert {
    condition     = length(yamldecode(helm_release.authentik.values[0]).serviceAccount.annotations) == 0
    error_message = "Direct PostgreSQL must not require Workload Identity."
  }
}

run "missing_database_connection" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    existing_secret = "authentik"
    namespace       = "authentik"
  }

  expect_failures = [var.cloud_sql_connection_name]
}

run "missing_workload_identity" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    cloud_sql_connection_name = "test-project:us-east1:authentik"
    existing_secret           = "authentik"
    namespace                 = "authentik"
  }

  expect_failures = [var.google_service_account_email]
}
