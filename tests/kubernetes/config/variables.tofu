# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "admin_saml" {
  default     = null
  description = "Optional Google SAML trust for local administrator testing; requires a custom Google SAML app with the authentik.localhost ACS"
  type = object({
    email_domain        = string
    google_group        = string
    idp_entity_id       = string
    signing_certificate = string
    sso_url             = string
  })
}

variable "authentik_token" {
  description = "Local Authentik bootstrap API token"
  sensitive   = true
  type        = string
}

variable "embedded_outpost_id" {
  description = "UUID of the built-in outpost discovered during bootstrap"
  type        = string
}

variable "google_oauth_client_id" {
  description = "Google web OAuth client with the registered localhost callback"
  sensitive   = true
  type        = string

  validation {
    condition     = length(var.google_oauth_client_id) > 0
    error_message = "Local integration requires Google OAuth credentials."
  }
}

variable "google_oauth_client_secret" {
  description = "Google OAuth secret supplied through the developer environment"
  sensitive   = true
  type        = string

  validation {
    condition     = length(var.google_oauth_client_secret) > 0
    error_message = "Local integration requires Google OAuth credentials."
  }
}
