# Required Providers
# https://opentofu.org/docs/language/providers/requirements

terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
  }
}

# Authentik Provider
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

provider "authentik" {
  insecure = var.authentik_insecure
  token    = var.authentik_token
  url      = var.authentik_url
}

# Kubernetes Authentik
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "test" {
  source = "../../../../regional/config"

  application_launch_url = "https://dev.localhost/istio-test/auth"
  application_name       = "Development"
  application_slug       = "development-oidc"
  authentik_url          = var.authentik_url
  browser_group_policy_bindings = {
    development = {
      groups = ["all"]
      host   = var.external_host
    }
  }
  client_id = "development"
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
  external_host                       = var.external_host
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  manage_default_authentication_stage = true
  namespace                           = var.namespace
  outpost_authentik_url               = "http://localhost:9000"

  redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://dev.localhost/oauth2/callback"
    },
  ]
}

# Authentik Brand
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/brand

resource "authentik_brand" "development" {
  attributes = jsonencode({
    settings = {
      theme = {
        base = "dark"
      }
    }
  })
  branding_custom_css = <<-EOT
    :root {
      --ak-c-login--BackgroundColorOverlay: rgba(30, 30, 30, 0.94);
      --ak-c-login__main--BackgroundColor: #232323;
      --ak-c-login__main--Color: #e0e0e0;
      --pf-global--BackgroundColor--100: #1e1e1e;
      --pf-global--BackgroundColor--200: #232323;
      --pf-global--Color--100: #e0e0e0;
      --pf-global--Color--200: #a0a0a0;
      --pf-global--primary-color--100: #ffb400;
      --pf-global--primary-color--200: #e6a200;
      --pf-c-form-control--BackgroundColor: #2b2b2b;
      --pf-c-form-control--after--BorderBottomColor: #484848;
      --pf-c-form-control--focus--after--BorderBottomColor: #7a7a7a;
      --pf-c-form-control--hover--after--BorderBottomColor: #7a7a7a;
      --pf-c-form-control--m-expanded--after--BorderBottomColor: #7a7a7a;
    }

    ::selection {
      background-color: #484848;
      color: #ffffff;
    }

    .pf-c-background-image {
      background-color: #1e1e1e !important;
      background-image: none !important;
    }

    .pf-c-login__main {
      border: 1px solid #353535;
      border-radius: 8px;
    }

    input,
    textarea,
    select {
      background-color: #2b2b2b !important;
      border-color: #484848 !important;
      color: #e0e0e0 !important;
    }

    input:focus,
    input:focus-visible,
    textarea:focus,
    textarea:focus-visible,
    select:focus,
    select:focus-visible {
      background-color: #303030 !important;
      border-color: #7a7a7a !important;
      box-shadow: inset 0 -2px 0 #7a7a7a !important;
      outline-color: #7a7a7a !important;
    }

    input:autofill,
    input:-webkit-autofill,
    input:-webkit-autofill:focus,
    input:-webkit-autofill:hover {
      -webkit-text-fill-color: #e0e0e0 !important;
      box-shadow: inset 0 0 0 1000px #303030 !important;
      caret-color: #e0e0e0;
    }

    .pf-c-button.pf-m-primary {
      background-color: #ffb400;
      color: #1e1e1e;
    }

    .pf-c-button.pf-m-primary:hover {
      background-color: #e6a200;
    }

    #ak-back-home {
      background-color: #ffb400 !important;
      color: #1e1e1e !important;
    }

    #ak-back-home:active,
    #ak-back-home:focus,
    #ak-back-home:hover {
      background-color: #e6a200 !important;
      color: #1e1e1e !important;
    }

    a {
      color: #ffb400;
    }
  EOT
  branding_favicon    = "https://docs.osinfra.io/img/mirko-transparent.png"
  branding_logo       = "https://docs.osinfra.io/img/osinfra-logo-full.png"
  branding_title      = "osinfra.io | Development"
  default             = false
  domain              = "localhost:9000"
}

# Authentik Outpost (import)
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/outpost

# The embedded outpost is a built-in Authentik object. Its UUID is written to
# terraform.auto.tfvars by wait-for-authentik.sh so each fresh instance is handled correctly.
import {
  id = var.embedded_outpost_id
  to = module.test.authentik_outpost.embedded
}

# Authentik Stage Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/stage

data "authentik_stage" "default_authentication_identification" {
  for_each = toset(["default"])

  name = module.test.default_authentication_identification_stage_name
}

# Authentik Stage Identification (import)
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_identification

# The default authentication flow's identification stage is a pre-existing, shared object built
# into every Authentik instance, so it is imported (rather than created) to add the Google source
# to its "sources" list without touching any of its other live settings.
import {
  for_each = toset(["default"])

  id = data.authentik_stage.default_authentication_identification[each.key].id
  to = module.test.authentik_stage_identification.default_authentication[0]
}

output "issuer_url" {
  value = module.test.issuer_url
}

output "outpost_service_name" {
  value = module.test.outpost_service_name
}
