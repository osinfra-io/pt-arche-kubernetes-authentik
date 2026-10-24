mock_provider "authentik" {
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

  mock_resource "authentik_provider_oauth2" {
    defaults = {
      client_secret = "mock-openbao-client-secret"
      id            = 1
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = 2
    }
  }

  mock_resource "authentik_property_mapping_provider_scope" {
    defaults = {
      id = 13
    }
  }
}

run "openbao_oidc_provider" {
  command = apply

  override_resource {
    target = authentik_provider_oauth2.openbao
    values = {
      id = 14
    }
  }

  override_resource {
    target = authentik_property_mapping_provider_scope.roles
    values = {
      id = 15
    }
  }

  variables {
    authentik_url                       = "https://authentik.example.com"
    external_host                       = "https://gateway.example.com"
    google_oauth_client_id              = ""
    google_oauth_client_secret          = ""
    manage_default_authentication_stage = false
    namespace                           = "authentik"
    openbao_hostname                    = "openbao.example.com"
    default_authentication_stage_settings = {
      captcha_stage             = null
      case_insensitive_matching = true
      enable_remember_me        = false
      enrollment_flow           = null
      password_stage            = null
      passwordless_flow         = null
      pretend_user_exists       = true
      recovery_flow             = null
      show_matched_user         = true
      show_source_labels        = false
      user_fields               = ["email", "username"]
      webauthn_stage            = null
    }
  }

  assert {
    condition     = authentik_application.openbao.slug == "openbao" && tostring(authentik_application.openbao.protocol_provider) == authentik_provider_oauth2.openbao.id
    error_message = "OpenBao must have a dedicated Authentik application and OAuth2 provider."
  }

  assert {
    condition = alltrue([
      for uri in authentik_provider_oauth2.openbao.allowed_redirect_uris :
      uri.matching_mode == "strict" && uri.redirect_uri_type == "authorization"
      ]) && toset(authentik_provider_oauth2.openbao.allowed_redirect_uris[*].url) == toset([
      "https://openbao.example.com/ui/vault/auth/oidc/oidc/callback",
      "http://localhost:8250/oidc/callback",
    ])
    error_message = "The OpenBao provider must allow only its exact UI and CLI OIDC callback URIs."
  }

  assert {
    condition = (
      authentik_provider_oauth2.openbao.client_id == "openbao" &&
      contains(authentik_provider_oauth2.openbao.property_mappings, authentik_property_mapping_provider_scope.groups.id) &&
      contains(authentik_provider_oauth2.openbao.property_mappings, authentik_property_mapping_provider_scope.roles.id)
    )
    error_message = "The dedicated OpenBao provider must use the stable client ID and existing group and role claims."
  }

  assert {
    condition     = output.openbao_client_secret == authentik_provider_oauth2.openbao.client_secret
    error_message = "The sensitive OpenBao client-secret output must expose the dedicated provider's generated secret."
  }
}
