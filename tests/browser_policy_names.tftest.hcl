# Test
# https://opentofu.org/docs/cli/commands/test

mock_provider "helm" {}
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

variables {
  authentik_url              = "https://authentik.example.com"
  google_oauth_client_id     = ""
  google_oauth_client_secret = ""
  namespace                  = "authentik"
  openbao_hostname           = "openbao.example.com"
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

run "shared_policy_name_with_reordered_groups" {
  command = plan

  module {
    source = "./regional/config"
  }

  variables {
    browser_group_policy_bindings = {
      "https://a.example.com" = {
        groups      = ["x", "y"]
        host        = "https://a.example.com"
        policy_name = "shared"
      }
      "https://b.example.com" = {
        groups      = ["y", "x"]
        host        = "https://b.example.com"
        policy_name = "shared"
      }
    }
  }
}

run "shared_policy_name_with_different_groups" {
  command = plan

  module {
    source = "./regional/config"
  }

  variables {
    browser_group_policy_bindings = {
      "https://a.example.com" = {
        groups      = ["x"]
        host        = "https://a.example.com"
        policy_name = "shared"
      }
      "https://b.example.com" = {
        groups      = ["y"]
        host        = "https://b.example.com"
        policy_name = "shared"
      }
    }
  }

  expect_failures = [var.browser_group_policy_bindings]
}

run "shared_policy_name_with_different_roles" {
  command = plan

  module {
    source = "./regional/config"
  }

  variables {
    browser_group_policy_bindings = {
      "https://a.example.com" = {
        groups      = ["x"]
        host        = "https://a.example.com"
        policy_name = "shared"
        roles       = ["r1"]
      }
      "https://b.example.com" = {
        groups      = ["x"]
        host        = "https://b.example.com"
        policy_name = "shared"
        roles       = ["r2"]
      }
    }
  }

  expect_failures = [var.browser_group_policy_bindings]
}

run "explicit_name_colliding_with_generated_name" {
  command = plan

  module {
    source = "./regional/config"
  }

  variables {
    browser_group_policy_bindings = {
      "https://gateway.example.com" = {
        groups = ["all"]
        host   = "https://gateway.example.com"
      }
      "https://z.example.com" = {
        groups      = ["team: Admins"]
        host        = "https://z.example.com"
        policy_name = "gateway-example-com-browser-access"
      }
    }
  }

  expect_failures = [var.browser_group_policy_bindings]
}
