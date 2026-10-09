# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_url" {
  description = "Canonical public Authentik URL used to pin the SAML audience and recipient"
  type        = string

  validation {
    condition     = can(regex("^https://[^/?#]+/?$", var.authentik_url))
    error_message = "authentik_url must be an HTTPS origin without a query or path."
  }
}

variable "baseline_group_id" {
  description = "Existing baseline Authentik group assigned during enrollment"
  type        = string
}

variable "configuration" {
  description = "Google Workspace SAML trust and dedicated administrator application configuration"
  type = object({
    email_domain        = string
    external_host       = string
    google_group        = string
    group_attribute     = optional(string, "groups")
    group_name          = optional(string, "agentgateway-admins")
    idp_entity_id       = string
    refresh_seconds     = optional(number, 14400)
    signing_certificate = string
    slug                = optional(string, "agentgateway-admins")
    sso_url             = string
  })

  validation {
    condition = (
      startswith(var.configuration.external_host, "https://") &&
      can(regex("^https://accounts\\.google\\.com/", var.configuration.sso_url)) &&
      can(regex("^https://accounts\\.google\\.com/", var.configuration.idp_entity_id)) &&
      startswith(trimspace(var.configuration.signing_certificate), "-----BEGIN CERTIFICATE-----") &&
      length(trimspace(var.configuration.google_group)) > 0 &&
      length(trimspace(var.configuration.group_attribute)) > 0 &&
      length(trimspace(var.configuration.email_domain)) > 0 &&
      var.configuration.group_name != "all" &&
      can(regex("^[a-z0-9-]+$", var.configuration.slug)) &&
      var.configuration.refresh_seconds >= 300 &&
      var.configuration.refresh_seconds <= 14400 &&
      floor(var.configuration.refresh_seconds) == var.configuration.refresh_seconds
    )
    error_message = "Admin SAML requires an HTTPS application host, Google accounts SSO URL and IdP Entity ID, PEM signing certificate, explicit domain/group mapping, non-baseline group, valid slug, and integral refresh_seconds between 300 and 14400."
  }
}

variable "invalidation_flow_id" {
  description = "Existing provider invalidation flow UUID"
  type        = string
}
