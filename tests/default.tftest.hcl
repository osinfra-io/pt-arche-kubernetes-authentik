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

  mock_resource "authentik_flow" {
    defaults = {
      id   = "00000000-0000-0000-0000-000000000007"
      uuid = "00000000-0000-0000-0000-000000000007"
    }
  }

  mock_resource "authentik_flow_stage_binding" {
    defaults = {
      id = 8
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

  mock_resource "authentik_property_mapping_source_oauth" {
    defaults = {
      id = 12
    }
  }

  mock_resource "authentik_source_oauth" {
    defaults = {
      id   = 6
      uuid = "00000000-0000-0000-0000-000000000006"
    }
  }

  mock_resource "authentik_stage_identification" {
    defaults = {
      id = 10
    }
  }

  mock_resource "authentik_stage_user_login" {
    defaults = {
      id = 11
    }
  }

  mock_resource "authentik_stage_user_write" {
    defaults = {
      id = 9
    }
  }

}

run "default_regional" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional"
  }
}

run "google_enabled_regional_config" {
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

  assert {
    condition     = output.preserved_authentication_source == true
    error_message = "The Google Authentik source should preserve existing identification-stage sources."
  }

  assert {
    condition     = output.default_authentication_stage_managed == true
    error_message = "The shared default authentication stage should remain managed while Google is enabled."
  }
}

run "google_disabled_regional_config" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional/config"
  }

  variables {
    google_oauth_client_id     = ""
    google_oauth_client_secret = ""
  }

  assert {
    condition     = output.google_oauth_source_enabled == false
    error_message = "The Google Authentik source should be removed when both OAuth credential variables are cleared."
  }

  assert {
    condition     = output.default_authentication_stage_managed == true
    error_message = "The shared default authentication stage should remain managed after Google is disabled."
  }

  assert {
    condition     = output.preserved_authentication_source == true
    error_message = "Disabling Google should preserve independently managed identification-stage sources."
  }
}

run "managed_application_membership" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional/config"
  }

  variables {
    application_groups = {
      pt-pneuma-agentgateway-admins = {
        description = "agentgateway UI access"
        members     = ["member@example.com", "new@example.com"]
        name        = "pt-pneuma: agentgateway Admins"
      }
    }
  }

  override_data {
    target = module.test.data.authentik_users.google[0]
    values = {
      users = [
        {
          attributes   = "{\"osinfra_google_email\":\"member@example.com\"}"
          avatar       = ""
          date_joined  = ""
          email        = "member@example.com"
          groups       = []
          is_active    = true
          is_superuser = false
          last_login   = ""
          name         = "Member"
          path         = "goauthentik.io/sources/google"
          pk           = 101
          type         = "external"
          uid          = "member"
          username     = "member@example.com"
          uuid         = "00000000-0000-0000-0000-000000000101"
        },
        {
          attributes   = "{}"
          avatar       = ""
          date_joined  = ""
          email        = "new@example.com"
          groups       = []
          is_active    = true
          is_superuser = false
          last_login   = ""
          name         = "Unverified"
          path         = "goauthentik.io/sources/google"
          pk           = 102
          type         = "external"
          uid          = "unverified"
          username     = "new@example.com"
          uuid         = "00000000-0000-0000-0000-000000000102"
        },
      ]
    }
  }

  assert {
    condition     = output.application_groups["pt-pneuma-agentgateway-admins"].name == "pt-pneuma: agentgateway Admins" && !output.application_groups["pt-pneuma-agentgateway-admins"].is_superuser && output.application_groups["pt-pneuma-agentgateway-admins"].users == tolist([101])
    error_message = "Only a verified Google identity may join the non-superuser application group; preserve the display name."
  }

  assert {
    condition     = output.pending_application_members["pt-pneuma-agentgateway-admins"] == tolist(["new@example.com"])
    error_message = "Unverified or not-yet-enrolled identities must remain explicitly pending."
  }

  assert {
    condition     = length(output.google_authentication_user_write_stages) == 1 && output.google_authentication_user_write_stages[0].user_creation_mode == "never_create"
    error_message = "Google sign-in must persist source identity updates for existing users without pre-provisioning accounts."
  }
}

run "application_membership_removed" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional/config"
  }

  variables {
    application_groups = {
      pt-pneuma-agentgateway-admins = {
        description = "agentgateway UI access"
        members     = []
        name        = "pt-pneuma: agentgateway Admins"
      }
    }
  }

  assert {
    condition     = length(output.application_groups["pt-pneuma-agentgateway-admins"].users) == 0 && length(output.pending_application_members["pt-pneuma-agentgateway-admins"]) == 0
    error_message = "Removing all declared members must empty the managed application group without deleting it."
  }
}
