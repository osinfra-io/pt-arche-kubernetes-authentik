# Test
# https://opentofu.org/docs/cli/commands/test

# Mock Providers
# https://opentofu.org/docs/cli/commands/test/#the-mock_provider-blocks

mock_provider "helm" {}

mock_provider "authentik" {
  # Authentik provider primary keys are numeric; the proxy and OAuth2 provider IDs are
  # referenced as numbers by the application and outpost resources.
  mock_resource "authentik_application" {
    defaults = {
      id   = 3
      uuid = "00000000-0000-0000-0000-000000000003"
    }
  }

  mock_resource "authentik_group" {
    defaults = {
      id = 4
    }
  }

  mock_resource "authentik_outpost" {
    defaults = {
      id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "authentik_policy_binding" {
    defaults = {
      id = 5
    }
  }

  mock_resource "authentik_provider_oauth2" {
    defaults = {
      id = 1
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = 2
    }
  }

  mock_resource "authentik_source_oauth" {
    defaults = {
      id   = 6
      uuid = "00000000-0000-0000-0000-000000000006"
    }
  }
}

run "default_regional" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional"
  }
}

run "default_regional_config" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional/config"
  }

  assert {
    condition     = output.browser_group_policy_binding_count == 2
    error_message = "The default browser config should create one Authentik policy binding per declared group (2 for this fixture)."
  }

  assert {
    condition     = output.google_oauth_source_enabled == true
    error_message = "The Google Authentik source should be created when both OAuth credential variables are set."
  }
}
