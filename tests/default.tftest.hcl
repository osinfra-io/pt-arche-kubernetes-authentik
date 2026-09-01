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
}
