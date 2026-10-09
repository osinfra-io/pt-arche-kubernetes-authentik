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

run "saml_admins" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional/config"
  }

  variables {
    admin_saml = {
      email_domain        = "example.com"
      external_host       = "https://agentgateway.example.com"
      google_group        = "Pneuma Sandbox Administrators"
      idp_entity_id       = "https://accounts.google.com/o/saml2?idpid=mock"
      signing_certificate = "-----BEGIN CERTIFICATE-----\nmock-only\n-----END CERTIFICATE-----"
      sso_url             = "https://accounts.google.com/o/saml2/idp?idpid=fixture"
    }
  }

  assert {
    condition     = output.admin_saml["agentgateway"].source.signed_response && !output.admin_saml["agentgateway"].source.signed_assertion && !output.admin_saml["agentgateway"].source.allow_idp_initiated && output.admin_saml["agentgateway"].source.issuer == "https://authentik.example.com/source/saml/agentgateway-admins/metadata/"
    error_message = "Google responses must be signed and unsolicited IdP-initiated login must be disabled."
  }

  assert {
    condition     = !output.admin_saml["agentgateway"].group.is_superuser && output.admin_saml["agentgateway"].group.name == "agentgateway-admins"
    error_message = "Application administrators must not become Authentik superusers."
  }

  assert {
    condition     = output.admin_saml["agentgateway"].source_stage.source == output.admin_saml["agentgateway"].source.uuid
    error_message = "The Enterprise Source stage must reference the SAML source UUID, not its slug."
  }

  assert {
    condition     = output.admin_saml["agentgateway"].authorization_bindings.source.order < output.admin_saml["agentgateway"].authorization_bindings.deny.order && !output.admin_saml["agentgateway"].authorization_bindings.deny.evaluate_on_plan && output.admin_saml["agentgateway"].authorization_bindings.deny.re_evaluate_policies
    error_message = "Membership must be evaluated after the Source stage refreshes groups, not at flow planning."
  }

  assert {
    condition     = output.admin_saml["agentgateway"].provider.access_token_validity == "seconds=14399" && output.admin_saml["agentgateway"].provider.refresh_token_validity == "seconds=0" && !output.admin_saml["agentgateway"].provider.intercept_header_auth
    error_message = "Administrator sessions must be bounded without refresh-token or header-auth bypasses."
  }

  assert {
    condition     = output.browser_group_policy_binding_count == 2 && output.google_oauth_source_enabled
    error_message = "Adding administrator SAML must preserve existing OAuth and browser group bindings."
  }
}
