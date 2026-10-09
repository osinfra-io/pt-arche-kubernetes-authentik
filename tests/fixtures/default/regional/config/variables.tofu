# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "google_oauth_client_id" {
  default     = "test-client-id"
  description = "The Google OAuth client ID used by the test fixture"
  type        = string
}

variable "google_oauth_client_secret" {
  default     = "test-client-secret"
  description = "The Google OAuth client secret used by the test fixture"
  sensitive   = true
  type        = string
}
variable "admin_saml" {
  default = null
  type = object({
    email_domain        = string
    external_host       = string
    google_group        = string
    idp_entity_id       = string
    signing_certificate = string
    sso_url             = string
  })
}
