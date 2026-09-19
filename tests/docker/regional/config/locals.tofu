# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  google_oauth_enabled = var.google_oauth_client_id != "" && var.google_oauth_client_secret != ""
}
