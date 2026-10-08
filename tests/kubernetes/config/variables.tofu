# Input Variables
# https://opentofu.org/docs/language/values/variables

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
